import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseProvider {
  DatabaseProvider._();
  static final DatabaseProvider instance = DatabaseProvider._();

  static Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  static const _dbName    = 'e3lty.db';
  static const _dbVersion = 4; // ← bumped from 3 to 4 (adds phone column)

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path   = join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
    );
  }

  // ── onCreate: full schema including phone ──────────────────────────────────
  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    batch.execute('''
      CREATE TABLE members (
        id           TEXT    PRIMARY KEY,
        family_id    TEXT    NOT NULL,
        name         TEXT    NOT NULL,
        age          INTEGER NOT NULL,
        profile_type TEXT    NOT NULL,
        user_id      TEXT,
        phone        TEXT,
        created_at   TEXT    NOT NULL DEFAULT (datetime('now')),
        updated_at   TEXT    NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    batch.execute('''
      CREATE TABLE medications (
        id          TEXT    PRIMARY KEY,
        family_id   TEXT    NOT NULL,
        member_id   TEXT    NOT NULL REFERENCES members(id) ON DELETE CASCADE,
        name        TEXT    NOT NULL,
        dose        TEXT    NOT NULL,
        frequency   TEXT    NOT NULL,
        time_of_day TEXT    NOT NULL,
        is_active   INTEGER NOT NULL DEFAULT 1,
        created_at  TEXT    NOT NULL DEFAULT (datetime('now')),
        updated_at  TEXT    NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    batch.execute('''
      CREATE TABLE med_confirmations (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        medication_id TEXT    NOT NULL REFERENCES medications(id) ON DELETE CASCADE,
        confirmed_at  TEXT    NOT NULL DEFAULT (datetime('now')),
        date          TEXT    NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE vital_signs (
        id          TEXT    PRIMARY KEY,
        family_id   TEXT    NOT NULL,
        member_id   TEXT    NOT NULL REFERENCES members(id) ON DELETE CASCADE,
        type        TEXT    NOT NULL,
        value       REAL    NOT NULL,
        unit        TEXT    NOT NULL,
        recorded_at TEXT    NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    batch.execute('''
      CREATE TABLE appointments (
        id           TEXT    PRIMARY KEY,
        family_id    TEXT    NOT NULL,
        member_id    TEXT    NOT NULL REFERENCES members(id) ON DELETE CASCADE,
        title        TEXT    NOT NULL,
        doctor       TEXT,
        location     TEXT,
        scheduled_at TEXT    NOT NULL,
        notes        TEXT,
        created_at   TEXT    NOT NULL DEFAULT (datetime('now')),
        updated_at   TEXT    NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    batch.execute('''
      CREATE TABLE documents (
        id           TEXT    PRIMARY KEY,
        family_id    TEXT    NOT NULL,
        member_id    TEXT    NOT NULL REFERENCES members(id) ON DELETE CASCADE,
        title        TEXT    NOT NULL,
        file_path    TEXT    NOT NULL,
        doc_type     TEXT    NOT NULL,
        created_at   TEXT    NOT NULL DEFAULT (datetime('now')),
        updated_at   TEXT    NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    batch.execute('''
      CREATE TABLE vaccinations (
        id           TEXT    PRIMARY KEY,
        family_id    TEXT    NOT NULL,
        member_id    TEXT    NOT NULL REFERENCES members(id) ON DELETE CASCADE,
        vaccine_name TEXT    NOT NULL,
        clinic_name  TEXT,
        received_at  TEXT,
        is_received  INTEGER NOT NULL DEFAULT 0,
        created_at   TEXT    NOT NULL DEFAULT (datetime('now')),
        updated_at   TEXT    NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    batch.execute('''
      CREATE TABLE ultrasounds (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        family_id    TEXT    NOT NULL,
        member_id    TEXT    NOT NULL REFERENCES members(id) ON DELETE CASCADE,
        month_label  TEXT    NOT NULL,
        session_type TEXT    NOT NULL,
        date         TEXT    NOT NULL,
        doctor       TEXT    NOT NULL DEFAULT '',
        notes        TEXT    NOT NULL DEFAULT '',
        created_at   TEXT    NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    await batch.commit(noResult: true);

    await db.execute('''
      CREATE TABLE IF NOT EXISTS prenatal_tests (
        id           TEXT PRIMARY KEY,
        member_id    TEXT NOT NULL,
        test_name    TEXT NOT NULL,
        trimester    INTEGER NOT NULL,
        is_completed INTEGER NOT NULL DEFAULT 0,
        completed_at TEXT,
        due_date     TEXT,
        created_at   TEXT DEFAULT (datetime('now'))
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS vital_thresholds (
        id          TEXT PRIMARY KEY,
        member_id   TEXT NOT NULL,
        family_id   TEXT,
        vital_type  TEXT NOT NULL,
        danger_min  REAL NOT NULL DEFAULT 0,
        danger_max  REAL NOT NULL DEFAULT 999,
        warning_min REAL NOT NULL DEFAULT 0,
        warning_max REAL NOT NULL DEFAULT 999,
        updated_at  TEXT DEFAULT (datetime('now')),
        UNIQUE(member_id, vital_type)
      )
    ''');
  }

  // ── onUpgrade ──────────────────────────────────────────────────────────────
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // v1 → v2: add family_id support (full rebuild)
    if (oldVersion < 2) {
      final batch = db.batch();
      batch.execute('DROP TABLE IF EXISTS vaccinations');
      batch.execute('DROP TABLE IF EXISTS documents');
      batch.execute('DROP TABLE IF EXISTS appointments');
      batch.execute('DROP TABLE IF EXISTS vital_signs');
      batch.execute('DROP TABLE IF EXISTS med_confirmations');
      batch.execute('DROP TABLE IF EXISTS medications');
      batch.execute('DROP TABLE IF EXISTS members');

      batch.execute('''
        CREATE TABLE members (
          id           TEXT    PRIMARY KEY,
          family_id    TEXT    NOT NULL,
          name         TEXT    NOT NULL,
          age          INTEGER NOT NULL,
          profile_type TEXT    NOT NULL,
          user_id      TEXT,
          phone        TEXT,
          created_at   TEXT    NOT NULL DEFAULT (datetime('now')),
          updated_at   TEXT    NOT NULL DEFAULT (datetime('now'))
        )
      ''');
      batch.execute('''
        CREATE TABLE medications (
          id          TEXT PRIMARY KEY, family_id TEXT NOT NULL,
          member_id   TEXT NOT NULL REFERENCES members(id) ON DELETE CASCADE,
          name TEXT NOT NULL, dose TEXT NOT NULL, frequency TEXT NOT NULL,
          time_of_day TEXT NOT NULL, is_active INTEGER NOT NULL DEFAULT 1,
          created_at TEXT NOT NULL DEFAULT (datetime('now')),
          updated_at TEXT NOT NULL DEFAULT (datetime('now'))
        )
      ''');
      batch.execute('''
        CREATE TABLE med_confirmations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          medication_id TEXT NOT NULL REFERENCES medications(id) ON DELETE CASCADE,
          confirmed_at TEXT NOT NULL DEFAULT (datetime('now')), date TEXT NOT NULL
        )
      ''');
      batch.execute('''
        CREATE TABLE vital_signs (
          id TEXT PRIMARY KEY, family_id TEXT NOT NULL,
          member_id TEXT NOT NULL REFERENCES members(id) ON DELETE CASCADE,
          type TEXT NOT NULL, value REAL NOT NULL, unit TEXT NOT NULL,
          recorded_at TEXT NOT NULL DEFAULT (datetime('now'))
        )
      ''');
      batch.execute('''
        CREATE TABLE appointments (
          id TEXT PRIMARY KEY, family_id TEXT NOT NULL,
          member_id TEXT NOT NULL REFERENCES members(id) ON DELETE CASCADE,
          title TEXT NOT NULL, doctor TEXT, location TEXT,
          scheduled_at TEXT NOT NULL, notes TEXT,
          created_at TEXT NOT NULL DEFAULT (datetime('now')),
          updated_at TEXT NOT NULL DEFAULT (datetime('now'))
        )
      ''');
      batch.execute('''
        CREATE TABLE documents (
          id TEXT PRIMARY KEY, family_id TEXT NOT NULL,
          member_id TEXT NOT NULL REFERENCES members(id) ON DELETE CASCADE,
          title TEXT NOT NULL, file_path TEXT NOT NULL, doc_type TEXT NOT NULL,
          created_at TEXT NOT NULL DEFAULT (datetime('now')),
          updated_at TEXT NOT NULL DEFAULT (datetime('now'))
        )
      ''');
      batch.execute('''
        CREATE TABLE vaccinations (
          id TEXT PRIMARY KEY, family_id TEXT NOT NULL,
          member_id TEXT NOT NULL REFERENCES members(id) ON DELETE CASCADE,
          vaccine_name TEXT NOT NULL, clinic_name TEXT, received_at TEXT,
          is_received INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL DEFAULT (datetime('now')),
          updated_at TEXT NOT NULL DEFAULT (datetime('now'))
        )
      ''');
      batch.execute('''
        CREATE TABLE ultrasounds (
          id INTEGER PRIMARY KEY AUTOINCREMENT, family_id TEXT NOT NULL,
          member_id TEXT NOT NULL REFERENCES members(id) ON DELETE CASCADE,
          month_label TEXT NOT NULL, session_type TEXT NOT NULL,
          date TEXT NOT NULL, doctor TEXT NOT NULL DEFAULT '',
          notes TEXT NOT NULL DEFAULT '',
          created_at TEXT NOT NULL DEFAULT (datetime('now'))
        )
      ''');
      await batch.commit(noResult: true);
    }

    // v2 → v3: add ultrasounds table
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ultrasounds (
          id INTEGER PRIMARY KEY AUTOINCREMENT, family_id TEXT NOT NULL,
          member_id TEXT NOT NULL REFERENCES members(id) ON DELETE CASCADE,
          month_label TEXT NOT NULL, session_type TEXT NOT NULL,
          date TEXT NOT NULL, doctor TEXT NOT NULL DEFAULT '',
          notes TEXT NOT NULL DEFAULT '',
          created_at TEXT NOT NULL DEFAULT (datetime('now'))
        )
      ''');
    }

    // ── v3 → v4: ADD phone column to members ─────────────────────────────────
    if (oldVersion < 4) {
      try {
        await db.execute(
          'ALTER TABLE members ADD COLUMN phone TEXT',
        );
      } catch (_) {
        // Column might already exist on some devices — safe to ignore
      }
    }
  }
}