import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../core/image_effects.dart';
import '../core/models.dart';
import '../data/project_repository.dart';
import '../services/media_import_service.dart';
import 'editor_screen.dart';

enum CaptureMode { photo, video }

class CameraPage extends StatefulWidget {
  const CameraPage({
    required this.repository,
    required this.active,
    super.key,
  });

  final ProjectRepository repository;
  final bool active;

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
          ? ImageEffectSettings(preset: _cameraPreset).toOperation()
          : EditOperation(
              type: 'camera_filter',
              parameters: {'preset': _cameraPreset.name},
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
            ImageEffectSettings(preset: _cameraPreset).colorMatrix,
          ),
          child: CameraPreview(controller),
        ),
      ),
      Positioned(
        top: 12,
        left: 16,
        right: 16,
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          IconButton.filledTonal(
            tooltip: 'Flash',
            onPressed: _cycleFlash,
            icon: Icon(switch (_flashMode) {
              FlashMode.auto => Icons.flash_auto,
              FlashMode.always => Icons.flash_on,
              _ => Icons.flash_off,
            }),
          ),
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
          _CameraFilterStrip(
            selected: _cameraPreset,
            onSelected: (preset) => setState(() => _cameraPreset = preset),
          ),
          const SizedBox(height: 10),
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
        ]),
      ),
    ]);
  }
}

class _CameraFilterStrip extends StatelessWidget {
  const _CameraFilterStrip({
    required this.selected,
    required this.onSelected,
  });

  final ImagePreset selected;
  final ValueChanged<ImagePreset> onSelected;

  @override
  Widget build(BuildContext context) {
    const labels = {
      ImagePreset.original: 'None',
      ImagePreset.vivid: 'Neon',
      ImagePreset.mono: 'Mono',
      ImagePreset.vintage: 'Golden',
      ImagePreset.cool: 'Mist',
    };
    return SizedBox(
      height: 72,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        scrollDirection: Axis.horizontal,
        itemCount: ImagePreset.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 13),
        itemBuilder: (_, index) {
          final preset = ImagePreset.values[index];
          final active = preset == selected;
          return GestureDetector(
            onTap: () => onSelected(preset),
            child: SizedBox(
              width: 58,
              child: Column(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xaa202027),
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
                        : Icons.lens_blur,
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
