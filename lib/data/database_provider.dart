import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Single source of truth for the local SQLite cache.
///
/// Firebase/Firestore remains the source of truth for family and medical data.
/// SQLite is kept as an offline/cache layer so the UI can keep reading data
/// locally and local reminders can still work after sync.
class DatabaseProvider {
  DatabaseProvider._();
  static final DatabaseProvider instance = DatabaseProvider._();

  static Database? _db;

  static const _dbName = 'e3lty.db';
  static const _dbVersion = 8;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    batch.execute('''
      CREATE TABLE members (
        id            TEXT PRIMARY KEY,
        family_id     TEXT NOT NULL,
        name          TEXT NOT NULL,
        age           INTEGER NOT NULL DEFAULT 0,
        profile_type  TEXT NOT NULL DEFAULT 'adult',
        phone         TEXT,
        user_id       TEXT,
        created_at    TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at    TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    batch.execute('''
      CREATE TABLE medications (
        id               TEXT PRIMARY KEY,
        family_id        TEXT NOT NULL,
        member_id        TEXT NOT NULL REFERENCES members(id) ON DELETE CASCADE,
        name             TEXT NOT NULL,
        dose             TEXT NOT NULL,
        frequency        TEXT NOT NULL,
        time_of_day      TEXT NOT NULL,
        reminder_hour    INTEGER NOT NULL DEFAULT 8,
        reminder_minute  INTEGER NOT NULL DEFAULT 0,
        is_active        INTEGER NOT NULL DEFAULT 1,
        show_on_calendar INTEGER NOT NULL DEFAULT 1,
        created_at       TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at       TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    batch.execute('''
      CREATE TABLE med_confirmations (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        medication_id   TEXT NOT NULL REFERENCES medications(id) ON DELETE CASCADE,
        confirmed_at    TEXT NOT NULL DEFAULT (datetime('now')),
        date            TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE vital_signs (
        id           TEXT PRIMARY KEY,
        family_id    TEXT NOT NULL,
        member_id    TEXT NOT NULL REFERENCES members(id) ON DELETE CASCADE,
        type         TEXT NOT NULL,
        value        REAL NOT NULL,
        unit         TEXT NOT NULL,
        recorded_at  TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    batch.execute('''
      CREATE TABLE appointments (
        id               TEXT PRIMARY KEY,
        family_id        TEXT NOT NULL,
        member_id        TEXT NOT NULL REFERENCES members(id) ON DELETE CASCADE,
        title            TEXT NOT NULL,
        doctor           TEXT,
        location         TEXT,
        scheduled_at     TEXT NOT NULL,
        notes            TEXT,
        show_on_calendar INTEGER NOT NULL DEFAULT 1,
        created_at       TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at       TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    batch.execute('''
      CREATE TABLE documents (
        id          TEXT PRIMARY KEY,
        family_id   TEXT NOT NULL,
        member_id   TEXT NOT NULL REFERENCES members(id) ON DELETE CASCADE,
        title       TEXT NOT NULL,
        file_path   TEXT NOT NULL,
        doc_type    TEXT NOT NULL,
        created_at  TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at  TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    batch.execute('''
      CREATE TABLE vaccinations (
        id               TEXT PRIMARY KEY,
        family_id        TEXT NOT NULL,
        member_id        TEXT NOT NULL REFERENCES members(id) ON DELETE CASCADE,
        vaccine_name     TEXT NOT NULL,
        clinic_name      TEXT,
        received_at      TEXT,
        date_given       TEXT,
        next_due         TEXT,
        notes            TEXT,
        is_received      INTEGER NOT NULL DEFAULT 0,
        show_on_calendar INTEGER NOT NULL DEFAULT 1,
        created_at       TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at       TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    batch.execute('''
      CREATE TABLE prenatal_tests (
        id            TEXT PRIMARY KEY,
        family_id     TEXT NOT NULL,
        member_id     TEXT NOT NULL REFERENCES members(id) ON DELETE CASCADE,
        trimester     INTEGER NOT NULL,
        test_name     TEXT NOT NULL,
        is_completed  INTEGER NOT NULL DEFAULT 0,
        completed_at  TEXT,
        created_at    TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at    TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    batch.execute('''
      CREATE TABLE ultrasounds (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        family_id     TEXT NOT NULL,
        member_id     TEXT NOT NULL REFERENCES members(id) ON DELETE CASCADE,
        month_label   TEXT NOT NULL,
        session_type  TEXT NOT NULL,
        date          TEXT NOT NULL,
        doctor        TEXT NOT NULL DEFAULT '',
        notes         TEXT NOT NULL DEFAULT '',
        created_at    TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    await batch.commit(noResult: true);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _dropAllKnownTables(db);
      await _onCreate(db, newVersion);
      return;
    }

    // Safe additive migrations. These do not delete user cache data.
    await _addColumnIfMissing(db, 'members', 'phone', 'TEXT');
    await _addColumnIfMissing(db, 'members', 'user_id', 'TEXT');

    await _addColumnIfMissing(db, 'medications', 'reminder_hour', 'INTEGER NOT NULL DEFAULT 8');
    await _addColumnIfMissing(db, 'medications', 'reminder_minute', 'INTEGER NOT NULL DEFAULT 0');
    await _addColumnIfMissing(db, 'medications', 'show_on_calendar', 'INTEGER NOT NULL DEFAULT 1');

    await _addColumnIfMissing(db, 'appointments', 'location', 'TEXT');
    await _addColumnIfMissing(db, 'appointments', 'show_on_calendar', 'INTEGER NOT NULL DEFAULT 1');

    await _addColumnIfMissing(db, 'vaccinations', 'date_given', 'TEXT');
    await _addColumnIfMissing(db, 'vaccinations', 'next_due', 'TEXT');
    await _addColumnIfMissing(db, 'vaccinations', 'notes', 'TEXT');
    await _addColumnIfMissing(db, 'vaccinations', 'show_on_calendar', 'INTEGER NOT NULL DEFAULT 1');

    await _ensurePrenatalTestsTable(db);
  }

  Future<void> _dropAllKnownTables(Database db) async {
    final batch = db.batch();
    batch.execute('DROP TABLE IF EXISTS ultrasounds');
    batch.execute('DROP TABLE IF EXISTS prenatal_tests');
    batch.execute('DROP TABLE IF EXISTS vaccinations');
    batch.execute('DROP TABLE IF EXISTS documents');
    batch.execute('DROP TABLE IF EXISTS appointments');
    batch.execute('DROP TABLE IF EXISTS vital_signs');
    batch.execute('DROP TABLE IF EXISTS med_confirmations');
    batch.execute('DROP TABLE IF EXISTS medications');
    batch.execute('DROP TABLE IF EXISTS members');
    await batch.commit(noResult: true);
  }

  Future<void> _ensurePrenatalTestsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS prenatal_tests (
        id            TEXT PRIMARY KEY,
        family_id     TEXT NOT NULL,
        member_id     TEXT NOT NULL,
        trimester     INTEGER NOT NULL,
        test_name     TEXT NOT NULL,
        is_completed  INTEGER NOT NULL DEFAULT 0,
        completed_at  TEXT,
        created_at    TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at    TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');
  }

  Future<void> _addColumnIfMissing(
      Database db, String table, String column, String definition) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    final exists = info.any((row) => row['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }
}
