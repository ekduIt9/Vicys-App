import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../core/image_effects.dart';
import '../core/models.dart';
import '../data/project_repository.dart';
import '../services/media_import_service.dart';
import 'editor_screen.dart';

enum CaptureMode { photo, video }

enum CameraEffectCategory { trending, beauty, filters, effects }

class CameraPage extends StatefulWidget {
  const CameraPage({
    required this.repository,
    required this.active,
    this.onClose,
    super.key,
  });

  final ProjectRepository repository;
  final bool active;
  final VoidCallback? onClose;

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage>
    with WidgetsBindingObserver {
  final MediaImportService _mediaImportService = MediaImportService();
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  CaptureMode _mode = CaptureMode.photo;
  FlashMode _flashMode = FlashMode.off;
  String? _error;
  bool _busy = false;
  bool _recording = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  ImagePreset _cameraPreset = ImagePreset.original;
  CameraEffectCategory _effectCategory = CameraEffectCategory.trending;
  double _filterIntensity = .8;
  double _exposure = 0;
  double _minimumExposure = 0;
  double _maximumExposure = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.active) unawaited(_initialize());
  }

  @override
  void didUpdateWidget(covariant CameraPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active) {
      unawaited(_initialize());
    } else if (oldWidget.active && !widget.active) {
      unawaited(_releaseCamera());
    }
  }

  /// Releases camera resources when inactive and reacquires them on resume.
  ///
  /// The camera plugin does not manage application lifecycle automatically.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.active) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(_releaseCamera());
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_initialize());
    }
  }

  /// Discovers cameras and initializes a high-resolution preview.
  ///
  /// Initialization may display native camera/microphone permission prompts.
  /// Errors are mapped to user-facing recovery text; no exception escapes UI.
  Future<void> _initialize({CameraDescription? preferred}) async {
    if (_busy || (_controller?.value.isInitialized ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _cameras = _cameras.isEmpty ? await availableCameras() : _cameras;
      if (_cameras.isEmpty) throw StateError('Thiết bị không có camera.');
      final description = preferred ?? _preferredCamera();
      final controller = CameraController(
        description,
        ResolutionPreset.high,
        enableAudio: true,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      await controller.setFlashMode(_flashMode);
      _minimumExposure = await controller.getMinExposureOffset();
      _maximumExposure = await controller.getMaxExposureOffset();
      if (!mounted || !widget.active) {
        await controller.dispose();
        return;
      }
      await _controller?.dispose();
      setState(() => _controller = controller);
    } on CameraException catch (error) {
      _setError(_cameraErrorMessage(error));
    } catch (error) {
      _setError(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  CameraDescription _preferredCamera() => _cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

  /// Captures one photo, persists it, creates a project and opens the editor.
  Future<void> _takePhoto() async {
    final controller = _controller;
    if (_busy || controller == null || !controller.value.isInitialized) return;
    setState(() => _busy = true);
    try {
      final capture = await controller.takePicture();
      final media = await _mediaImportService.persistCaptured(
        capture,
        ProjectKind.image,
      );
      await _openEditor([media]);
    } on CameraException catch (error) {
      _setError(_cameraErrorMessage(error));
    } catch (_) {
      _setError('Không thể lưu ảnh. Ảnh cũ của bạn vẫn an toàn.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Starts or stops video recording and persists the completed file.
  ///
  /// Only one recording can exist at a time. Leaving the camera stops and
  /// discards an unfinished recording rather than holding native resources.
  Future<void> _toggleRecording() async {
    final controller = _controller;
    if (_busy || controller == null || !controller.value.isInitialized) return;
    setState(() => _busy = true);
    try {
      if (_recording) {
        final capture = await controller.stopVideoRecording();
        _stopRecordingClock();
        setState(() => _recording = false);
        final media = await _mediaImportService.persistCaptured(
          capture,
          ProjectKind.video,
        );
        await _openEditor([media]);
      } else {
        await controller.prepareForVideoRecording();
        await controller.startVideoRecording();
        _startRecordingClock();
        setState(() => _recording = true);
      }
    } on CameraException catch (error) {
      _setError(_cameraErrorMessage(error));
    } catch (_) {
      _setError('Không thể hoàn tất video. Hãy kiểm tra dung lượng thiết bị.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Switches between available front and rear cameras.
  Future<void> _switchCamera() async {
    if (_busy || _recording || _cameras.length < 2) return;
    final current = _controller?.description;
    final next = _cameras.firstWhere(
      (camera) => camera.lensDirection != current?.lensDirection,
      orElse: () => _cameras.first,
    );
    await _releaseCamera();
    await _initialize(preferred: next);
  }

  /// Cycles supported flash modes and applies the result to preview/capture.
  Future<void> _cycleFlash() async {
    final controller = _controller;
    if (controller == null || _recording) return;
    final next = switch (_flashMode) {
      FlashMode.off => FlashMode.auto,
      FlashMode.auto => FlashMode.always,
      _ => FlashMode.off,
    };
    try {
      await controller.setFlashMode(next);
      if (mounted) setState(() => _flashMode = next);
    } on CameraException {
      _setError('Camera này không hỗ trợ chế độ flash đã chọn.');
    }
  }

  /// Creates a SQLite project that owns the durable imported media paths.
  Future<void> _openEditor(List<ImportedMedia> media) async {
    if (media.isEmpty || !mounted) return;
    final kind = media.any((item) => item.kind == ProjectKind.video)
        ? ProjectKind.video
        : ProjectKind.image;
    var project = await widget.repository.create(
      kind,
      sourcePaths: media.map((item) => item.path).toList(growable: false),
      title: media.first.originalName,
    );
    if (_cameraPreset != ImagePreset.original) {
      final operation = kind == ProjectKind.image
          ? ImageEffectSettings(
              preset: _cameraPreset,
              intensity: _filterIntensity,
            ).toOperation()
          : EditOperation(
              type: 'camera_filter',
              parameters: {
                'preset': _cameraPreset.name,
                'intensity': _filterIntensity,
                'exposure': _exposure,
              },
            );
      project = project.copyWith(
        operations: [operation],
        revision: project.revision + 1,
        updatedAt: DateTime.now(),
      );
      await widget.repository.save(project);
    }
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => EditorScreen(
        project: project,
        repository: widget.repository,
      ),
    ));
  }

  void _startRecordingClock() {
    _recordingDuration = Duration.zero;
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _recordingDuration += const Duration(seconds: 1));
      }
    });
  }

  void _stopRecordingClock() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
  }

  /// Disposes preview and stops timers without blocking widget disposal.
  Future<void> _releaseCamera() async {
    _stopRecordingClock();
    final controller = _controller;
    _controller = null;
    _recording = false;
    if (mounted) setState(() {});
    await controller?.dispose();
  }

  void _setError(String message) {
    if (mounted) setState(() => _error = message);
  }

  /// Applies camera exposure within hardware-supported EV bounds.
  ///
  /// The camera plugin performs native device I/O. Unsupported values are
  /// clamped and failures keep the previous preview exposure.
  Future<void> _setExposure(double value) async {
    final controller = _controller;
    if (controller == null) return;
    final clamped =
        value.clamp(_minimumExposure, _maximumExposure).toDouble();
    try {
      final applied = await controller.setExposureOffset(clamped);
      if (mounted) setState(() => _exposure = applied);
    } on CameraException {
      _setError('Thiết bị không hỗ trợ thay đổi độ phơi sáng.');
    }
  }

  String _cameraErrorMessage(CameraException error) => switch (error.code) {
        'CameraAccessDenied' ||
        'CameraAccessDeniedWithoutPrompt' =>
          'Vicys cần quyền Camera. Hãy cấp quyền trong Cài đặt rồi thử lại.',
        'AudioAccessDenied' ||
        'AudioAccessDeniedWithoutPrompt' =>
          'Vicys cần quyền Microphone để quay video có âm thanh.',
        'CameraAccessRestricted' || 'AudioAccessRestricted' =>
          'Quyền camera hoặc microphone đang bị giới hạn trên thiết bị.',
        _ => 'Không thể mở camera (${error.code}). Hãy thử lại.',
      };

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recordingTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_error != null) {
      return _CameraError(message: _error!, onRetry: _initialize);
    }
    if (!widget.active || controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Stack(fit: StackFit.expand, children: [
      Center(
        child: ColorFiltered(
          colorFilter: ColorFilter.matrix(
            ImageEffectSettings(
              preset: _cameraPreset,
              intensity: _filterIntensity,
            ).colorMatrix,
          ),
          child: CameraPreview(controller),
        ),
      ),
      const Center(child: IgnorePointer(child: _FocusReticle())),
      Positioned(
        top: 12,
        left: 16,
        right: 16,
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            if (widget.onClose != null)
              IconButton.filledTonal(
                tooltip: 'Đóng camera',
                onPressed: widget.onClose,
                icon: const Icon(Icons.close),
              ),
            IconButton.filledTonal(
              tooltip: 'Flash',
              onPressed: _cycleFlash,
              icon: Icon(switch (_flashMode) {
                FlashMode.auto => Icons.flash_auto,
                FlashMode.always => Icons.flash_on,
                _ => Icons.flash_off,
              }),
            ),
          ]),
          if (_recording)
            _RecordingTime(duration: _recordingDuration),
          IconButton.filledTonal(
            tooltip: 'Đổi camera',
            onPressed: _switchCamera,
            icon: const Icon(Icons.cameraswitch_outlined),
          ),
        ]),
      ),
      Positioned(
        bottom: 16,
        left: 0,
        right: 0,
        child: Column(children: [
          _EffectCategoryTabs(
            selected: _effectCategory,
            onSelected: (category) =>
                setState(() => _effectCategory = category),
          ),
          const SizedBox(height: 6),
          _CameraFilterStrip(
            category: _effectCategory,
            selected: _cameraPreset,
            onSelected: (preset) => setState(() => _cameraPreset = preset),
          ),
          if (_cameraPreset != ImagePreset.original)
            _FilterIntensity(
              value: _filterIntensity,
              onChanged: (value) =>
                  setState(() => _filterIntensity = value),
            ),
          const SizedBox(height: 6),
          SegmentedButton<CaptureMode>(
            segments: const [
              ButtonSegment(value: CaptureMode.photo, label: Text('ẢNH')),
              ButtonSegment(value: CaptureMode.video, label: Text('VIDEO')),
            ],
            selected: {_mode},
            onSelectionChanged: _recording
                ? null
                : (value) => setState(() => _mode = value.first),
          ),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            const _CameraMetric(label: 'ISO', value: 'AUTO'),
            Semantics(
              button: true,
              label: _mode == CaptureMode.photo
                  ? 'Chụp ảnh'
                  : (_recording ? 'Dừng quay video' : 'Bắt đầu quay video'),
              child: GestureDetector(
                onTap: _busy
                    ? null
                    : (_mode == CaptureMode.photo
                        ? _takePhoto
                        : _toggleRecording),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _recording ? Colors.red : Colors.white,
                    border: Border.all(color: Colors.white, width: 5),
                  ),
                  child: _busy
                      ? const Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(strokeWidth: 3),
                        )
                      : null,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => _showExposureSheet(context),
              child: _CameraMetric(
                label: 'EV',
                value: '${_exposure >= 0 ? '+' : ''}${_exposure.toStringAsFixed(1)}',
              ),
            ),
          ]),
        ]),
      ),
    ]);
  }

  Future<void> _showExposureSheet(BuildContext context) async {
    if (_minimumExposure == _maximumExposure) return;
    var preview = _exposure;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xff1c1b1b),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Độ phơi sáng ${preview.toStringAsFixed(1)} EV'),
            Slider(
              min: _minimumExposure,
              max: _maximumExposure,
              value: preview.clamp(
                _minimumExposure,
                _maximumExposure,
              ).toDouble(),
              onChanged: (value) {
                setSheetState(() => preview = value);
                _setExposure(value);
              },
            ),
          ]),
        ),
      ),
    );
  }
}

class _CameraFilterStrip extends StatelessWidget {
  const _CameraFilterStrip({
    required this.category,
    required this.selected,
    required this.onSelected,
  });

  final CameraEffectCategory category;
  final ImagePreset selected;
  final ValueChanged<ImagePreset> onSelected;

  @override
  Widget build(BuildContext context) {
    const labels = {
      ImagePreset.original: 'None',
      ImagePreset.vivid: 'Vivid',
      ImagePreset.mono: 'Mono',
      ImagePreset.vintage: 'Golden',
      ImagePreset.cool: 'Mist',
      ImagePreset.neon: 'Neon',
      ImagePreset.dreamy: 'Dreamy',
      ImagePreset.film: 'Film',
      ImagePreset.tealOrange: 'Teal',
      ImagePreset.rose: 'Rosy',
      ImagePreset.sunset: 'Sunset',
      ImagePreset.fade: 'Fade',
      ImagePreset.cyber: 'Cyber',
      ImagePreset.mint: 'Mint',
    };
    final presets = switch (category) {
      CameraEffectCategory.trending => const [
          ImagePreset.original,
          ImagePreset.neon,
          ImagePreset.dreamy,
          ImagePreset.tealOrange,
          ImagePreset.rose,
          ImagePreset.cyber,
        ],
      CameraEffectCategory.beauty => const [
          ImagePreset.original,
          ImagePreset.dreamy,
          ImagePreset.rose,
          ImagePreset.fade,
          ImagePreset.mint,
          ImagePreset.sunset,
        ],
      CameraEffectCategory.filters => ImagePreset.values,
      CameraEffectCategory.effects => const [
          ImagePreset.original,
          ImagePreset.cyber,
          ImagePreset.neon,
          ImagePreset.film,
          ImagePreset.mono,
          ImagePreset.vintage,
        ],
    };
    return SizedBox(
      height: 82,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        scrollDirection: Axis.horizontal,
        itemCount: presets.length,
        separatorBuilder: (_, __) => const SizedBox(width: 13),
        itemBuilder: (_, index) {
          final preset = presets[index];
          final active = preset == selected;
          return GestureDetector(
            onTap: () => onSelected(preset),
            child: SizedBox(
              width: 64,
              child: Column(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _presetGradient(preset),
                    border: Border.all(
                      color: active
                          ? const Color(0xffc0c1ff)
                          : Colors.white24,
                      width: active ? 3 : 1,
                    ),
                  ),
                  child: Icon(
                    preset == ImagePreset.original
                        ? Icons.block
                        : _presetIcon(preset),
                    size: 22,
                  ),
                ),
                const SizedBox(height: 3),
                Text(labels[preset]!, style: const TextStyle(fontSize: 10)),
              ]),
            ),
          );
        },
      ),
    );
  }

  LinearGradient _presetGradient(ImagePreset preset) {
    final colors = switch (preset) {
      ImagePreset.neon || ImagePreset.cyber =>
        const [Color(0xff00e5ff), Color(0xffff4fd8)],
      ImagePreset.dreamy || ImagePreset.rose =>
        const [Color(0xffffb0cd), Color(0xffc0c1ff)],
      ImagePreset.sunset || ImagePreset.vintage =>
        const [Color(0xffff9a44), Color(0xff6b2d5c)],
      ImagePreset.cool || ImagePreset.mint =>
        const [Color(0xff4edea3), Color(0xff5376ff)],
      ImagePreset.mono => const [Color(0xffeeeeee), Color(0xff333333)],
      ImagePreset.film || ImagePreset.fade =>
        const [Color(0xffc9b79c), Color(0xff49413a)],
      ImagePreset.tealOrange =>
        const [Color(0xff00a7a7), Color(0xffff8b3d)],
      _ => const [Color(0xff353534), Color(0xff1c1b1b)],
    };
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: colors,
    );
  }

  IconData _presetIcon(ImagePreset preset) => switch (preset) {
        ImagePreset.neon || ImagePreset.cyber => Icons.bolt,
        ImagePreset.dreamy || ImagePreset.fade => Icons.cloud_outlined,
        ImagePreset.rose => Icons.favorite_border,
        ImagePreset.sunset => Icons.wb_sunny_outlined,
        ImagePreset.mono => Icons.monochrome_photos,
        ImagePreset.film || ImagePreset.vintage => Icons.movie_filter,
        ImagePreset.cool || ImagePreset.mint => Icons.ac_unit,
        ImagePreset.tealOrange => Icons.palette_outlined,
        _ => Icons.lens_blur,
      };
}

class _EffectCategoryTabs extends StatelessWidget {
  const _EffectCategoryTabs({
    required this.selected,
    required this.onSelected,
  });

  final CameraEffectCategory selected;
  final ValueChanged<CameraEffectCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    const labels = {
      CameraEffectCategory.trending: 'Trending',
      CameraEffectCategory.beauty: 'Beauty',
      CameraEffectCategory.filters: 'Filters',
      CameraEffectCategory.effects: 'Effects',
    };
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: CameraEffectCategory.values.map((category) {
        final active = category == selected;
        return InkWell(
          onTap: () => onSelected(category),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.only(bottom: 5),
            decoration: active
                ? const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Color(0xffc0c1ff),
                        width: 3,
                      ),
                    ),
                  )
                : null,
            child: Text(
              labels[category]!,
              style: TextStyle(
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                color: active ? Colors.white : Colors.white60,
              ),
            ),
          ),
        );
      }).toList(growable: false),
    );
  }
}

class _FilterIntensity extends StatelessWidget {
  const _FilterIntensity({
    required this.value,
    required this.onChanged,
  });

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 36,
        child: Row(children: [
          const SizedBox(width: 24),
          const Text('Intensity', style: TextStyle(fontSize: 11)),
          Expanded(
            child: Slider(value: value, onChanged: onChanged),
          ),
          SizedBox(
            width: 42,
            child: Text(
              '${(value * 100).round()}',
              style: const TextStyle(
                fontFamily: 'monospace',
                color: Color(0xffc0c1ff),
              ),
            ),
          ),
        ]),
      );
}

class _CameraMetric extends StatelessWidget {
  const _CameraMetric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              color: Colors.white60,
              letterSpacing: 1.2,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'monospace',
              color: Color(0xffc0c1ff),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ],
      );
}

class _FocusReticle extends StatelessWidget {
  const _FocusReticle();

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 116,
        height: 116,
        child: Stack(children: [
          ...[
            Alignment.topLeft,
            Alignment.topRight,
            Alignment.bottomLeft,
            Alignment.bottomRight,
          ].map(
            (alignment) => Align(
              alignment: alignment,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  border: Border(
                    top: alignment.y < 0
                        ? const BorderSide(color: Colors.white70, width: 3)
                        : BorderSide.none,
                    bottom: alignment.y > 0
                        ? const BorderSide(color: Colors.white70, width: 3)
                        : BorderSide.none,
                    left: alignment.x < 0
                        ? const BorderSide(color: Colors.white70, width: 3)
                        : BorderSide.none,
                    right: alignment.x > 0
                        ? const BorderSide(color: Colors.white70, width: 3)
                        : BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          const Center(
            child: Text(
              'AF',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 19,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ]),
      );
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.no_photography_outlined, size: 64),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ]),
        ),
      );
}

class _RecordingTime extends StatelessWidget {
  const _RecordingTime({required this.duration});
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return Chip(
      avatar: const Icon(Icons.fiber_manual_record, color: Colors.red, size: 16),
      label: Text('$minutes:$seconds'),
    );
  }
}
