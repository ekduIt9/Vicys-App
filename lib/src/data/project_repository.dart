import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../core/models.dart';

abstract interface class ProjectRepository {
  Future<List<MediaProject>> list();
  Future<MediaProject> create(ProjectKind kind);
  Future<void> save(MediaProject project);
  Future<void> delete(String id);
}

class LocalProjectRepository implements ProjectRepository {
  static const _indexKey = 'project_index_v1';
  static const _prefix = 'project_v1_';
  final Uuid _uuid = const Uuid();

  @override
  Future<List<MediaProject>> list() async {
    final preferences = await SharedPreferences.getInstance();
    final ids = preferences.getStringList(_indexKey) ?? const <String>[];
    final projects = <MediaProject>[];
    for (final id in ids) {
      final encoded = preferences.getString('$_prefix$id');
      if (encoded != null) {
        projects.add(MediaProject.decode(encoded));
      }
    }
    projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return projects;
  }

  @override
  Future<MediaProject> create(ProjectKind kind) async {
    final now = DateTime.now();
    final project = MediaProject(
      id: _uuid.v4(),
      title: kind == ProjectKind.image ? 'Ảnh chưa đặt tên' : 'Video chưa đặt tên',
      kind: kind,
      createdAt: now,
      updatedAt: now,
    );
    await save(project);
    return project;
  }

  @override
  Future<void> save(MediaProject project) async {
    final preferences = await SharedPreferences.getInstance();
    final ids = preferences.getStringList(_indexKey) ?? <String>[];
    if (!ids.contains(project.id)) {
      ids.add(project.id);
      await preferences.setStringList(_indexKey, ids);
    }
    await preferences.setString('$_prefix${project.id}', project.encode());
  }

  @override
  Future<void> delete(String id) async {
    final preferences = await SharedPreferences.getInstance();
    final ids = preferences.getStringList(_indexKey) ?? <String>[];
    ids.remove(id);
    await preferences.setStringList(_indexKey, ids);
    await preferences.remove('$_prefix$id');
  }
}
