import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Imports user-selected audio into durable application-owned storage.
class AudioImportService {
  AudioImportService({
    FilePicker? picker,
    Uuid? uuid,
  })  : _picker = picker ?? FilePicker.platform,
        _uuid = uuid ?? const Uuid();

  final FilePicker _picker;
  final Uuid _uuid;

  /// Opens the native audio picker and returns a durable copied file path.
  ///
  /// The selected source is streamed to application documents without loading
  /// it fully into memory. The source is never deleted. Returns `null` on
  /// cancellation and removes a partial destination if copying fails.
  Future<String?> pickAndPersist() async {
    final result = await _picker.pickFiles(type: FileType.audio);
    final sourcePath = result?.files.single.path;
    if (sourcePath == null) return null;
    final source = File(sourcePath);
    final directory = await _audioDirectory();
    final extension = path.extension(sourcePath);
    final destination = File(
      path.join(directory.path, '${_uuid.v4()}$extension'),
    );
    final sink = destination.openWrite();
    try {
      await sink.addStream(source.openRead());
      await sink.close();
      return destination.path;
    } catch (_) {
      await sink.close();
      if (await destination.exists()) await destination.delete();
      rethrow;
    }
  }

  Future<Directory> _audioDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(path.join(documents.path, 'media', 'audio'));
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }
}
