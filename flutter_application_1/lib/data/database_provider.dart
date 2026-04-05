import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Single source of truth for the SQLite database.
/// Call [DatabaseProvider.instance.database] anywhere to get the [Database].
class DatabaseProvider {
  DatabaseProvider._();
  static final DatabaseProvider instance = DatabaseProvider._();

  static Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  static const _dbName    = 'e3lty.db';
  static const _dbVersion = 1;

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path   = join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      // Enable foreign-key enforcement
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
    );
  }

  // ── Schema ─────────────────────────────────────────────────────────────────

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    // Family members
    batch.execute('''
      CREATE TABLE members (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        name        TEXT    NOT NULL,
        age         INTEGER NOT NULL,
        profile_type TEXT   NOT NULL,
        created_at  TEXT    NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // Medications (linked to a member)
    batch.execute('''
      CREATE TABLE medications (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        member_id   INTEGER NOT NULL REFERENCES members(id) ON DELETE CASCADE,
        name        TEXT    NOT NULL,
        dose        TEXT    NOT NULL,
        frequency   TEXT    NOT NULL,
        time_of_day TEXT    NOT NULL,
        is_active   INTEGER NOT NULL DEFAULT 1,
        created_at  TEXT    NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // Daily medication confirmations
    batch.execute('''
      CREATE TABLE med_confirmations (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        medication_id INTEGER NOT NULL REFERENCES medications(id) ON DELETE CASCADE,
        confirmed_at  TEXT    NOT NULL DEFAULT (datetime('now')),
        date          TEXT    NOT NULL
      )
    ''');

    // Vital signs
    batch.execute('''
      CREATE TABLE vital_signs (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        member_id   INTEGER NOT NULL REFERENCES members(id) ON DELETE CASCADE,
        type        TEXT    NOT NULL,
        value       REAL    NOT NULL,
        unit        TEXT    NOT NULL,
        recorded_at TEXT    NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // Appointments
    batch.execute('''
      CREATE TABLE appointments (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        member_id    INTEGER NOT NULL REFERENCES members(id) ON DELETE CASCADE,
        title        TEXT    NOT NULL,
        doctor       TEXT,
        location     TEXT,
        scheduled_at TEXT    NOT NULL,
        notes        TEXT,
        created_at   TEXT    NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // Medical documents (images / PDFs stored on device; only path saved here)
    batch.execute('''
      CREATE TABLE documents (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        member_id    INTEGER NOT NULL REFERENCES members(id) ON DELETE CASCADE,
        title        TEXT    NOT NULL,
        file_path    TEXT    NOT NULL,
        doc_type     TEXT    NOT NULL,
        created_at   TEXT    NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // Vaccination records (child module)
    batch.execute('''
      CREATE TABLE vaccinations (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        member_id    INTEGER NOT NULL REFERENCES members(id) ON DELETE CASCADE,
        vaccine_name TEXT    NOT NULL,
        clinic_name  TEXT,
        received_at  TEXT,
        is_received  INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await batch.commit(noResult: true);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Reserved for future migrations — add ALTER TABLE statements here
  }
}