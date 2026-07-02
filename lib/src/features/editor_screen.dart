import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import '../core/image_effects.dart';
import '../core/models.dart';
import '../core/video_editing.dart';
import '../data/project_repository.dart';
import '../services/audio_import_service.dart';
import '../services/media_import_service.dart';
import '../services/services.dart';
import '../ui/vicys_design.dart';
import 'video_preview.dart';
import 'video_timeline.dart';
import 'video_tool_shelf.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({required this.project, required this.repository, super.key});
  final MediaProject project;
  final ProjectRepository repository;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late final EditHistory history = EditHistory(widget.project);
  late final AutosaveController autosave = AutosaveController(widget.repository);
  final audioImportService = AudioImportService();
  final mediaImportService = MediaImportService();
  late ImageEffectSettings imageEffects =
      ImageEffectSettings.fromProject(widget.project);
  final videoPosition = ValueNotifier<Duration>(Duration.zero);
  final videoDuration = ValueNotifier<Duration>(Duration.zero);
  final videoPreviewKey = GlobalKey<VideoPreviewState>();
  int selectedClip = 0;
  bool importingVideo = false;
  String? imagePanel;

  void apply(String type) {
    setState(() => history.apply(EditOperation(type: type)));
    autosave.schedule(history.project);
  }

  /// Applies one validated non-destructive video operation and autosaves it.
  void applyVideoOperation(EditOperation operation) {
    setState(() => history.apply(operation));
    autosave.schedule(history.project);
  }

  /// Commits one complete effect snapshot to project history and autosave.
  ///
  /// Slider previews update only widget state; committing on interaction end
  /// avoids hundreds of SQLite revisions while preserving undo granularity.
  void commitImageEffects(ImageEffectSettings settings) {
    setState(() {
      imageEffects = settings;
      history.apply(settings.toOperation());
    });
    autosave.schedule(history.project);
  }

  void undo() {
    setState(() {
      history.undo();
      _clampSelectedClip();
      imageEffects = ImageEffectSettings.fromProject(history.project);
    });
    autosave.schedule(history.project);
  }

  void redo() {
    setState(() {
      history.redo();
      _clampSelectedClip();
      imageEffects = ImageEffectSettings.fromProject(history.project);
    });
    autosave.schedule(history.project);
  }

  void _clampSelectedClip() {
    final count = history.project.sourcePaths.length;
    if (count == 0) {
      selectedClip = 0;
    } else if (selectedClip >= count) {
      selectedClip = count - 1;
    }
  }

  void handleTool(String tool) {
    if (history.project.kind == ProjectKind.image &&
        (tool == 'Màu' || tool == 'Filter')) {
      setState(() => imagePanel = tool);
      return;
    }
    if (history.project.kind == ProjectKind.video) {
      if (history.project.sourcePaths.isEmpty) {
        _showMessage('Hãy thêm một video vào dự án trước.');
        return;
      }
      switch (tool) {
        case 'Cắt':
          _showTrimEditor();
          return;
        case 'Tách':
          _splitAtPlayhead();
          return;
        case 'Tốc độ':
          _showSpeedEditor();
          return;
        case 'Âm lượng':
          _showVolumeEditor();
          return;
        case 'Màu':
          _showFilterEditor();
          return;
        case 'Chữ':
          _showTextEditor();
          return;
        case 'Sticker':
          _showStickerEditor();
          return;
        case 'Nhạc':
          _pickAudio();
          return;
        case 'Chuyển cảnh':
          _showTransitionEditor();
          return;
        case 'Canvas':
          _showCanvasEditor();
          return;
        default:
          _showMessage('Không tìm thấy công cụ $tool.');
          return;
      }
    }
    apply(tool);
  }

  VideoClipEdit get selectedVideoClip =>
      VideoClipEdit.fromProject(history.project, selectedClip);
  VideoComposition get videoComposition =>
      VideoComposition.fromProject(history.project);

  /// Imports durable video files and appends them to the current project.
  ///
  /// Picker cancellation leaves the project unchanged. Imported files are
  /// persisted by [MediaImportService] before history and autosave are updated.
  Future<void> importVideos() async {
    if (importingVideo) return;
    setState(() => importingVideo = true);
    try {
      final media = await mediaImportService.importVideos();
      if (!mounted || media.isEmpty) return;
      final paths = media.map((item) => item.path);
      setState(() {
        history.replaceSourcePaths([
          ...history.project.sourcePaths,
          ...paths,
        ]);
        selectedClip = history.project.sourcePaths.length - media.length;
      });
      autosave.schedule(history.project);
    } catch (_) {
      if (mounted) {
        _showMessage('Không thể thêm video. Draft hiện tại vẫn an toàn.');
      }
    } finally {
      if (mounted) setState(() => importingVideo = false);
    }
  }

  /// Opens trim controls and commits one operation when the user confirms.
  Future<void> _showTrimEditor() async {
    final duration = videoDuration.value;
    if (duration <= const Duration(milliseconds: 200)) return;
    final clip = selectedVideoClip;
    var startMs = clip.trimStart.inMilliseconds.toDouble();
    var endMs = (clip.trimEnd ?? duration).inMilliseconds.toDouble();
    final result = await showModalBottomSheet<RangeValues>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Cắt video', style: TextStyle(fontSize: 18)),
              RangeSlider(
                values: RangeValues(startMs, endMs),
                min: 0,
                max: duration.inMilliseconds.toDouble(),
                divisions: 100,
                labels: RangeLabels(
                  _formatDuration(Duration(milliseconds: startMs.round())),
                  _formatDuration(Duration(milliseconds: endMs.round())),
                ),
                onChanged: (value) => setSheetState(() {
                  startMs = value.start;
                  endMs = value.end;
                }),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(context, RangeValues(startMs, endMs)),
                child: const Text('Áp dụng'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || result == null) return;
    applyVideoOperation(createTrimOperation(
      clipIndex: selectedClip,
      start: Duration(milliseconds: result.start.round()),
      end: Duration(milliseconds: result.end.round()),
    ));
  }

  void _splitAtPlayhead() {
    final position = videoPosition.value;
    if (position <= selectedVideoClip.trimStart ||
        position >= (selectedVideoClip.trimEnd ?? videoDuration.value)) {
      _showMessage('Di chuyển đầu phát vào giữa clip để tách.');
      return;
    }
    applyVideoOperation(
      createSplitOperation(clipIndex: selectedClip, position: position),
    );
    _showMessage('Đã tạo điểm tách tại ${_formatDuration(position)}.');
  }

  Future<void> _showSpeedEditor() async {
    var speed = selectedVideoClip.speed;
    final result = await _showValueEditor(
      title: 'Tốc độ',
      value: speed,
      minimum: .25,
      maximum: 4,
      divisions: 15,
      label: (value) => '${value.toStringAsFixed(2)}x',
      onChanged: (value) => speed = value,
    );
    if (mounted && result != null) {
      applyVideoOperation(
        createSpeedOperation(clipIndex: selectedClip, speed: result),
      );
    }
  }

  Future<void> _showVolumeEditor() async {
    var volume = selectedVideoClip.volume;
    final result = await _showValueEditor(
      title: 'Âm lượng clip',
      value: volume,
      minimum: 0,
      maximum: 1,
      divisions: 20,
      label: (value) => '${(value * 100).round()}%',
      onChanged: (value) => volume = value,
    );
    if (mounted && result != null) {
      applyVideoOperation(
        createVolumeOperation(clipIndex: selectedClip, volume: result),
      );
    }
  }

  Future<void> _showFilterEditor() async {
    const labels = {
      VideoFilter.original: 'Gốc',
      VideoFilter.vivid: 'Rực rỡ',
      VideoFilter.mono: 'Đen trắng',
      VideoFilter.vintage: 'Cổ điển',
      VideoFilter.cool: 'Lạnh',
      VideoFilter.warm: 'Ấm',
      VideoFilter.cinematic: 'Điện ảnh',
    };
    final selected = await showModalBottomSheet<VideoFilter>(
      context: context,
      builder: (context) => _ChoiceSheet<VideoFilter>(
        title: 'Bộ lọc video',
        values: VideoFilter.values,
        selected: videoComposition.filter,
        label: (value) => labels[value]!,
      ),
    );
    if (mounted && selected != null) {
      applyVideoOperation(createVideoSettingOperation(
        VideoEditOperation.filter,
        selected.name,
      ));
    }
  }

  Future<void> _showTextEditor() async {
    final controller = TextEditingController(text: videoComposition.text);
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thêm chữ'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 120,
          decoration: const InputDecoration(hintText: 'Nhập nội dung'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Áp dụng'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (mounted && text != null) {
      applyVideoOperation(createVideoSettingOperation(
        VideoEditOperation.text,
        text.isEmpty ? null : text,
      ));
    }
  }

  Future<void> _showStickerEditor() async {
    const stickers = ['', '✨', '❤️', '🔥', '😎', '🎉', '⭐', '🌈', '🚀'];
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => _ChoiceSheet<String>(
        title: 'Sticker',
        values: stickers,
        selected: videoComposition.sticker ?? '',
        label: (value) => value.isEmpty ? 'Bỏ sticker' : value,
      ),
    );
    if (mounted && selected != null) {
      applyVideoOperation(createVideoSettingOperation(
        VideoEditOperation.sticker,
        selected.isEmpty ? null : selected,
      ));
    }
  }

  /// Imports a soundtrack into durable storage and commits its local path.
  Future<void> _pickAudio() async {
    try {
      if (videoComposition.audioPath != null) {
        final action = await showModalBottomSheet<String>(
          context: context,
          builder: (context) => _ChoiceSheet<String>(
            title: 'Nhạc nền',
            values: const ['replace', 'remove'],
            selected: null,
            label: _audioActionLabel,
          ),
        );
        if (!mounted || action == null) return;
        if (action == 'remove') {
          applyVideoOperation(createVideoSettingOperation(
            VideoEditOperation.audio,
            null,
          ));
          return;
        }
      }
      final audioPath = await audioImportService.pickAndPersist();
      if (!mounted || audioPath == null) return;
      applyVideoOperation(createVideoSettingOperation(
        VideoEditOperation.audio,
        audioPath,
      ));
    } catch (_) {
      if (mounted) {
        _showMessage('Không thể mở tệp nhạc. Draft video vẫn an toàn.');
      }
    }
  }

  static String _audioActionLabel(String action) =>
      action == 'remove' ? 'Bỏ nhạc' : 'Thay nhạc';

  Future<void> _showTransitionEditor() async {
    const labels = {
      VideoTransition.none: 'Không',
      VideoTransition.fade: 'Mờ dần',
      VideoTransition.slide: 'Trượt',
      VideoTransition.zoom: 'Thu phóng',
    };
    final selected = await showModalBottomSheet<VideoTransition>(
      context: context,
      builder: (context) => _ChoiceSheet<VideoTransition>(
        title: 'Chuyển cảnh',
        values: VideoTransition.values,
        selected: videoComposition.transition,
        label: (value) => labels[value]!,
      ),
    );
    if (mounted && selected != null) {
      applyVideoOperation(createVideoSettingOperation(
        VideoEditOperation.transition,
        selected.name,
      ));
    }
  }

  Future<void> _showCanvasEditor() async {
    const options = <({double ratio, String label})>[
      (ratio: 9 / 16, label: '9:16'),
      (ratio: 1, label: '1:1'),
      (ratio: 4 / 5, label: '4:5'),
      (ratio: 16 / 9, label: '16:9'),
    ];
    final current = options.firstWhere(
      (option) =>
          (option.ratio - videoComposition.aspectRatio).abs() < .001,
      orElse: () => options.first,
    );
    final selected =
        await showModalBottomSheet<({double ratio, String label})>(
      context: context,
      builder: (context) => _ChoiceSheet<({double ratio, String label})>(
        title: 'Tỷ lệ canvas',
        values: options,
        selected: current,
        label: (option) => option.label,
      ),
    );
    if (mounted && selected != null) {
      applyVideoOperation(createVideoSettingOperation(
        VideoEditOperation.canvas,
        selected.ratio,
      ));
    }
  }

  Future<double?> _showValueEditor({
    required String title,
    required double value,
    required double minimum,
    required double maximum,
    required int divisions,
    required String Function(double) label,
    required ValueChanged<double> onChanged,
  }) =>
      showModalBottomSheet<double>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setSheetState) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: const TextStyle(fontSize: 18)),
                Slider(
                  value: value,
                  min: minimum,
                  max: maximum,
                  divisions: divisions,
                  label: label(value),
                  onChanged: (next) => setSheetState(() {
                    value = next;
                    onChanged(next);
                  }),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, value),
                  child: const Text('Áp dụng'),
                ),
              ],
            ),
          ),
        ),
      );

  void _showMessage(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  String _formatDuration(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// Persists current operations before returning to the media library.
  Future<void> finish() async {
    await widget.repository.save(history.project);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    autosave.dispose();
    videoPosition.dispose();
    videoDuration.dispose();
    widget.repository.save(history.project);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const imageTools = [
      ('Cắt', Icons.crop),
      ('Màu', Icons.tune),
      ('Filter', Icons.filter_vintage),
      ('Chữ', Icons.text_fields),
      ('Sticker', Icons.emoji_emotions_outlined),
      ('Vẽ', Icons.brush),
    ];
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 70,
        leading: TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('Hủy'),
        ),
        title: const VicysWordmark(compact: true),
        actions: [
          IconButton(
            onPressed: history.canUndo ? undo : null,
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            onPressed: history.canRedo ? redo : null,
            icon: const Icon(Icons.redo),
          ),
          if (history.project.kind == ProjectKind.video)
            IconButton(
              tooltip: 'Thêm video',
              onPressed: importingVideo ? null : importVideos,
              icon: importingVideo
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
            ),
          TextButton(
            onPressed: finish,
            child: Text(
              history.project.kind == ProjectKind.image ? 'Xong' : 'Lưu',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: Column(children: [
        Expanded(child: Center(child: AspectRatio(
          aspectRatio: history.project.kind == ProjectKind.image
              ? 1
              : videoComposition.aspectRatio,
          child: Container(
            decoration: BoxDecoration(color: const Color(0xff202027), borderRadius: BorderRadius.circular(12)),
            clipBehavior: Clip.antiAlias,
            child: history.project.kind == ProjectKind.video &&
                    history.project.sourcePaths.isEmpty
                ? _EmptyVideoProject(
                    importing: importingVideo,
                    onImport: importVideos,
                  )
                : history.project.kind == ProjectKind.video
                    ? VideoPreview(
                        key: videoPreviewKey,
                        clip: selectedVideoClip,
                        composition: videoComposition,
                        position: videoPosition,
                        duration: videoDuration,
                      )
                    : _ProjectPreview(
                        project: history.project,
                        imageEffects: imageEffects,
                      ),
          ),
        ))),
        if (history.project.kind == ProjectKind.video &&
            history.project.sourcePaths.isNotEmpty)
          VideoTimeline(
            project: history.project,
            position: videoPosition,
            duration: videoDuration,
            selectedClip: selectedClip,
            onSelectedClip: (index) => setState(() => selectedClip = index),
            onSeek: (position) => videoPreviewKey.currentState?.seek(position),
            onTogglePlayback: () =>
                videoPreviewKey.currentState?.togglePlayback(),
            onUndo: undo,
            onRedo: redo,
          ),
        if (history.project.kind == ProjectKind.image && imagePanel != null)
          ImageEffectsPanel(
            mode: imagePanel!,
            settings: imageEffects,
            onPreview: (settings) => setState(() => imageEffects = settings),
            onCommit: commitImageEffects,
            onClose: () => setState(() => imagePanel = null),
          )
        else if (history.project.kind == ProjectKind.video &&
            history.project.sourcePaths.isNotEmpty)
          VideoToolShelf(onToolSelected: handleTool)
        else if (history.project.kind == ProjectKind.image)
          SizedBox(height: 92, child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            scrollDirection: Axis.horizontal,
            itemCount: imageTools.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, index) => InkWell(
              onTap: () => handleTool(imageTools[index].$1),
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(width: 68, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(imageTools[index].$2), const SizedBox(height: 6), Text(imageTools[index].$1, maxLines: 1),
              ])),
            ),
          )),
      ]),
    );
  }
}

class _EmptyVideoProject extends StatelessWidget {
  const _EmptyVideoProject({
    required this.importing,
    required this.onImport,
  });

  final bool importing;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.video_library_outlined, size: 64),
              const SizedBox(height: 12),
              Text(
                'Thêm video để bắt đầu',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Video được lưu cục bộ và file gốc không bị thay đổi.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: importing ? null : onImport,
                icon: importing
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                label: Text(importing ? 'Đang thêm…' : 'Chọn video'),
              ),
            ],
          ),
        ),
      );
}

class _ProjectPreview extends StatelessWidget {
  const _ProjectPreview({
    required this.project,
    required this.imageEffects,
  });

  final MediaProject project;
  final ImageEffectSettings imageEffects;

  @override
  Widget build(BuildContext context) {
    if (project.sourcePaths.isEmpty) {
      return Center(child: Icon(
        project.kind == ProjectKind.image
            ? Icons.image_outlined
            : Icons.play_circle_outline,
        size: 80,
        color: Colors.white24,
      ));
    }
    final source = project.sourcePaths.first;
    if (project.kind == ProjectKind.image) {
      Widget image = Image.file(
        File(source),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const _MissingMedia(),
      );
      image = ColorFiltered(
        colorFilter: ColorFilter.matrix(imageEffects.colorMatrix),
        child: image,
      );
      if (imageEffects.blur > 0) {
        image = ImageFiltered(
          imageFilter: ui.ImageFilter.blur(
            sigmaX: imageEffects.blur,
            sigmaY: imageEffects.blur,
          ),
          child: image,
        );
      }
      return Stack(fit: StackFit.expand, children: [
        image,
        if (imageEffects.vignette > 0)
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: .78,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(
                      alpha: imageEffects.vignette * .8,
                    ),
                  ],
                  stops: const [.45, 1],
                ),
              ),
            ),
          ),
      ]);
    }
    return Stack(fit: StackFit.expand, children: [
      const ColoredBox(color: Color(0xff18181e)),
      const Center(child: Icon(Icons.play_circle_outline, size: 80)),
      Positioned(
        left: 12,
        right: 12,
        bottom: 12,
        child: Text(
          path.basename(source),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ),
    ]);
  }
}

class ImageEffectsPanel extends StatelessWidget {
  const ImageEffectsPanel({
    required this.mode,
    required this.settings,
    required this.onPreview,
    required this.onCommit,
    required this.onClose,
    super.key,
  });

  final String mode;
  final ImageEffectSettings settings;
  final ValueChanged<ImageEffectSettings> onPreview;
  final ValueChanged<ImageEffectSettings> onCommit;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xff18181e),
        child: SizedBox(
          height: mode == 'Filter' ? 126 : 214,
          child: Column(children: [
            SizedBox(
              height: 44,
              child: Row(children: [
                IconButton(
                  tooltip: 'Đóng bảng hiệu ứng',
                  onPressed: onClose,
                  icon: const Icon(Icons.keyboard_arrow_down),
                ),
                Text(
                  mode == 'Filter' ? 'Bộ lọc' : 'Điều chỉnh',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    const neutral = ImageEffectSettings();
                    onPreview(neutral);
                    onCommit(neutral);
                  },
                  child: const Text('Đặt lại'),
                ),
              ]),
            ),
            Expanded(
              child: mode == 'Filter'
                  ? _PresetStrip(
                      settings: settings,
                      onPreview: onPreview,
                      onCommit: onCommit,
                    )
                  : _AdjustmentControls(
                      settings: settings,
                      onPreview: onPreview,
                      onCommit: onCommit,
                    ),
            ),
          ]),
        ),
      );
}

class _PresetStrip extends StatelessWidget {
  const _PresetStrip({
    required this.settings,
    required this.onPreview,
    required this.onCommit,
  });

  final ImageEffectSettings settings;
  final ValueChanged<ImageEffectSettings> onPreview;
  final ValueChanged<ImageEffectSettings> onCommit;

  @override
  Widget build(BuildContext context) {
    const labels = {
      ImagePreset.original: 'Gốc',
      ImagePreset.vivid: 'Rực rỡ',
      ImagePreset.mono: 'Đen trắng',
      ImagePreset.vintage: 'Cổ điển',
      ImagePreset.cool: 'Lạnh',
      ImagePreset.neon: 'Neon',
      ImagePreset.dreamy: 'Mơ màng',
      ImagePreset.film: 'Film',
      ImagePreset.tealOrange: 'Teal',
      ImagePreset.rose: 'Rose',
      ImagePreset.sunset: 'Sunset',
      ImagePreset.fade: 'Fade',
      ImagePreset.cyber: 'Cyber',
      ImagePreset.mint: 'Mint',
    };
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      scrollDirection: Axis.horizontal,
      itemCount: ImagePreset.values.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (context, index) {
        final preset = ImagePreset.values[index];
        final selected = preset == settings.preset;
        return ChoiceChip(
          selected: selected,
          label: Text(labels[preset]!),
          avatar: Icon(
            preset == ImagePreset.mono
                ? Icons.monochrome_photos
                : Icons.auto_awesome,
            size: 18,
          ),
          onSelected: (_) {
            final next = settings.copyWith(preset: preset);
            onPreview(next);
            onCommit(next);
          },
        );
      },
    );
  }
}

class _AdjustmentControls extends StatelessWidget {
  const _AdjustmentControls({
    required this.settings,
    required this.onPreview,
    required this.onCommit,
  });

  final ImageEffectSettings settings;
  final ValueChanged<ImageEffectSettings> onPreview;
  final ValueChanged<ImageEffectSettings> onCommit;

  @override
  Widget build(BuildContext context) {
    final controls = <_Adjustment>[
      _Adjustment(
        label: 'Sáng',
        icon: Icons.brightness_6_outlined,
        value: settings.brightness,
        minimum: -1,
        maximum: 1,
        update: (value) => settings.copyWith(brightness: value),
      ),
      _Adjustment(
        label: 'Tương phản',
        icon: Icons.contrast,
        value: settings.contrast,
        minimum: -1,
        maximum: 1,
        update: (value) => settings.copyWith(contrast: value),
      ),
      _Adjustment(
        label: 'Bão hòa',
        icon: Icons.color_lens_outlined,
        value: settings.saturation,
        minimum: -1,
        maximum: 1,
        update: (value) => settings.copyWith(saturation: value),
      ),
      _Adjustment(
        label: 'Nhiệt độ',
        icon: Icons.thermostat_outlined,
        value: settings.warmth,
        minimum: -1,
        maximum: 1,
        update: (value) => settings.copyWith(warmth: value),
      ),
      _Adjustment(
        label: 'Làm mờ',
        icon: Icons.blur_on,
        value: settings.blur,
        minimum: 0,
        maximum: 10,
        update: (value) => settings.copyWith(blur: value),
      ),
      _Adjustment(
        label: 'Vignette',
        icon: Icons.vignette,
        value: settings.vignette,
        minimum: 0,
        maximum: 1,
        update: (value) => settings.copyWith(vignette: value),
      ),
    ];
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 12),
      scrollDirection: Axis.horizontal,
      itemCount: controls.length,
      separatorBuilder: (_, __) => const SizedBox(width: 10),
      itemBuilder: (_, index) {
        final control = controls[index];
        return SizedBox(
          width: 148,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(control.icon, size: 18),
              const SizedBox(width: 6),
              Text(control.label),
            ]),
            Slider(
              value: control.value,
              min: control.minimum,
              max: control.maximum,
              onChanged: (value) => onPreview(control.update(value)),
              onChangeEnd: (value) => onCommit(control.update(value)),
            ),
            Text(_displayValue(control)),
          ]),
        );
      },
    );
  }

  String _displayValue(_Adjustment control) {
    if (control.maximum == 10) return control.value.toStringAsFixed(1);
    return '${(control.value * 100).round()}';
  }
}

class _Adjustment {
  const _Adjustment({
    required this.label,
    required this.icon,
    required this.value,
    required this.minimum,
    required this.maximum,
    required this.update,
  });

  final String label;
  final IconData icon;
  final double value;
  final double minimum;
  final double maximum;
  final ImageEffectSettings Function(double value) update;
}

class _ChoiceSheet<T> extends StatelessWidget {
  const _ChoiceSheet({
    required this.title,
    required this.values,
    required this.selected,
    required this.label,
  });

  final String title;
  final List<T> values;
  final T? selected;
  final String Function(T value) label;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: values
                    .map(
                      (value) => ChoiceChip(
                        selected: value == selected,
                        label: Text(label(value)),
                        onSelected: (_) => Navigator.pop(context, value),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      );
}

class _MissingMedia extends StatelessWidget {
  const _MissingMedia();

  @override
  Widget build(BuildContext context) => const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.broken_image_outlined, size: 64),
          SizedBox(height: 8),
          Text('Không tìm thấy file nguồn'),
        ]),
      );
}
