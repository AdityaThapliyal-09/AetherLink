// AetherLink SQLite database schema and migration.
// Uses sqflite for local-only storage. No cloud, no remote backend.

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path_pkg;
import '../../core/constants/app_constants.dart';
import '../../core/logging/logger.dart';

class AetherDatabase {
  static final AetherDatabase _instance = AetherDatabase._internal();
  factory AetherDatabase() => _instance;
  AetherDatabase._internal();

  Database? _db;

  Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final fullPath = path_pkg.join(dbPath, AppConstants.dbName);
    logger.database('Opening database at $fullPath');

    return openDatabase(
      fullPath,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        await db.rawQuery('PRAGMA journal_mode = WAL');
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    logger.database('Creating database schema v$version');
    await db.transaction((txn) async {
      // ---- Identity ----
      await txn.execute('''
        CREATE TABLE identity (
          id              INTEGER PRIMARY KEY,
          node_id         TEXT NOT NULL UNIQUE,
          display_name    TEXT NOT NULL,
          ed_public_key   TEXT NOT NULL,
          ed_private_key_ref TEXT NOT NULL,
          dh_public_key   TEXT NOT NULL,
          dh_private_key_ref TEXT NOT NULL,
          created_at      INTEGER NOT NULL
        )
      ''');

      // ---- Peers / Contacts ----
      await txn.execute('''
        CREATE TABLE peers (
          node_id         TEXT PRIMARY KEY,
          display_name    TEXT NOT NULL,
          ed_public_key   TEXT,
          dh_public_key   TEXT,
          last_seen       INTEGER,
          connection_state TEXT NOT NULL DEFAULT 'disconnected',
          rssi            INTEGER,
          hop_count       INTEGER NOT NULL DEFAULT 0,
          is_trusted      INTEGER NOT NULL DEFAULT 0,
          next_hop_id     TEXT,
          created_at      INTEGER NOT NULL
        )
      ''');

      // ---- Conversations ----
      await txn.execute('''
        CREATE TABLE conversations (
          conversation_id   TEXT PRIMARY KEY,
          peer_id           TEXT NOT NULL,
          peer_name         TEXT NOT NULL,
          created_at        INTEGER NOT NULL,
          last_message_text TEXT,
          last_message_time INTEGER,
          unread_count      INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY(peer_id) REFERENCES peers(node_id)
        )
      ''');

      // ---- Messages ----
      await txn.execute('''
        CREATE TABLE messages (
          message_id          TEXT PRIMARY KEY,
          conversation_id     TEXT NOT NULL,
          sender_id           TEXT NOT NULL,
          receiver_id         TEXT NOT NULL,
          encrypted_payload   TEXT NOT NULL,
          plaintext           TEXT,
          timestamp           INTEGER NOT NULL,
          status              TEXT NOT NULL DEFAULT 'pending',
          hop_count           INTEGER NOT NULL DEFAULT 0,
          message_type        TEXT NOT NULL DEFAULT 'text',
          retry_count         INTEGER NOT NULL DEFAULT 0,
          is_outgoing         INTEGER NOT NULL DEFAULT 0,
          route_description   TEXT,
          FOREIGN KEY(conversation_id) REFERENCES conversations(conversation_id)
        )
      ''');
      await txn.execute(
          'CREATE INDEX idx_messages_conversation ON messages(conversation_id, timestamp)');

      // ---- Routing Table ----
      await txn.execute('''
        CREATE TABLE routing_table (
          destination_id  TEXT PRIMARY KEY,
          next_hop_id     TEXT NOT NULL,
          hop_count       INTEGER NOT NULL,
          sequence_number INTEGER NOT NULL DEFAULT 0,
          state           TEXT NOT NULL DEFAULT 'active',
          last_updated    INTEGER NOT NULL,
          expires_at      INTEGER NOT NULL,
          precursors      TEXT NOT NULL DEFAULT '[]'
        )
      ''');

      // ---- Broadcast / SOS messages ----
      await txn.execute('''
        CREATE TABLE broadcast_messages (
          message_id      TEXT PRIMARY KEY,
          origin_id       TEXT NOT NULL,
          origin_name     TEXT NOT NULL,
          alert_type      TEXT NOT NULL DEFAULT 'broadcast',
          content         TEXT NOT NULL,
          timestamp       INTEGER NOT NULL,
          ttl             INTEGER NOT NULL,
          hop_count       INTEGER NOT NULL DEFAULT 0
        )
      ''');

      // ---- Seen message cache (dedup / loop prevention) ----
      // Stores message IDs that this node has already processed.
      await txn.execute('''
        CREATE TABLE seen_messages (
          message_id  TEXT PRIMARY KEY,
          seen_at     INTEGER NOT NULL
        )
      ''');

      // ---- Application logs (for diagnostics screen) ----
      await txn.execute('''
        CREATE TABLE app_logs (
          id          INTEGER PRIMARY KEY AUTOINCREMENT,
          timestamp   INTEGER NOT NULL,
          category    TEXT NOT NULL,
          level       TEXT NOT NULL,
          message     TEXT NOT NULL,
          details     TEXT
        )
      ''');
    });

    logger.database('Database schema created successfully');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    logger.database('Upgrading database from v$oldVersion to v$newVersion');
    // Future migration logic goes here.
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  /// Wipes all data — only callable from settings with user confirmation.
  Future<void> clearAllData() async {
    final database = await db;
    await database.transaction((txn) async {
      for (final table in [
        'messages', 'conversations', 'peers', 'routing_table',
        'broadcast_messages', 'seen_messages', 'app_logs', 'identity',
      ]) {
        await txn.execute('DELETE FROM $table');
      }
    });
    logger.database('All data cleared by user request');
  }
}
