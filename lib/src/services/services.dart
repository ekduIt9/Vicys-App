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

  /// Adds one non-destructive operation and creates a new local revision.
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

  /// Restores the previous operation state as a new monotonic revision.
  ///
  /// The original media remains untouched and redo retains the current state.
  void undo() {
    if (!canUndo) return;
    final current = project;
    final previous = _undo.removeLast();
    _redo.add(current);
    project = current.copyWith(
      operations: previous.operations,
      updatedAt: DateTime.now(),
      revision: current.revision + 1,
      syncState: SyncState.queued,
    );
  }

  /// Reapplies the next operation state while keeping revisions monotonic.
  ///
  /// Redo creates a new local revision instead of restoring an older revision,
  /// preventing cloud synchronization from mistaking the edit for stale data.
  void redo() {
    if (!canRedo) return;
    final current = project;
    final next = _redo.removeLast();
    _undo.add(current);
    project = current.copyWith(
      operations: next.operations,
      updatedAt: DateTime.now(),
      revision: current.revision + 1,
      syncState: SyncState.queued,
    );
  }
}

class AutosaveController {
  AutosaveController(this.repository);
  final ProjectRepository repository;
  Timer? _timer;

  /// Debounces project persistence so rapid UI changes produce one disk write.
  void schedule(MediaProject project) {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 500), () => repository.save(project));
  }

  /// Cancels pending persistence when the editor is disposed.
  void dispose() => _timer?.cancel();
}

class SyncService {
  SyncService(this.repository);
  final ProjectRepository repository;

  /// Streams a file through SHA-256 without retaining large media in memory.
  ///
  /// This reads the source file and performs no mutation. File-system errors
  /// propagate to the sync queue for retry or user-facing recovery.
  Future<String> checksum(File file) async =>
      (await sha256.bind(file.openRead()).first).toString();

  /// Selects the newest revision or marks equal divergent revisions as conflict.
  MediaProject resolveConflict(MediaProject local, MediaProject remote) {
    if (local.revision == remote.revision && local.encode() != remote.encode()) {
      return local.copyWith(syncState: SyncState.conflict);
    }
    return local.revision > remote.revision ? local : remote;
  }

  /// Persists a project as queued without performing immediate network I/O.
  Future<void> enqueue(MediaProject project) =>
      repository.save(project.copyWith(syncState: SyncState.queued));
}

abstract interface class RenderService {
  /// Exports a project and emits normalized progress from zero to one.
  Stream<double> export(MediaProject project);
}

class DemoRenderService implements RenderService {
  /// Emits deterministic fake progress without reading or writing media.
  @override
  Stream<double> export(MediaProject project) async* {
    for (var step = 0; step <= 10; step++) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      yield step / 10;
    }
  }
}

/// Produces a human-readable project manifest for diagnostics and sharing.
String projectManifest(MediaProject project) =>
    const JsonEncoder.withIndent('  ').convert(project.toJson());
