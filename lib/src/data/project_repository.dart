import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../core/models.dart';
import 'local_database.dart';

abstract interface class ProjectRepository {
  /// Lists non-deleted projects with the most recently edited project first.
  Future<List<MediaProject>> list();

  /// Creates and persists an image or video project with optional source media.
  Future<MediaProject> create(
    ProjectKind kind, {
    List<String> sourcePaths = const <String>[],
    String? title,
  });

  /// Atomically saves a project snapshot and enqueues it for cloud sync.
  Future<void> save(MediaProject project);

  /// Soft-deletes a project locally and enqueues its remote deletion.
  Future<void> delete(String id);
}

class LocalProjectRepository implements ProjectRepository {
  LocalProjectRepository({
    LocalDatabase? database,
    Uuid? uuid,
  })  : _database = database ?? LocalDatabase(),
        _uuid = uuid ?? const Uuid();

  final LocalDatabase _database;
  final Uuid _uuid;

  /// Reads project manifests from SQLite without loading associated media.
  ///
  /// SQLite performs disk work on its worker thread. Corrupt or future-version
  /// manifests surface as [FormatException] instead of being silently skipped.
  @override
  Future<List<MediaProject>> list() async {
    final database = await _database.instance;
    final rows = await database.query(
      'projects',
      columns: ['manifest'],
      where: 'deleted_at IS NULL',
      orderBy: 'updated_at DESC',
    );
    return rows
        .map((row) => MediaProject.decode(row['manifest']! as String))
        .toList(growable: false);
  }

  /// Creates a local-first draft and queues its first cloud revision.
  ///
  /// Writes to SQLite through [save]. A database failure is returned to the UI
  /// so it can explain that no draft was created.
  @override
  Future<MediaProject> create(
    ProjectKind kind, {
    List<String> sourcePaths = const <String>[],
    String? title,
  }) async {
    final now = DateTime.now();
    final project = MediaProject(
      id: _uuid.v4(),
      title: title ??
          (kind == ProjectKind.image
              ? 'Ảnh chưa đặt tên'
              : 'Video chưa đặt tên'),
      kind: kind,
      createdAt: now,
      updatedAt: now,
      sourcePaths: List.unmodifiable(sourcePaths),
    );
    await save(project);
    return project;
  }

  /// Persists the current manifest, immutable revision and sync queue entry.
  ///
  /// All three writes use one SQLite transaction, so a crash cannot leave a
  /// project without its matching revision. Repeated saves of the same revision
  /// are idempotent. This does not perform network I/O.
  @override
  Future<void> save(MediaProject project) async {
    final database = await _database.instance;
    final queuedProject = project.copyWith(syncState: SyncState.queued);
    final now = DateTime.now().millisecondsSinceEpoch;

    await database.transaction((transaction) async {
      await _upsertProject(transaction, queuedProject);
      await transaction.insert(
        'project_versions',
        {
          'project_id': queuedProject.id,
          'revision': queuedProject.revision,
          'device_id': 'local',
          'manifest': queuedProject.encode(),
          'created_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      await _enqueue(
        transaction,
        entityId: queuedProject.id,
        revision: queuedProject.revision,
        operation: 'upsert',
        now: now,
      );
    });
  }

  /// Marks a project deleted while retaining its data until cloud confirmation.
  ///
  /// The tombstone and delete queue entry are committed atomically. Unknown IDs
  /// are ignored, making retries safe.
  @override
  Future<void> delete(String id) async {
    final database = await _database.instance;
    final now = DateTime.now().millisecondsSinceEpoch;
    await database.transaction((transaction) async {
      final changed = await transaction.update(
        'projects',
        {'deleted_at': now, 'sync_state': SyncState.queued.name},
        where: 'id = ? AND deleted_at IS NULL',
        whereArgs: [id],
      );
      if (changed == 0) return;
      await transaction.delete(
        'sync_queue',
        where: "entity_type = 'project' AND entity_id = ? AND operation = 'upsert'",
        whereArgs: [id],
      );
      await _enqueue(
        transaction,
        entityId: id,
        operation: 'delete',
        now: now,
      );
    });
  }

  /// Inserts or updates a project without SQLite's destructive REPLACE behavior.
  ///
  /// A regular `INSERT OR REPLACE` deletes the existing row and would cascade
  /// into versions and assets. This UPSERT preserves child records and clears a
  /// prior local tombstone when an explicit save restores the project.
  Future<void> _upsertProject(
    Transaction transaction,
    MediaProject project,
  ) async {
    await transaction.rawInsert(
      '''
        INSERT INTO projects (
          id, owner_id, title, kind, schema_version, current_revision,
          manifest, sync_state, created_at, updated_at, deleted_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)
        ON CONFLICT(id) DO UPDATE SET
          title = excluded.title,
          kind = excluded.kind,
          schema_version = excluded.schema_version,
          current_revision = excluded.current_revision,
          manifest = excluded.manifest,
          sync_state = excluded.sync_state,
          updated_at = excluded.updated_at,
          deleted_at = NULL
      ''',
      [
        project.id,
        null,
        project.title,
        project.kind.name,
        project.schemaVersion,
        project.revision,
        jsonEncode(project.toJson()),
        project.syncState.name,
        project.createdAt.millisecondsSinceEpoch,
        project.updatedAt.millisecondsSinceEpoch,
      ],
    );
  }

  /// Upserts one idempotent project operation into the durable sync queue.
  ///
  /// A newer save replaces the queued revision and resets its retry state.
  Future<void> _enqueue(
    Transaction transaction, {
    required String entityId,
    required String operation,
    required int now,
    int? revision,
  }) async {
    await transaction.insert(
      'sync_queue',
      {
        'entity_type': 'project',
        'entity_id': entityId,
        'operation': operation,
        'revision': revision,
        'attempts': 0,
        'next_attempt_at': now,
        'last_error': null,
        'created_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
