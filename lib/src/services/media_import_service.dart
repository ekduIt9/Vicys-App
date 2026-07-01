import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../core/models.dart';

class ImportedMedia {
  const ImportedMedia({
    required this.path,
    required this.kind,
    required this.originalName,
  });

  final String path;
  final ProjectKind kind;
  final String originalName;
}

/// Imports gallery and camera output into durable application storage.
class MediaImportService {
  MediaImportService({
    ImagePicker? picker,
    Uuid? uuid,
  })  : _picker = picker ?? ImagePicker(),
        _uuid = uuid ?? const Uuid();

  final ImagePicker _picker;
  final Uuid _uuid;

  /// Opens the system picker and imports all selected images and videos.
  ///
  /// The picker may temporarily background the application. Selected files are
  /// stream-copied into app documents without loading entire videos into RAM.
  /// Returns an empty list when the user cancels.
  Future<List<ImportedMedia>> importFromGallery() async {
    final files = await _picker.pickMultipleMedia(requestFullMetadata: false);
    return _persistAll(files);
  }

  /// Recovers picker results after Android destroys and recreates the Activity.
  ///
  /// Call during application startup or project-page initialization. Throws the
  /// picker exception when recovery failed so UI can show an actionable error.
  Future<List<ImportedMedia>> recoverLostData() async {
    final response = await _picker.retrieveLostData();
    if (response.isEmpty) return const [];
    if (response.exception != null) throw response.exception!;
    return _persistAll(response.files ?? const []);
  }

  /// Moves a camera result out of temporary cache and classifies it explicitly.
  ///
  /// This performs file I/O only; it does not decode media or update SQLite.
  Future<ImportedMedia> persistCaptured(
    XFile file,
    ProjectKind kind,
  ) =>
      _persist(file, forcedKind: kind);

  Future<List<ImportedMedia>> _persistAll(List<XFile> files) async {
    final imported = <ImportedMedia>[];
    for (final file in files) {
      imported.add(await _persist(file));
    }
    return imported;
  }

  /// Copies one picker file using streams and removes no source data.
  Future<ImportedMedia> _persist(
    XFile file, {
    ProjectKind? forcedKind,
  }) async {
    final kind = forcedKind ?? _classify(file);
    final directory = await _mediaDirectory();
    final extension = path.extension(file.name).toLowerCase();
    final destination = File(path.join(
      directory.path,
      '${_uuid.v4()}${extension.isEmpty ? _fallbackExtension(kind) : extension}',
    ));
    final sink = destination.openWrite();
    try {
      await sink.addStream(file.openRead());
    } catch (_) {
      await sink.close();
      if (await destination.exists()) await destination.delete();
      rethrow;
    }
    await sink.close();
    return ImportedMedia(
      path: destination.path,
      kind: kind,
      originalName: file.name,
    );
  }

  /// Creates the durable media directory once and returns its handle.
  Future<Directory> _mediaDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    final media = Directory(path.join(documents.path, 'media'));
    if (!await media.exists()) await media.create(recursive: true);
    return media;
  }

  ProjectKind _classify(XFile file) {
    final mimeType = file.mimeType?.toLowerCase();
    if (mimeType?.startsWith('video/') ?? false) return ProjectKind.video;
    final extension = path.extension(file.name).toLowerCase();
    const videoExtensions = {
      '.mp4', '.mov', '.m4v', '.avi', '.mkv', '.webm', '.3gp',
    };
    return videoExtensions.contains(extension)
        ? ProjectKind.video
        : ProjectKind.image;
  }

  String _fallbackExtension(ProjectKind kind) =>
      kind == ProjectKind.image ? '.jpg' : '.mp4';
}
