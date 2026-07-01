import 'dart:convert';

enum ProjectKind { image, video }

enum SyncState { localOnly, queued, syncing, synced, conflict, failed }

class EditOperation {
  const EditOperation({
    required this.type,
    this.parameters = const <String, Object?>{},
  });

  final String type;
  final Map<String, Object?> parameters;

  Map<String, Object?> toJson() => {'type': type, 'parameters': parameters};

  factory EditOperation.fromJson(Map<String, Object?> json) => EditOperation(
        type: json['type']! as String,
        parameters:
            Map<String, Object?>.from(json['parameters']! as Map<dynamic, dynamic>),
      );
}

class MediaProject {
  const MediaProject({
    required this.id,
    required this.title,
    required this.kind,
    required this.createdAt,
    required this.updatedAt,
    this.schemaVersion = currentSchemaVersion,
    this.revision = 1,
    this.operations = const <EditOperation>[],
    this.sourcePaths = const <String>[],
    this.syncState = SyncState.localOnly,
  });

  static const currentSchemaVersion = 2;
  final String id;
  final String title;
  final ProjectKind kind;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int schemaVersion;
  final int revision;
  final List<EditOperation> operations;
  final List<String> sourcePaths;
  final SyncState syncState;

  MediaProject copyWith({
    String? title,
    DateTime? updatedAt,
    int? revision,
    List<EditOperation>? operations,
    List<String>? sourcePaths,
    SyncState? syncState,
  }) =>
      MediaProject(
        id: id,
        title: title ?? this.title,
        kind: kind,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        schemaVersion: schemaVersion,
        revision: revision ?? this.revision,
        operations: operations ?? this.operations,
        sourcePaths: sourcePaths ?? this.sourcePaths,
        syncState: syncState ?? this.syncState,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'kind': kind.name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'schemaVersion': schemaVersion,
        'revision': revision,
        'operations': operations.map((operation) => operation.toJson()).toList(),
        'sourcePaths': sourcePaths,
        'syncState': syncState.name,
      };

  String encode() => jsonEncode(toJson());

  factory MediaProject.fromJson(Map<String, Object?> json) {
    final schemaVersion = json['schemaVersion'] as int? ?? 1;
    if (schemaVersion > currentSchemaVersion) {
      throw const FormatException('Project was created by a newer app version.');
    }
    return MediaProject(
      id: json['id']! as String,
      title: json['title']! as String,
      kind: ProjectKind.values.byName(json['kind']! as String),
      createdAt: DateTime.parse(json['createdAt']! as String),
      updatedAt: DateTime.parse(json['updatedAt']! as String),
      schemaVersion: schemaVersion,
      revision: json['revision'] as int? ?? 1,
      operations: (json['operations'] as List<dynamic>? ?? const [])
          .map((value) =>
              EditOperation.fromJson(Map<String, Object?>.from(value as Map)))
          .toList(),
      sourcePaths: (json['sourcePaths'] as List<dynamic>? ?? const [])
          .cast<String>(),
      syncState: SyncState.values
          .byName(json['syncState'] as String? ?? SyncState.localOnly.name),
    );
  }

  factory MediaProject.decode(String value) =>
      MediaProject.fromJson(Map<String, Object?>.from(jsonDecode(value) as Map));
}

class SocialPost {
  const SocialPost({
    required this.id,
    required this.author,
    required this.caption,
    required this.kind,
    required this.createdAt,
    this.likes = 0,
    this.comments = 0,
  });

  final String id;
  final String author;
  final String caption;
  final ProjectKind kind;
  final DateTime createdAt;
  final int likes;
  final int comments;
}
