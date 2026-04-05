import 'package:sqflite/sqflite.dart';
import 'database_provider.dart';

// ─── Lightweight data models (DB ↔ Dart) ─────────────────────────────────────

class MemberRecord {
  final int?   id;
  final String name;
  final int    age;
  final String profileType; // matches ProfileType.name
  final String createdAt;

  const MemberRecord({
    this.id,
    required this.name,
    required this.age,
    required this.profileType,
    this.createdAt = '',
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'name':         name,
    'age':          age,
    'profile_type': profileType,
  };

  factory MemberRecord.fromMap(Map<String, dynamic> m) => MemberRecord(
    id:          m['id'] as int,
    name:        m['name'] as String,
    age:         m['age'] as int,
    profileType: m['profile_type'] as String,
    createdAt:   m['created_at'] as String? ?? '',
  );
}

class MedicationRecord {
  final int?   id;
  final int    memberId;
  final String name;
  final String dose;
  final String frequency;
  final String timeOfDay;
  final bool   isActive;

  const MedicationRecord({
    this.id,
    required this.memberId,
    required this.name,
    required this.dose,
    required this.frequency,
    required this.timeOfDay,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'member_id':   memberId,
    'name':        name,
    'dose':        dose,
    'frequency':   frequency,
    'time_of_day': timeOfDay,
    'is_active':   isActive ? 1 : 0,
  };

  factory MedicationRecord.fromMap(Map<String, dynamic> m) => MedicationRecord(
    id:         m['id'] as int,
    memberId:   m['member_id'] as int,
    name:       m['name'] as String,
    dose:       m['dose'] as String,
    frequency:  m['frequency'] as String,
    timeOfDay:  m['time_of_day'] as String,
    isActive:   (m['is_active'] as int) == 1,
  );
}

class VitalRecord {
  final int?   id;
  final int    memberId;
  final String type;        // e.g. 'blood_pressure_systolic', 'blood_sugar'
  final double value;
  final String unit;
  final String recordedAt;

  const VitalRecord({
    this.id,
    required this.memberId,
    required this.type,
    required this.value,
    required this.unit,
    this.recordedAt = '',
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'member_id':   memberId,
    'type':        type,
    'value':       value,
    'unit':        unit,
  };

  factory VitalRecord.fromMap(Map<String, dynamic> m) => VitalRecord(
    id:         m['id'] as int,
    memberId:   m['member_id'] as int,
    type:       m['type'] as String,
    value:      (m['value'] as num).toDouble(),
    unit:       m['unit'] as String,
    recordedAt: m['recorded_at'] as String? ?? '',
  );
}

class AppointmentRecord {
  final int?   id;
  final int    memberId;
  final String title;
  final String? doctor;
  final String? location;
  final String scheduledAt;
  final String? notes;

  const AppointmentRecord({
    this.id,
    required this.memberId,
    required this.title,
    this.doctor,
    this.location,
    required this.scheduledAt,
    this.notes,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'member_id':    memberId,
    'title':        title,
    'doctor':       doctor,
    'location':     location,
    'scheduled_at': scheduledAt,
    'notes':        notes,
  };

  factory AppointmentRecord.fromMap(Map<String, dynamic> m) => AppointmentRecord(
    id:          m['id'] as int,
    memberId:    m['member_id'] as int,
    title:       m['title'] as String,
    doctor:      m['doctor'] as String?,
    location:    m['location'] as String?,
    scheduledAt: m['scheduled_at'] as String,
    notes:       m['notes'] as String?,
  );
}

class DocumentRecord {
  final int?   id;
  final int    memberId;
  final String title;
  final String filePath;
  final String docType;   // e.g. 'lab_result', 'prescription', 'xray'
  final String createdAt;

  const DocumentRecord({
    this.id,
    required this.memberId,
    required this.title,
    required this.filePath,
    required this.docType,
    this.createdAt = '',
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'member_id': memberId,
    'title':     title,
    'file_path': filePath,
    'doc_type':  docType,
  };

  factory DocumentRecord.fromMap(Map<String, dynamic> m) => DocumentRecord(
    id:        m['id'] as int,
    memberId:  m['member_id'] as int,
    title:     m['title'] as String,
    filePath:  m['file_path'] as String,
    docType:   m['doc_type'] as String,
    createdAt: m['created_at'] as String? ?? '',
  );
}

class VaccinationRecord {
  final int?   id;
  final int    memberId;
  final String vaccineName;
  final String? clinicName;
  final String? receivedAt;
  final bool   isReceived;

  const VaccinationRecord({
    this.id,
    required this.memberId,
    required this.vaccineName,
    this.clinicName,
    this.receivedAt,
    this.isReceived = false,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'member_id':    memberId,
    'vaccine_name': vaccineName,
    'clinic_name':  clinicName,
    'received_at':  receivedAt,
    'is_received':  isReceived ? 1 : 0,
  };

  factory VaccinationRecord.fromMap(Map<String, dynamic> m) => VaccinationRecord(
    id:          m['id'] as int,
    memberId:    m['member_id'] as int,
    vaccineName: m['vaccine_name'] as String,
    clinicName:  m['clinic_name'] as String?,
    receivedAt:  m['received_at'] as String?,
    isReceived:  (m['is_received'] as int) == 1,
  );
}

// ─── Repository ───────────────────────────────────────────────────────────────

/// Single access point for all DB reads and writes.
/// Inject or use as a singleton via [AppRepository.instance].
class AppRepository {
  AppRepository._();
  static final AppRepository instance = AppRepository._();

  Future<Database> get _db => DatabaseProvider.instance.database;

  // ══ Members ════════════════════════════════════════════════════════════════

  Future<int> insertMember(MemberRecord m) async {
    final db = await _db;
    return db.insert('members', m.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<MemberRecord>> getAllMembers() async {
    final db   = await _db;
    final rows = await db.query('members', orderBy: 'created_at ASC');
    return rows.map(MemberRecord.fromMap).toList();
  }

  Future<MemberRecord?> getMemberById(int id) async {
    final db   = await _db;
    final rows = await db.query('members', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : MemberRecord.fromMap(rows.first);
  }

  Future<int> updateMember(MemberRecord m) async {
    final db = await _db;
    return db.update('members', m.toMap(), where: 'id = ?', whereArgs: [m.id]);
  }

  Future<int> deleteMember(int id) async {
    final db = await _db;
    // Cascade deletes all related rows (medications, vitals, etc.)
    return db.delete('members', where: 'id = ?', whereArgs: [id]);
  }

  // ══ Medications ════════════════════════════════════════════════════════════

  Future<int> insertMedication(MedicationRecord r) async {
    final db = await _db;
    return db.insert('medications', r.toMap());
  }

  Future<List<MedicationRecord>> getMedicationsForMember(int memberId) async {
    final db   = await _db;
    final rows = await db.query('medications',
        where: 'member_id = ? AND is_active = 1', whereArgs: [memberId]);
    return rows.map(MedicationRecord.fromMap).toList();
  }

  Future<int> updateMedication(MedicationRecord r) async {
    final db = await _db;
    return db.update('medications', r.toMap(),
        where: 'id = ?', whereArgs: [r.id]);
  }

  Future<int> deleteMedication(int id) async {
    final db = await _db;
    return db.delete('medications', where: 'id = ?', whereArgs: [id]);
  }

  // Confirm today's dose for a medication
  Future<int> confirmMedication(int medicationId) async {
    final db    = await _db;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return db.insert('med_confirmations', {
      'medication_id': medicationId,
      'date':          today,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Check if a medication was confirmed today
  Future<bool> isMedicationConfirmedToday(int medicationId) async {
    final db    = await _db;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final rows  = await db.query('med_confirmations',
        where: 'medication_id = ? AND date = ?',
        whereArgs: [medicationId, today]);
    return rows.isNotEmpty;
  }

  // ══ Vital Signs ════════════════════════════════════════════════════════════

  Future<int> insertVital(VitalRecord r) async {
    final db = await _db;
    return db.insert('vital_signs', r.toMap());
  }

  Future<List<VitalRecord>> getVitalsForMember(int memberId,
      {String? type, int limit = 30}) async {
    final db = await _db;
    final rows = await db.query(
      'vital_signs',
      where:    type != null ? 'member_id = ? AND type = ?' : 'member_id = ?',
      whereArgs: type != null ? [memberId, type] : [memberId],
      orderBy:  'recorded_at DESC',
      limit:    limit,
    );
    return rows.map(VitalRecord.fromMap).toList();
  }

  Future<VitalRecord?> getLatestVital(int memberId, String type) async {
    final vitals = await getVitalsForMember(memberId, type: type, limit: 1);
    return vitals.isEmpty ? null : vitals.first;
  }

  // ══ Appointments ═══════════════════════════════════════════════════════════

  Future<int> insertAppointment(AppointmentRecord r) async {
    final db = await _db;
    return db.insert('appointments', r.toMap());
  }

  Future<List<AppointmentRecord>> getAppointmentsForMember(int memberId) async {
    final db   = await _db;
    final rows = await db.query('appointments',
        where: 'member_id = ?', whereArgs: [memberId],
        orderBy: 'scheduled_at ASC');
    return rows.map(AppointmentRecord.fromMap).toList();
  }

  Future<List<AppointmentRecord>> getUpcomingAppointments() async {
    final db  = await _db;
    final now = DateTime.now().toIso8601String();
    final rows = await db.query('appointments',
        where:    'scheduled_at >= ?',
        whereArgs: [now],
        orderBy:  'scheduled_at ASC',
        limit:    20);
    return rows.map(AppointmentRecord.fromMap).toList();
  }

  Future<int> deleteAppointment(int id) async {
    final db = await _db;
    return db.delete('appointments', where: 'id = ?', whereArgs: [id]);
  }

  // ══ Documents ══════════════════════════════════════════════════════════════

  Future<int> insertDocument(DocumentRecord r) async {
    final db = await _db;
    return db.insert('documents', r.toMap());
  }

  Future<List<DocumentRecord>> getDocumentsForMember(int memberId) async {
    final db   = await _db;
    final rows = await db.query('documents',
        where: 'member_id = ?', whereArgs: [memberId],
        orderBy: 'created_at DESC');
    return rows.map(DocumentRecord.fromMap).toList();
  }

  Future<int> deleteDocument(int id) async {
    final db = await _db;
    return db.delete('documents', where: 'id = ?', whereArgs: [id]);
  }

  // ══ Vaccinations ═══════════════════════════════════════════════════════════

  Future<int> insertVaccination(VaccinationRecord r) async {
    final db = await _db;
    return db.insert('vaccinations', r.toMap());
  }

  Future<List<VaccinationRecord>> getVaccinationsForMember(int memberId) async {
    final db   = await _db;
    final rows = await db.query('vaccinations',
        where: 'member_id = ?', whereArgs: [memberId]);
    return rows.map(VaccinationRecord.fromMap).toList();
  }

  Future<int> markVaccinationReceived(int id,
      {required String clinicName, required String receivedAt}) async {
    final db = await _db;
    return db.update(
      'vaccinations',
      {'is_received': 1, 'clinic_name': clinicName, 'received_at': receivedAt},
      where:    'id = ?',
      whereArgs: [id],
    );
  }
}