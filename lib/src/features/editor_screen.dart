import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import '../core/image_effects.dart';
import '../core/models.dart';
import '../data/project_repository.dart';
import '../services/services.dart';
import '../ui/vicys_design.dart';
import 'video_timeline.dart';

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
  final renderService = DemoRenderService();
  late ImageEffectSettings imageEffects =
      ImageEffectSettings.fromProject(widget.project);
  String? imagePanel;

  void apply(String type) {
    setState(() => history.apply(EditOperation(type: type)));
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
      imageEffects = ImageEffectSettings.fromProject(history.project);
    });
    autosave.schedule(history.project);
  }

  void redo() {
    setState(() {
      history.redo();
      imageEffects = ImageEffectSettings.fromProject(history.project);
    });
    autosave.schedule(history.project);
  }

  void handleTool(String tool) {
    if (history.project.kind == ProjectKind.image &&
        (tool == 'Màu' || tool == 'Filter')) {
      setState(() => imagePanel = tool);
      return;
    }
    apply(tool);
  }

  Future<void> export() async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đang xuất'),
        content: StreamBuilder<double>(
          stream: renderService.export(history.project),
          builder: (context, snapshot) {
            final progress = snapshot.data ?? 0;
            if (progress == 1) {
              Future<void>.delayed(Duration.zero, () {
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã hoàn thành bản xuất demo')),
                );
              });
            }
            return LinearProgressIndicator(value: progress);
          },
        ),
      ),
    );
  }

  /// Persists current operations before returning to the media library.
  Future<void> finish() async {
    await widget.repository.save(history.project);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    autosave.dispose();
    widget.repository.save(history.project);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tools = history.project.kind == ProjectKind.image
        ? const [('Cắt', Icons.crop), ('Màu', Icons.tune), ('Filter', Icons.filter_vintage),
            ('Chữ', Icons.text_fields), ('Sticker', Icons.emoji_emotions_outlined), ('Vẽ', Icons.brush)]
        : const [('Cắt', Icons.content_cut), ('Tách', Icons.call_split), ('Tốc độ', Icons.speed),
            ('Màu', Icons.tune), ('Chữ', Icons.text_fields), ('Nhạc', Icons.music_note), ('Chuyển cảnh', Icons.auto_awesome)];
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
          TextButton(
            onPressed: history.project.kind == ProjectKind.image
                ? finish
                : export,
            child: Text(
              history.project.kind == ProjectKind.image ? 'Xong' : 'Xuất',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: Column(children: [
        Expanded(child: Center(child: AspectRatio(
          aspectRatio: history.project.kind == ProjectKind.image ? 1 : 9 / 16,
          child: Container(
            decoration: BoxDecoration(color: const Color(0xff202027), borderRadius: BorderRadius.circular(12)),
            clipBehavior: Clip.antiAlias,
            child: _ProjectPreview(
              project: history.project,
              imageEffects: imageEffects,
            ),
          ),
        ))),
        if (history.project.kind == ProjectKind.video)
          VideoTimeline(
            project: history.project,
            onOperation: apply,
          ),
        if (history.project.kind == ProjectKind.image && imagePanel != null)
          ImageEffectsPanel(
            mode: imagePanel!,
            settings: imageEffects,
            onPreview: (settings) => setState(() => imageEffects = settings),
            onCommit: commitImageEffects,
            onClose: () => setState(() => imagePanel = null),
          )
        else
          SizedBox(height: 92, child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            scrollDirection: Axis.horizontal,
            itemCount: tools.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, index) => InkWell(
              onTap: () => handleTool(tools[index].$1),
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(width: 68, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(tools[index].$2), const SizedBox(height: 6), Text(tools[index].$1, maxLines: 1),
              ])),
            ),
          )),
      ]),
    );
  }
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
