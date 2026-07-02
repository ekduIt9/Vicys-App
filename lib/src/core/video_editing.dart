import 'models.dart';

/// Immutable non-destructive settings applied to one source video clip.
class VideoClipEdit {
  const VideoClipEdit({
    required this.sourcePath,
    this.trimStart = Duration.zero,
    this.trimEnd,
    this.speed = 1,
    this.volume = 1,
  });

  final String sourcePath;
  final Duration trimStart;
  final Duration? trimEnd;
  final double speed;
  final double volume;

  /// Rebuilds the effective clip state from the project's operation history.
  ///
  /// Invalid or legacy operations are ignored so older local drafts remain
  /// readable. This method performs no file I/O and is safe on the UI isolate.
  factory VideoClipEdit.fromProject(MediaProject project, int clipIndex) {
    var edit = VideoClipEdit(sourcePath: project.sourcePaths[clipIndex]);
    for (final operation in project.operations) {
      if (operation.parameters['clipIndex'] != clipIndex) continue;
      final parameters = operation.parameters;
      switch (operation.type) {
        case VideoEditOperation.trim:
          edit = edit.copyWith(
            trimStart: _milliseconds(parameters['startMs']) ?? edit.trimStart,
            trimEnd: _milliseconds(parameters['endMs']),
          );
        case VideoEditOperation.speed:
          edit = edit.copyWith(speed: _number(parameters['value'], 1));
        case VideoEditOperation.volume:
          edit = edit.copyWith(volume: _number(parameters['value'], 1));
      }
    }
    return edit;
  }

  VideoClipEdit copyWith({
    Duration? trimStart,
    Duration? trimEnd,
    double? speed,
    double? volume,
  }) =>
      VideoClipEdit(
        sourcePath: sourcePath,
        trimStart: trimStart ?? this.trimStart,
        trimEnd: trimEnd ?? this.trimEnd,
        speed: speed ?? this.speed,
        volume: volume ?? this.volume,
      );

  static Duration? _milliseconds(Object? value) =>
      value is num ? Duration(milliseconds: value.round()) : null;

  static double _number(Object? value, double fallback) =>
      value is num ? value.toDouble() : fallback;
}

/// Stable operation names stored in versioned project manifests.
abstract final class VideoEditOperation {
  static const trim = 'video_trim';
  static const split = 'video_split';
  static const speed = 'video_speed';
  static const volume = 'video_volume';
  static const delete = 'video_delete';
  static const filter = 'video_filter';
  static const text = 'video_text';
  static const sticker = 'video_sticker';
  static const audio = 'video_audio';
  static const transition = 'video_transition';
  static const canvas = 'video_canvas';
}

/// Effective project-wide composition rebuilt from non-destructive operations.
class VideoComposition {
  const VideoComposition({
    this.filter = VideoFilter.original,
    this.text,
    this.sticker,
    this.stickerX = .72,
    this.stickerY = .12,
    this.audioPath,
    this.transition = VideoTransition.none,
    this.aspectRatio = 9 / 16,
  });

  final VideoFilter filter;
  final String? text;
  final String? sticker;
  final double stickerX;
  final double stickerY;
  final String? audioPath;
  final VideoTransition transition;
  final double aspectRatio;
  static const _unset = Object();

  /// Replays supported operations, with the latest value winning per tool.
  factory VideoComposition.fromProject(MediaProject project) {
    var result = const VideoComposition();
    for (final operation in project.operations) {
      final value = operation.parameters['value'];
      switch (operation.type) {
        case VideoEditOperation.filter:
          result = result._copy(filter: VideoFilter.parse(value));
        case VideoEditOperation.text:
          result = result._copy(text: value is String ? value : null);
        case VideoEditOperation.sticker:
          result = result._copy(
            sticker: value is String ? value : null,
            stickerX: _normalized(
              operation.parameters['x'],
              result.stickerX,
            ),
            stickerY: _normalized(
              operation.parameters['y'],
              result.stickerY,
            ),
          );
        case VideoEditOperation.audio:
          result = result._copy(audioPath: value is String ? value : null);
        case VideoEditOperation.transition:
          result = result._copy(transition: VideoTransition.parse(value));
        case VideoEditOperation.canvas:
          result = result._copy(aspectRatio: _ratio(value));
      }
    }
    return result;
  }

  VideoComposition _copy({
    VideoFilter? filter,
    Object? text = _unset,
    Object? sticker = _unset,
    double? stickerX,
    double? stickerY,
    Object? audioPath = _unset,
    VideoTransition? transition,
    double? aspectRatio,
  }) =>
      VideoComposition(
        filter: filter ?? this.filter,
        text: identical(text, _unset) ? this.text : text as String?,
        sticker: identical(sticker, _unset) ? this.sticker : sticker as String?,
        stickerX: stickerX ?? this.stickerX,
        stickerY: stickerY ?? this.stickerY,
        audioPath:
            identical(audioPath, _unset) ? this.audioPath : audioPath as String?,
        transition: transition ?? this.transition,
        aspectRatio: aspectRatio ?? this.aspectRatio,
      );

  static double _ratio(Object? value) {
    final ratio = value is num ? value.toDouble() : 9 / 16;
    return ratio > 0 ? ratio : 9 / 16;
  }

  static double _normalized(Object? value, double fallback) {
    if (value is! num) return fallback;
    return value.toDouble().clamp(0, 1).toDouble();
  }
}

enum VideoFilter {
  original,
  vivid,
  mono,
  vintage,
  cool,
  warm,
  cinematic;

  static VideoFilter parse(Object? value) {
    for (final item in VideoFilter.values) {
      if (item.name == value) return item;
    }
    return VideoFilter.original;
  }

  /// Returns a 4x5 color matrix used by Flutter's GPU composition layer.
  List<double> get matrix => switch (this) {
        VideoFilter.original => _identity,
        VideoFilter.vivid => const [
            1.2, 0, 0, 0, 0, 0, 1.16, 0, 0, 0, 0, 0, 1.2, 0, 0, 0, 0, 0, 1, 0,
          ],
        VideoFilter.mono => const [
            .2126, .7152, .0722, 0, 0, .2126, .7152, .0722, 0, 0,
            .2126, .7152, .0722, 0, 0, 0, 0, 0, 1, 0,
          ],
        VideoFilter.vintage => const [
            .9, .18, .04, 0, 8, .08, .82, .04, 0, 4,
            .03, .12, .72, 0, -2, 0, 0, 0, 1, 0,
          ],
        VideoFilter.cool => const [
            .94, 0, .03, 0, -3, 0, 1, .04, 0, 0,
            .02, .04, 1.08, 0, 7, 0, 0, 0, 1, 0,
          ],
        VideoFilter.warm => const [
            1.1, .04, 0, 0, 8, 0, 1.02, 0, 0, 3,
            0, 0, .9, 0, -4, 0, 0, 0, 1, 0,
          ],
        VideoFilter.cinematic => const [
            1.06, .02, -.04, 0, 2, -.03, 1.02, .04, 0, 0,
            -.04, .1, 1.08, 0, 3, 0, 0, 0, 1, 0,
          ],
      };

  static const _identity = <double>[
    1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0,
  ];
}

enum VideoTransition {
  none,
  fade,
  slide,
  zoom;

  static VideoTransition parse(Object? value) {
    for (final item in VideoTransition.values) {
      if (item.name == value) return item;
    }
    return VideoTransition.none;
  }
}

/// Creates a project-wide operation with a serializable scalar value.
EditOperation createVideoSettingOperation(String type, Object? value) =>
    EditOperation(type: type, parameters: {'value': value});

/// Creates a sticker operation with canvas-relative coordinates.
///
/// Coordinates are clamped to zero through one so projects remain portable
/// across canvas sizes and aspect ratios.
EditOperation createStickerOperation({
  required String? sticker,
  required double x,
  required double y,
}) =>
    EditOperation(
      type: VideoEditOperation.sticker,
      parameters: {
        'value': sticker,
        'x': x.clamp(0, 1),
        'y': y.clamp(0, 1),
      },
    );

/// Creates a validated trim operation without modifying the source file.
EditOperation createTrimOperation({
  required int clipIndex,
  required Duration start,
  required Duration end,
}) {
  if (start.isNegative || end <= start) {
    throw ArgumentError('Trim end must be after a non-negative start.');
  }
  return EditOperation(
    type: VideoEditOperation.trim,
    parameters: {
      'clipIndex': clipIndex,
      'startMs': start.inMilliseconds,
      'endMs': end.inMilliseconds,
    },
  );
}

/// Creates a split marker for later preview composition and final rendering.
EditOperation createSplitOperation({
  required int clipIndex,
  required Duration position,
}) {
  if (position <= Duration.zero) {
    throw ArgumentError.value(position, 'position', 'Must be after clip start.');
  }
  return EditOperation(
    type: VideoEditOperation.split,
    parameters: {
      'clipIndex': clipIndex,
      'positionMs': position.inMilliseconds,
    },
  );
}

/// Creates a playback-speed operation in the supported 0.25x–4x range.
EditOperation createSpeedOperation({
  required int clipIndex,
  required double speed,
}) {
  if (speed < .25 || speed > 4) {
    throw ArgumentError.value(speed, 'speed', 'Must be between 0.25 and 4.');
  }
  return EditOperation(
    type: VideoEditOperation.speed,
    parameters: {'clipIndex': clipIndex, 'value': speed},
  );
}

/// Creates a normalized clip-volume operation, where zero is muted.
EditOperation createVolumeOperation({
  required int clipIndex,
  required double volume,
}) {
  if (volume < 0 || volume > 1) {
    throw ArgumentError.value(volume, 'volume', 'Must be between 0 and 1.');
  }
  return EditOperation(
    type: VideoEditOperation.volume,
    parameters: {'clipIndex': clipIndex, 'value': volume},
  );
}
