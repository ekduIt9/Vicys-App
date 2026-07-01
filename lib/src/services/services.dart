import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../core/models.dart';
import '../data/project_repository.dart';

class EditHistory {
  EditHistory(this.project);
  MediaProject project;
  final List<MediaProject> _undo = [];
  final List<MediaProject> _redo = [];

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  void apply(EditOperation operation) {
    _undo.add(project);
    _redo.clear();
    project = project.copyWith(
      updatedAt: DateTime.now(),
      revision: project.revision + 1,
      operations: [...project.operations, operation],
      syncState: SyncState.queued,
    );
  }

  void undo() {
    if (!canUndo) return;
    _redo.add(project);
    project = _undo.removeLast();
  }

  void redo() {
    if (!canRedo) return;
    _undo.add(project);
    project = _redo.removeLast();
  }
}

class AutosaveController {
  AutosaveController(this.repository);
  final ProjectRepository repository;
  Timer? _timer;

  void schedule(MediaProject project) {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 500), () => repository.save(project));
  }

  void dispose() => _timer?.cancel();
}

class SyncService {
  SyncService(this.repository);
  final ProjectRepository repository;

  Future<String> checksum(File file) async =>
      sha256.convert(await file.readAsBytes()).toString();

  MediaProject resolveConflict(MediaProject local, MediaProject remote) {
    if (local.revision == remote.revision && local.encode() != remote.encode()) {
      return local.copyWith(syncState: SyncState.conflict);
    }
    return local.revision > remote.revision ? local : remote;
  }

  Future<void> enqueue(MediaProject project) =>
      repository.save(project.copyWith(syncState: SyncState.queued));
}

abstract interface class RenderService {
  Stream<double> export(MediaProject project);
}

class DemoRenderService implements RenderService {
  @override
  Stream<double> export(MediaProject project) async* {
    for (var step = 0; step <= 10; step++) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      yield step / 10;
    }
  }
}

String projectManifest(MediaProject project) =>
    const JsonEncoder.withIndent('  ').convert(project.toJson());
