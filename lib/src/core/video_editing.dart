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
}

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
