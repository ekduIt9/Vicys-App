import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Durable local backing-track metadata.
class BackingTrack {
  const BackingTrack({required this.path, required this.name});

  final String path;
  final String name;
}

/// Owns imported backing-track files and their single native playback voice.
class BackingTrackService {
  BackingTrackService({FilePicker? picker})
      : _picker = picker ?? FilePicker.platform;

  final FilePicker _picker;
  final AudioPlayer _player = AudioPlayer();
  BackingTrack? current;
  Duration durationValue = Duration.zero;
  Duration positionValue = Duration.zero;

  Stream<Duration> get position => _player.onPositionChanged;
  Stream<Duration> get duration => _player.onDurationChanged;
  Stream<PlayerState> get state => _player.onPlayerStateChanged;
  Stream<bool> get isPlaying =>
      state.map((value) => value == PlayerState.playing);

  /// Picks one audio file and stream-copies it into app-owned storage.
  ///
  /// Returns `null` on cancellation. The source file is never modified and a
  /// partial destination is removed when copying fails.
  Future<BackingTrack?> importFromDevice() async {
    final result = await _picker.pickFiles(type: FileType.audio);
    final selected = result?.files.single;
    final sourcePath = selected?.path;
    if (selected == null || sourcePath == null) return null;
    final directory = await _trackDirectory();
    final safeName = selected.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final destination = File(
      '${directory.path}${Platform.pathSeparator}'
      '${DateTime.now().millisecondsSinceEpoch}_$safeName',
    );
    final sink = destination.openWrite();
    try {
      await sink.addStream(File(sourcePath).openRead());
      await sink.close();
    } catch (_) {
      await sink.close();
      if (await destination.exists()) await destination.delete();
      rethrow;
    }
    current = BackingTrack(path: destination.path, name: selected.name);
    await _player.setSource(DeviceFileSource(destination.path));
    durationValue = await _player.getDuration() ?? Duration.zero;
    positionValue = Duration.zero;
    return current;
  }

  /// Toggles the imported track while preserving its current position.
  Future<void> toggle() async {
    if (current == null) return;
    if (_player.state == PlayerState.playing) {
      await _player.pause();
    } else {
      await _player.resume();
    }
  }

  /// Seeks within the current track; values outside duration are plugin-clamped.
  Future<void> seek(Duration position) async {
    if (current != null) {
      positionValue = position;
      await _player.seek(position);
    }
  }

  /// Stops playback and releases the native player.
  Future<void> dispose() => _player.dispose();

  Future<Directory> _trackDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(
      '${documents.path}${Platform.pathSeparator}backing_tracks',
    );
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }
}
