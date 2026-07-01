import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

/// Owns the on-device SQLite database and its forward-only migrations.
///
/// The database mirrors production entities but stores timestamps as epoch
/// milliseconds and booleans as integers. Opening it performs disk I/O on the
/// sqflite worker thread. Callers share the lazily opened instance and must call
/// [close] only when the application process is shutting down or in tests.
class LocalDatabase {
  LocalDatabase({DatabaseFactory? databaseFactory})
      : _databaseFactory = databaseFactory ?? databaseFactorySqflite;

  static const databaseName = 'vicys.db';
  static const schemaVersion = 1;

  final DatabaseFactory _databaseFactory;
  Database? _database;

  /// Returns the single open database, creating and migrating it when needed.
  ///
  /// Concurrent calls reuse the same instance after sqflite finishes opening.
  /// Throws [DatabaseException] when the file cannot be opened or migrated.
  Future<Database> get instance async {
    final current = _database;
    if (current != null && current.isOpen) return current;

    final databasePath = path.join(
      await _databaseFactory.getDatabasesPath(),
      databaseName,
    );
    _database = await _databaseFactory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: _configure,
        onCreate: _createVersion1,
        onUpgrade: _upgrade,
      ),
    );
    return _database!;
  }

  /// Enables foreign-key enforcement for every SQLite connection.
  ///
  /// This mutates connection configuration before migrations or queries run.
  Future<void> _configure(Database database) =>
      database.execute('PRAGMA foreign_keys = ON');

  /// Creates schema version 1 in a single transaction managed by sqflite.
  ///
  /// It creates local equivalents of production tables plus [sync_queue].
  /// A failure aborts database creation and leaves no partially migrated schema.
  Future<void> _createVersion1(Database database, int version) async {
    final statements = _version1Statements;
    for (final statement in statements) {
      await database.execute(statement);
    }
  }

  /// Applies forward-only migrations between installed and requested versions.
  ///
  /// Add one guarded block per schema version. Downgrades are intentionally
  /// unsupported to avoid silently destroying newer local drafts.
  Future<void> _upgrade(
    Database database,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion > newVersion) {
      throw StateError('Downgrading the Vicys database is not supported.');
    }
  }

  /// Closes the underlying file handle and allows a later call to reopen it.
  Future<void> close() async {
    final current = _database;
    _database = null;
    await current?.close();
  }

  static const List<String> _version1Statements = [
    '''
    CREATE TABLE profiles (
      id TEXT PRIMARY KEY,
      username TEXT NOT NULL UNIQUE,
      display_name TEXT NOT NULL DEFAULT '',
      bio TEXT NOT NULL DEFAULT '',
      avatar_path TEXT,
      storage_used INTEGER NOT NULL DEFAULT 0 CHECK(storage_used >= 0),
      created_at INTEGER NOT NULL,
      sync_state TEXT NOT NULL DEFAULT 'localOnly'
    )
    ''',
    '''
    CREATE TABLE projects (
      id TEXT PRIMARY KEY,
      owner_id TEXT,
      title TEXT NOT NULL,
      kind TEXT NOT NULL CHECK(kind IN ('image', 'video')),
      schema_version INTEGER NOT NULL,
      current_revision INTEGER NOT NULL,
      manifest TEXT NOT NULL,
      sync_state TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      deleted_at INTEGER,
      FOREIGN KEY(owner_id) REFERENCES profiles(id) ON DELETE CASCADE
    )
    ''',
    '''
    CREATE TABLE project_versions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      project_id TEXT NOT NULL,
      revision INTEGER NOT NULL,
      device_id TEXT NOT NULL DEFAULT 'local',
      manifest TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      UNIQUE(project_id, revision, device_id),
      FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE
    )
    ''',
    '''
    CREATE TABLE media_assets (
      id TEXT PRIMARY KEY,
      owner_id TEXT,
      project_id TEXT,
      local_path TEXT,
      remote_path TEXT,
      checksum TEXT NOT NULL,
      byte_size INTEGER NOT NULL CHECK(byte_size >= 0),
      mime_type TEXT NOT NULL,
      distributable INTEGER NOT NULL DEFAULT 1,
      sync_state TEXT NOT NULL DEFAULT 'localOnly',
      created_at INTEGER NOT NULL,
      UNIQUE(owner_id, checksum),
      FOREIGN KEY(owner_id) REFERENCES profiles(id) ON DELETE CASCADE,
      FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE
    )
    ''',
    '''
    CREATE TABLE share_links (
      id TEXT PRIMARY KEY,
      project_id TEXT NOT NULL,
      owner_id TEXT,
      token_hash TEXT NOT NULL UNIQUE,
      expires_at INTEGER NOT NULL,
      revoked_at INTEGER,
      created_at INTEGER NOT NULL,
      FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE,
      FOREIGN KEY(owner_id) REFERENCES profiles(id) ON DELETE CASCADE
    )
    ''',
    '''
    CREATE TABLE posts (
      id TEXT PRIMARY KEY,
      author_id TEXT NOT NULL,
      media_asset_id TEXT NOT NULL,
      thumbnail_asset_id TEXT,
      caption TEXT NOT NULL DEFAULT '',
      visibility TEXT NOT NULL DEFAULT 'public'
        CHECK(visibility IN ('private', 'public')),
      duration_ms INTEGER CHECK(duration_ms IS NULL OR duration_ms BETWEEN 0 AND 60000),
      created_at INTEGER NOT NULL,
      deleted_at INTEGER,
      sync_state TEXT NOT NULL DEFAULT 'localOnly',
      FOREIGN KEY(author_id) REFERENCES profiles(id) ON DELETE CASCADE,
      FOREIGN KEY(media_asset_id) REFERENCES media_assets(id),
      FOREIGN KEY(thumbnail_asset_id) REFERENCES media_assets(id)
    )
    ''',
    '''
    CREATE TABLE follows (
      follower_id TEXT NOT NULL,
      following_id TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      PRIMARY KEY(follower_id, following_id),
      CHECK(follower_id <> following_id),
      FOREIGN KEY(follower_id) REFERENCES profiles(id) ON DELETE CASCADE,
      FOREIGN KEY(following_id) REFERENCES profiles(id) ON DELETE CASCADE
    )
    ''',
    '''
    CREATE TABLE comments (
      id TEXT PRIMARY KEY,
      post_id TEXT NOT NULL,
      author_id TEXT NOT NULL,
      body TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      deleted_at INTEGER,
      sync_state TEXT NOT NULL DEFAULT 'localOnly',
      FOREIGN KEY(post_id) REFERENCES posts(id) ON DELETE CASCADE,
      FOREIGN KEY(author_id) REFERENCES profiles(id) ON DELETE CASCADE
    )
    ''',
    '''
    CREATE TABLE reactions (
      post_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      PRIMARY KEY(post_id, user_id),
      FOREIGN KEY(post_id) REFERENCES posts(id) ON DELETE CASCADE,
      FOREIGN KEY(user_id) REFERENCES profiles(id) ON DELETE CASCADE
    )
    ''',
    '''
    CREATE TABLE saved_posts (
      post_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      PRIMARY KEY(post_id, user_id),
      FOREIGN KEY(post_id) REFERENCES posts(id) ON DELETE CASCADE,
      FOREIGN KEY(user_id) REFERENCES profiles(id) ON DELETE CASCADE
    )
    ''',
    '''
    CREATE TABLE blocks (
      blocker_id TEXT NOT NULL,
      blocked_id TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      PRIMARY KEY(blocker_id, blocked_id),
      CHECK(blocker_id <> blocked_id),
      FOREIGN KEY(blocker_id) REFERENCES profiles(id) ON DELETE CASCADE,
      FOREIGN KEY(blocked_id) REFERENCES profiles(id) ON DELETE CASCADE
    )
    ''',
    '''
    CREATE TABLE notifications (
      id TEXT PRIMARY KEY,
      recipient_id TEXT NOT NULL,
      actor_id TEXT,
      type TEXT NOT NULL,
      entity_id TEXT,
      read_at INTEGER,
      created_at INTEGER NOT NULL,
      FOREIGN KEY(recipient_id) REFERENCES profiles(id) ON DELETE CASCADE,
      FOREIGN KEY(actor_id) REFERENCES profiles(id) ON DELETE SET NULL
    )
    ''',
    '''
    CREATE TABLE reports (
      id TEXT PRIMARY KEY,
      reporter_id TEXT NOT NULL,
      target_type TEXT NOT NULL CHECK(target_type IN ('post', 'comment', 'user')),
      target_id TEXT NOT NULL,
      reason TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'open'
        CHECK(status IN ('open', 'reviewing', 'closed')),
      created_at INTEGER NOT NULL,
      FOREIGN KEY(reporter_id) REFERENCES profiles(id) ON DELETE CASCADE
    )
    ''',
    '''
    CREATE TABLE sync_queue (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      entity_type TEXT NOT NULL,
      entity_id TEXT NOT NULL,
      operation TEXT NOT NULL CHECK(operation IN ('upsert', 'delete')),
      revision INTEGER,
      attempts INTEGER NOT NULL DEFAULT 0,
      next_attempt_at INTEGER NOT NULL,
      last_error TEXT,
      created_at INTEGER NOT NULL,
      UNIQUE(entity_type, entity_id, operation)
    )
    ''',
    'CREATE INDEX projects_owner_updated_idx ON projects(owner_id, updated_at DESC)',
    'CREATE INDEX project_versions_project_idx ON project_versions(project_id, revision DESC)',
    'CREATE INDEX media_assets_project_idx ON media_assets(project_id)',
    'CREATE INDEX posts_feed_idx ON posts(created_at DESC) WHERE deleted_at IS NULL',
    'CREATE INDEX comments_post_idx ON comments(post_id, created_at)',
    'CREATE INDEX notifications_recipient_idx ON notifications(recipient_id, created_at DESC)',
    'CREATE INDEX sync_queue_due_idx ON sync_queue(next_attempt_at, attempts)',
  ];
}
