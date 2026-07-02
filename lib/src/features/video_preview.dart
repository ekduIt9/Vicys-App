import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../core/video_editing.dart';

/// Native-backed preview for one selected non-destructive video clip.
class VideoPreview extends StatefulWidget {
  const VideoPreview({
    required this.clip,
    required this.composition,
    required this.position,
    required this.duration,
    required this.onStickerMoved,
    super.key,
  });

  final VideoClipEdit clip;
  final VideoComposition composition;
  final ValueNotifier<Duration> position;
  final ValueNotifier<Duration> duration;
  final ValueChanged<Offset> onStickerMoved;

  @override
  State<VideoPreview> createState() => VideoPreviewState();
}

/// Owns and releases the native decoder used by [VideoPreview].
class VideoPreviewState extends State<VideoPreview> {
  VideoPlayerController? _controller;
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _loadedAudioPath;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void didUpdateWidget(covariant VideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clip.sourcePath != widget.clip.sourcePath) {
      _open();
    } else {
      _applyClipSettings();
    }
    if (oldWidget.composition.audioPath != widget.composition.audioPath) {
      _prepareAudio();
    }
  }

  /// Seeks the native decoder while clamping to the selected trim range.
  Future<void> seek(Duration requested) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final end = widget.clip.trimEnd ?? controller.value.duration;
    final target = requested < widget.clip.trimStart
        ? widget.clip.trimStart
        : requested > end
            ? end
            : requested;
    await controller.seekTo(target);
    if (_loadedAudioPath != null) {
      try {
        await _audioPlayer.seek(target - widget.clip.trimStart);
      } catch (_) {
        _loadedAudioPath = null;
      }
    }
  }

  /// Toggles playback without rebuilding the editor or timeline.
  Future<void> togglePlayback() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      await controller.pause();
      if (_loadedAudioPath != null) {
        try {
          await _audioPlayer.pause();
        } catch (_) {
          _loadedAudioPath = null;
        }
      }
    } else {
      await controller.play();
      if (_loadedAudioPath != null) {
        try {
          await _audioPlayer.seek(
            controller.value.position - widget.clip.trimStart,
          );
          await _audioPlayer.resume();
        } catch (_) {
          _loadedAudioPath = null;
        }
      }
    }
    if (mounted) setState(() {});
  }

  /// Creates and initializes the native video decoder for the selected clip.
  ///
  /// The previous controller is disposed first. Initialization failures are
  /// retained as a recoverable UI state and never modify the source file.
  Future<void> _open() async {
    final previous = _controller;
    _controller = null;
    await previous?.dispose();
    final controller = VideoPlayerController.file(File(widget.clip.sourcePath));
    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _controller = controller;
      controller.addListener(_onTick);
      await _applyClipSettings();
      await _prepareAudio();
      widget.duration.value = widget.clip.trimEnd ?? controller.value.duration;
      setState(() => _error = null);
    } catch (error) {
      await controller.dispose();
      if (mounted) setState(() => _error = error);
    }
  }

  /// Loads the selected local soundtrack without copying or decoding it in Dart.
  Future<void> _prepareAudio() async {
    final path = widget.composition.audioPath;
    if (path == null || path.isEmpty) {
      if (_loadedAudioPath != null) {
        try {
          await _audioPlayer.stop();
        } catch (_) {
          // Video preview remains usable when the optional soundtrack fails.
        }
      }
      _loadedAudioPath = null;
      return;
    }
    try {
      await _audioPlayer.setSource(DeviceFileSource(path));
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      _loadedAudioPath = path;
    } catch (_) {
      _loadedAudioPath = null;
    }
  }

  /// Applies non-destructive speed, volume and trim-start preview settings.
  Future<void> _applyClipSettings() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    await controller.setPlaybackSpeed(widget.clip.speed);
    await controller.setVolume(widget.clip.volume);
    final end = widget.clip.trimEnd ?? controller.value.duration;
    widget.duration.value = end;
    if (controller.value.position < widget.clip.trimStart ||
        controller.value.position > end) {
      await controller.seekTo(widget.clip.trimStart);
    }
  }

  void _onTick() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final end = widget.clip.trimEnd ?? controller.value.duration;
    if (controller.value.position >= end && controller.value.isPlaying) {
      controller.pause();
      if (_loadedAudioPath != null) _audioPlayer.pause();
      controller.seekTo(widget.clip.trimStart);
      if (_loadedAudioPath != null) _audioPlayer.seek(Duration.zero);
    }
    widget.position.value = controller.value.position;
  }

  @override
  void dispose() {
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_error != null) {
      return _VideoError(onRetry: _open);
    }
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    Widget video = Center(
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: VideoPlayer(controller),
      ),
    );
    video = ColorFiltered(
      colorFilter: ColorFilter.matrix(widget.composition.filter.matrix),
      child: video,
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (child, animation) => switch (
              widget.composition.transition) {
            VideoTransition.slide => SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(.12, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            VideoTransition.zoom => ScaleTransition(
                scale: Tween<double>(begin: .92, end: 1).animate(animation),
                child: child,
              ),
            _ => FadeTransition(opacity: animation, child: child),
          },
          child: KeyedSubtree(
            key: ValueKey(widget.clip.sourcePath),
            child: video,
          ),
        ),
        if (widget.composition.text case final text?)
          Positioned(
            left: 20,
            right: 20,
            bottom: 72,
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                shadows: [Shadow(color: Colors.black, blurRadius: 6)],
              ),
            ),
          ),
        if (widget.composition.sticker case final sticker?)
          Positioned.fill(
            child: _DraggableSticker(
              sticker: sticker,
              position: Offset(
                widget.composition.stickerX,
                widget.composition.stickerY,
              ),
              onCommitted: widget.onStickerMoved,
            ),
          ),
        Center(
          child: IconButton.filledTonal(
            tooltip: controller.value.isPlaying ? 'Tạm dừng' : 'Phát video',
            iconSize: 38,
            onPressed: togglePlayback,
            icon: Icon(
              controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
            ),
          ),
        ),
      ],
    );
  }
}

class _DraggableSticker extends StatefulWidget {
  const _DraggableSticker({
    required this.sticker,
    required this.position,
    required this.onCommitted,
  });

  final String sticker;
  final Offset position;
  final ValueChanged<Offset> onCommitted;

  @override
  State<_DraggableSticker> createState() => _DraggableStickerState();
}

class _DraggableStickerState extends State<_DraggableSticker> {
  late Offset position = widget.position;

  @override
  void didUpdateWidget(covariant _DraggableSticker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.position != widget.position) position = widget.position;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          const size = 64.0;
          final width = (constraints.maxWidth - size)
              .clamp(1.0, double.infinity)
              .toDouble();
          final height =
              (constraints.maxHeight - size)
                  .clamp(1.0, double.infinity)
                  .toDouble();
          return Stack(
            children: [
              Positioned(
                left: position.dx * width,
                top: position.dy * height,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (details) => setState(() {
                    position = Offset(
                      (position.dx + details.delta.dx / width)
                          .clamp(0, 1)
                          .toDouble(),
                      (position.dy + details.delta.dy / height)
                          .clamp(0, 1)
                          .toDouble(),
                    );
                  }),
                  onPanEnd: (_) => widget.onCommitted(position),
                  child: SizedBox.square(
                    dimension: size,
                    child: Center(
                      child: Text(
                        widget.sticker,
                        style: const TextStyle(fontSize: 52),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
}

class _VideoError extends StatelessWidget {
  const _VideoError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 8),
            const Text('Không thể mở video. File gốc vẫn an toàn.'),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      );
}
