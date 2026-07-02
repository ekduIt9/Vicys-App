import 'package:flutter_test/flutter_test.dart';
import 'package:studio_social/src/core/models.dart';
import 'package:studio_social/src/services/services.dart';

void main() {
  test('project survives JSON round trip', () {
    final now = DateTime.utc(2026, 7, 1);
    final project = MediaProject(
      id: 'project-1',
      title: 'Demo',
      kind: ProjectKind.video,
      createdAt: now,
      updatedAt: now,
      sourcePaths: const ['media/source.mp4'],
      operations: const [EditOperation(type: 'trim', parameters: {'end': 12})],
    );

    final decoded = MediaProject.decode(project.encode());
    expect(decoded.id, project.id);
    expect(decoded.operations.single.type, 'trim');
    expect(decoded.sourcePaths, ['media/source.mp4']);
    expect(decoded.schemaVersion, MediaProject.currentSchemaVersion);
  });

  test('version 1 project opens without source media', () {
    final decoded = MediaProject.fromJson({
      'id': 'legacy-project',
      'title': 'Legacy',
      'kind': 'image',
      'createdAt': '2026-01-01T00:00:00.000Z',
      'updatedAt': '2026-01-01T00:00:00.000Z',
      'schemaVersion': 1,
      'revision': 1,
      'operations': <Object?>[],
      'syncState': 'localOnly',
    });

    expect(decoded.sourcePaths, isEmpty);
  });

  test('history supports undo and redo', () {
    final now = DateTime.utc(2026, 7, 1);
    final history = EditHistory(MediaProject(
      id: 'project-1',
      title: 'Demo',
      kind: ProjectKind.image,
      createdAt: now,
      updatedAt: now,
    ));

    history.apply(const EditOperation(type: 'crop'));
    expect(history.project.operations, hasLength(1));
    final appliedRevision = history.project.revision;
    history.undo();
    expect(history.project.operations, isEmpty);
    expect(history.project.revision, appliedRevision + 1);
    history.redo();
    expect(history.project.operations, hasLength(1));
    expect(history.project.revision, appliedRevision + 2);
  });

  test('equal revision with divergent data becomes conflict', () {
    final now = DateTime.utc(2026, 7, 1);
    final base = MediaProject(
      id: 'project-1',
      title: 'Local',
      kind: ProjectKind.image,
      createdAt: now,
      updatedAt: now,
    );
    final result = SyncService(_MemoryRepository())
        .resolveConflict(base, base.copyWith(title: 'Remote'));
    expect(result.syncState, SyncState.conflict);
  });
}

class _MemoryRepository implements ProjectRepository {
  @override
  Future<MediaProject> create(
    ProjectKind kind, {
    List<String> sourcePaths = const <String>[],
    String? title,
  }) =>
      throw UnimplementedError();
  @override
  Future<void> delete(String id) async {}
  @override
  Future<List<MediaProject>> list() async => [];
  @override
  Future<void> save(MediaProject project) async {}
}
