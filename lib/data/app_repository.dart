import 'package:sqflite/sqflite.dart';
import 'database_provider.dart';

// ─── MemberRecord ─────────────────────────────────────────────────────────────
class MemberRecord {
  final String? id;
  final String? familyId;
  final String name;
  final int age;
  final String profileType;
  final String? userId;
  final String? phone;          // ← ADDED
  final String createdAt;
  final String updatedAt;

  const MemberRecord({
    this.id,
    this.familyId,
    required this.name,
    required this.age,
    required this.profileType,
    this.userId,
    this.phone,                 // ← ADDED
    this.createdAt = '',
    this.updatedAt = '',
  });

  Map<String, dynamic> toMap() => {
    if (id != null)       'id': id,
    if (familyId != null) 'family_id': familyId,
    'name':         name,
    'age':          age,
    'profile_type': profileType,
    if (userId != null) 'user_id': userId,
    if (phone != null)  'phone': phone,   // ← ADDED
  };

  factory MemberRecord.fromMap(Map<String, dynamic> m) => MemberRecord(
    id:          m['id'] as String?,
    familyId:    m['family_id'] as String?,
    name:        m['name'] as String,
    age:         m['age'] as int,
    profileType: m['profile_type'] as String,
    userId:      m['user_id'] as String?,
    phone:       m['phone'] as String?,   // ← ADDED (safe — returns null if missing)
    createdAt:   m['created_at'] as String? ?? '',
    updatedAt:   m['updated_at'] as String? ?? '',
  );
}

// ─── MedicationRecord ─────────────────────────────────────────────────────────
class MedicationRecord {
  final String? id;
  final String? familyId;
  final String memberId;
  final String name;
  final String dose;
  final String frequency;
  final String timeOfDay;
  final int reminderHour;    // 0-23, الساعة المختارة من TimePicker
  final int reminderMinute;  // 0-59، الدقيقة المختارة من TimePicker
  final bool isActive;
  final bool showOnFamilyCalendar;
  final String createdAt;
  final String updatedAt;

  const MedicationRecord({
    this.id,
    this.familyId,
    required this.memberId,
    required this.name,
    required this.dose,
    required this.frequency,
    required this.timeOfDay,
    this.reminderHour = 8,
    this.reminderMinute = 0,
    this.isActive = true,
    this.showOnFamilyCalendar = false,
    this.createdAt = '',
    this.updatedAt = '',
  });

  MedicationRecord copyWith({
    String? id,
    String? familyId,
    String? memberId,
    String? name,
    String? dose,
    String? frequency,
    String? timeOfDay,
    int? reminderHour,
    int? reminderMinute,
    bool? isActive,
    bool? showOnFamilyCalendar,
  }) => MedicationRecord(
    id:             id             ?? this.id,
    familyId:       familyId       ?? this.familyId,
    memberId:       memberId       ?? this.memberId,
    name:           name           ?? this.name,
    dose:           dose           ?? this.dose,
    frequency:      frequency      ?? this.frequency,
    timeOfDay:      timeOfDay      ?? this.timeOfDay,
    reminderHour:   reminderHour   ?? this.reminderHour,
    reminderMinute: reminderMinute ?? this.reminderMinute,
    isActive:       isActive       ?? this.isActive,
    showOnFamilyCalendar: showOnFamilyCalendar ?? this.showOnFamilyCalendar,
    createdAt:      this.createdAt,
    updatedAt:      this.updatedAt,
  );

  Map<String, dynamic> toMap() => {
    if (id != null)       'id': id,
    if (familyId != null) 'family_id': familyId,
    'member_id':     memberId,
    'name':          name,
    'dose':          dose,
    'frequency':     frequency,
    'time_of_day':   timeOfDay,
    'reminder_hour':   reminderHour,
    'reminder_minute': reminderMinute,
    'is_active':     isActive ? 1 : 0,
    'show_on_family_calendar': showOnFamilyCalendar ? 1 : 0,
  };

  factory MedicationRecord.fromMap(Map<String, dynamic> m) => MedicationRecord(
    id:             m['id'] as String?,
    familyId:       m['family_id'] as String?,
    memberId:       m['member_id'] as String,
    name:           m['name'] as String,
    dose:           m['dose'] as String,
    frequency:      m['frequency'] as String,
    timeOfDay:      m['time_of_day'] as String,
    reminderHour:   (m['reminder_hour'] as int?) ?? 8,
    reminderMinute: (m['reminder_minute'] as int?) ?? 0,
    isActive:       ((m['is_active'] as int?) ?? 1) == 1,
    showOnFamilyCalendar: ((m['show_on_family_calendar'] as int?) ?? 0) == 1,
    createdAt:      m['created_at'] as String? ?? '',
    updatedAt:      m['updated_at'] as String? ?? '',
  );
}

// ─── VitalRecord ──────────────────────────────────────────────────────────────
class VitalRecord {
  final String? id;
  final String? familyId;
  final String memberId;
  final String type;
  final double value;
  final String unit;
  final String recordedAt;

  const VitalRecord({
    this.id,
    this.familyId,
    required this.memberId,
    required this.type,
    required this.value,
    required this.unit,
    this.recordedAt = '',
  });

  Map<String, dynamic> toMap() => {
    if (id != null)       'id': id,
    if (familyId != null) 'family_id': familyId,
    'member_id': memberId,
    'type':      type,
    'value':     value,
    'unit':      unit,
  };

  factory VitalRecord.fromMap(Map<String, dynamic> m) => VitalRecord(
    id:         m['id'] as String?,
    familyId:   m['family_id'] as String?,
    memberId:   m['member_id'] as String,
    type:       m['type'] as String,
    value:      (m['value'] as num).toDouble(),
    unit:       m['unit'] as String,
    recordedAt: m['recorded_at'] as String? ?? '',
  );
}

// ─── AppointmentRecord ────────────────────────────────────────────────────────
class AppointmentRecord {
  final String? id;
  final String? familyId;
  final String memberId;
  final String title;
  final String? doctor;
  final String? location;
  final String scheduledAt;
  final String? notes;
  final bool showOnFamilyCalendar;
  final String createdAt;
  final String updatedAt;

  const AppointmentRecord({
    this.id,
    this.familyId,
    required this.memberId,
    required this.title,
    this.doctor,
    this.location,
    required this.scheduledAt,
    this.notes,
    this.showOnFamilyCalendar = false,
    this.createdAt = '',
    this.updatedAt = '',
  });

  Map<String, dynamic> toMap() => {
    if (id != null)       'id': id,
    if (familyId != null) 'family_id': familyId,
    'member_id':   memberId,
    'title':       title,
    'doctor':      doctor,
    'location':    location,
    'scheduled_at': scheduledAt,
    'notes':       notes,
    'show_on_family_calendar': showOnFamilyCalendar ? 1 : 0,
  };

  factory AppointmentRecord.fromMap(Map<String, dynamic> m) => AppointmentRecord(
    id:          m['id'] as String?,
    familyId:    m['family_id'] as String?,
    memberId:    m['member_id'] as String,
    title:       m['title'] as String,
    doctor:      m['doctor'] as String?,
    location:    m['location'] as String?,
    scheduledAt: m['scheduled_at'] as String,
    notes:       m['notes'] as String?,
    showOnFamilyCalendar: ((m['show_on_family_calendar'] as int?) ?? 0) == 1,
    createdAt:   m['created_at'] as String? ?? '',
    updatedAt:   m['updated_at'] as String? ?? '',
  );
}

// ─── DocumentRecord ───────────────────────────────────────────────────────────
class DocumentRecord {
  final String? id;
  final String? familyId;
  final String memberId;
  final String title;
  final String filePath;
  final String docType;
  final String createdAt;
  final String updatedAt;

  const DocumentRecord({
    this.id,
    this.familyId,
    required this.memberId,
    required this.title,
    required this.filePath,
    required this.docType,
    this.createdAt = '',
    this.updatedAt = '',
  });

  Map<String, dynamic> toMap() => {
    if (id != null)       'id': id,
    if (familyId != null) 'family_id': familyId,
    'member_id': memberId,
    'title':     title,
    'file_path': filePath,
    'doc_type':  docType,
  };

  factory DocumentRecord.fromMap(Map<String, dynamic> m) => DocumentRecord(
    id:        m['id'] as String?,
    familyId:  m['family_id'] as String?,
    memberId:  m['member_id'] as String,
    title:     m['title'] as String,
    filePath:  m['file_path'] as String,
    docType:   m['doc_type'] as String,
    createdAt: m['created_at'] as String? ?? '',
    updatedAt: m['updated_at'] as String? ?? '',
  );
}

// ─── VaccinationRecord ────────────────────────────────────────────────────────
class VaccinationRecord {
  final String? id;
  final String? familyId;
  final String memberId;
  final String vaccineName;
  final String? clinicName;
  final String? receivedAt;
  final bool isReceived;
  final bool showOnFamilyCalendar;
  final String createdAt;
  final String updatedAt;

  const VaccinationRecord({
    this.id,
    this.familyId,
    required this.memberId,
    required this.vaccineName,
    this.clinicName,
    this.receivedAt,
    this.isReceived = false,
    this.showOnFamilyCalendar = false,
    this.createdAt = '',
    this.updatedAt = '',
  });

  Map<String, dynamic> toMap() => {
    if (id != null)       'id': id,
    if (familyId != null) 'family_id': familyId,
    'member_id':   memberId,
    'vaccine_name': vaccineName,
    'clinic_name': clinicName,
    'received_at': receivedAt,
    'is_received': isReceived ? 1 : 0,
    'show_on_family_calendar': showOnFamilyCalendar ? 1 : 0,
  };

  factory VaccinationRecord.fromMap(Map<String, dynamic> m) => VaccinationRecord(
    id:          m['id'] as String?,
    familyId:    m['family_id'] as String?,
    memberId:    m['member_id'] as String,
    vaccineName: m['vaccine_name'] as String,
    clinicName:  m['clinic_name'] as String?,
    receivedAt:  m['received_at'] as String?,
    isReceived:  ((m['is_received'] as int?) ?? 0) == 1,
    showOnFamilyCalendar: ((m['show_on_family_calendar'] as int?) ?? 0) == 1,
    createdAt:   m['created_at'] as String? ?? '',
    updatedAt:   m['updated_at'] as String? ?? '',
  );
}

// ─── UltrasoundRecord ─────────────────────────────────────────────────────────
class UltrasoundRecord {
  final int? id;
  final String familyId;
  final String memberId;
  final String monthLabel;
  final String sessionType;
  final String date;
  final String doctor;
  final String notes;
  final String createdAt;

  UltrasoundRecord({
    this.id,
    required this.familyId,
    required this.memberId,
    required this.monthLabel,
    required this.sessionType,
    required this.date,
    required this.doctor,
    required this.notes,
    this.createdAt = '',
  });

  factory UltrasoundRecord.fromMap(Map<String, dynamic> m) => UltrasoundRecord(
    id:          m['id'] as int?,
    familyId:    m['family_id'] as String,
    memberId:    m['member_id'].toString(),
    monthLabel:  m['month_label'] as String,
    sessionType: m['session_type'] as String,
    date:        m['date'] as String,
    doctor:      m['doctor'] as String,
    notes:       m['notes'] as String,
    createdAt:   m['created_at'] as String? ?? '',
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'family_id':    familyId,
    'member_id':    memberId,
    'month_label':  monthLabel,
    'session_type': sessionType,
    'date':         date,
    'doctor':       doctor,
    'notes':        notes,
  };
}

// ─── AppRepository ────────────────────────────────────────────────────────────
class AppRepository {
  AppRepository._();
  static final AppRepository instance = AppRepository._();
  factory AppRepository() => instance;

  Future<Database> get _db => DatabaseProvider.instance.database;

  // ══ Members ════════════════════════════════════════════════════════════════

  Future<void> addMember(Map<String, dynamic> memberData) async {
    final db = await _db;
    await db.insert('members', memberData,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateMember(Map<String, dynamic> memberData) async {
    final db = await _db;
    final id = memberData['id'] as String?;
    if (id == null) throw Exception('Member ID required for update');
    await db.update('members', memberData, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteMember(String id) async {
    final db = await _db;
    await db.delete('members', where: 'id = ?', whereArgs: [id]);
  }

  Future<MemberRecord?> getMemberById(String id) async {
    final db = await _db;
    final rows = await db.query('members', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : MemberRecord.fromMap(rows.first);
  }

  Future<List<MemberRecord>> getAllMembers() async {
    final db = await _db;
    final rows = await db.query('members', orderBy: 'created_at ASC');
    return rows.map(MemberRecord.fromMap).toList();
  }

  Future<List<MemberRecord>> getMembersForFamily(String familyId) async {
    final db = await _db;
    final rows = await db.query('members',
        where: 'family_id = ?',
        whereArgs: [familyId],
        orderBy: 'created_at ASC');
    return rows.map(MemberRecord.fromMap).toList();
  }

  Future<String> insertMember(MemberRecord m) async {
    final db = await _db;
    final id = _generateId();
    final mapWithId = m.toMap();
    mapWithId['id'] = id;
    await db.insert('members', mapWithId);
    return id;
  }

  // ══ Medications ════════════════════════════════════════════════════════════

  Future<void> addMedication(Map<String, dynamic> medData) async {
    final db = await _db;
    await db.insert('medications', medData,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateMedication(Map<String, dynamic> medData) async {
    final db = await _db;
    final id = medData['id'] as String?;
    if (id == null) throw Exception('Medication ID required for update');
    await db.update('medications', medData, where: 'id = ?', whereArgs: [id]);
  }

  Future<MedicationRecord?> getMedicationById(String id) async {
    final db = await _db;
    final rows = await db.query('medications', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : MedicationRecord.fromMap(rows.first);
  }

  Future<List<MedicationRecord>> getMedicationsForMember(String memberId) async {
    final db = await _db;
    final rows = await db.query('medications',
        where: 'member_id = ? AND is_active = 1', whereArgs: [memberId]);
    return rows.map(MedicationRecord.fromMap).toList();
  }

  Future<void> deleteMedication(String id) async {
    final db = await _db;
    await db.delete('medications', where: 'id = ?', whereArgs: [id]);
  }

  /// Inserts a new medication, generating a stable ID if the record has none.
  /// Returns the saved [MedicationRecord] — always with a non-null [id].
  Future<MedicationRecord> insertMedication(MedicationRecord r) async {
    final db = await _db;
    final id = r.id ?? _generateId();
    final saved = r.copyWith(id: id);
    await db.insert('medications', saved.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    return saved;
  }

  Future<void> updateMedicationRecord(MedicationRecord r) async {
    if (r.id == null) throw Exception('Medication ID required for update');
    final db = await _db;
    final map = r.toMap();
    map['updated_at'] = DateTime.now().toIso8601String();
    await db.update('medications', map, where: 'id = ?', whereArgs: [r.id]);
  }

  Future<int> confirmMedication(String medicationId) async {
    final db = await _db;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return db.insert('med_confirmations', {
      'medication_id': medicationId,
      'date': today,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<bool> isMedicationConfirmedToday(String medicationId) async {
    final db = await _db;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final rows = await db.query('med_confirmations',
        where: 'medication_id = ? AND date = ?',
        whereArgs: [medicationId, today]);
    return rows.isNotEmpty;
  }

  // ══ Vital Signs ════════════════════════════════════════════════════════════

  Future<void> addVital(Map<String, dynamic> vitalData) async {
    final db = await _db;
    await db.insert('vital_signs', vitalData,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateVital(Map<String, dynamic> vitalData) async {
    final db = await _db;
    final id = vitalData['id'] as String?;
    if (id == null) throw Exception('Vital ID required for update');
    await db.update('vital_signs', vitalData, where: 'id = ?', whereArgs: [id]);
  }

  Future<VitalRecord?> getVitalById(String id) async {
    final db = await _db;
    final rows = await db.query('vital_signs', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : VitalRecord.fromMap(rows.first);
  }

  Future<int> insertVital(VitalRecord r) async {
    final db = await _db;
    return db.insert('vital_signs', r.toMap());
  }

  Future<List<VitalRecord>> getVitalsForMember(String memberId,
      {String? type, int limit = 30}) async {
    final db = await _db;
    final rows = await db.query(
      'vital_signs',
      where: type != null ? 'member_id = ? AND type = ?' : 'member_id = ?',
      whereArgs: type != null ? [memberId, type] : [memberId],
      orderBy: 'recorded_at DESC',
      limit: limit,
    );
    return rows.map(VitalRecord.fromMap).toList();
  }

  Future<VitalRecord?> getLatestVital(String memberId, String type) async {
    final vitals = await getVitalsForMember(memberId, type: type, limit: 1);
    return vitals.isEmpty ? null : vitals.first;
  }

  // ══ Ultrasounds ════════════════════════════════════════════════════════════

  Future<int> insertUltrasound(UltrasoundRecord r) async {
    final db = await _db;
    return db.insert('ultrasounds', r.toMap());
  }

  Future<List<UltrasoundRecord>> getUltrasoundsForMember(String memberId) async {
    final db = await _db;
    final rows = await db.query('ultrasounds',
        where: 'member_id = ?',
        whereArgs: [memberId],
        orderBy: 'created_at DESC');
    return rows.map(UltrasoundRecord.fromMap).toList();
  }

  Future<void> deleteUltrasound(int id) async {
    final db = await _db;
    await db.delete('ultrasounds', where: 'id = ?', whereArgs: [id]);
  }

  // ══ Appointments ═══════════════════════════════════════════════════════════

  Future<void> addAppointment(Map<String, dynamic> apptData) async {
    final db = await _db;
    await db.insert('appointments', apptData,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateAppointment(Map<String, dynamic> apptData) async {
    final db = await _db;
    final id = apptData['id'] as String?;
    if (id == null) throw Exception('Appointment ID required for update');
    await db.update('appointments', apptData, where: 'id = ?', whereArgs: [id]);
  }

  Future<AppointmentRecord?> getAppointmentById(String id) async {
    final db = await _db;
    final rows = await db.query('appointments', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : AppointmentRecord.fromMap(rows.first);
  }

  Future<int> insertAppointment(AppointmentRecord r) async {
    final db = await _db;
    return db.insert('appointments', r.toMap());
  }

  Future<List<AppointmentRecord>> getAppointmentsForMember(String memberId) async {
    final db = await _db;
    final rows = await db.query('appointments',
        where: 'member_id = ?',
        whereArgs: [memberId],
        orderBy: 'scheduled_at ASC');
    return rows.map(AppointmentRecord.fromMap).toList();
  }

  Future<List<AppointmentRecord>> getUpcomingAppointments() async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    final rows = await db.query('appointments',
        where: 'scheduled_at >= ?',
        whereArgs: [now],
        orderBy: 'scheduled_at ASC',
        limit: 20);
    return rows.map(AppointmentRecord.fromMap).toList();
  }

  Future<void> deleteAppointment(String id) async {
    final db = await _db;
    await db.delete('appointments', where: 'id = ?', whereArgs: [id]);
  }

  // ══ Documents ══════════════════════════════════════════════════════════════

  Future<void> addDocument(Map<String, dynamic> docData) async {
    final db = await _db;
    await db.insert('documents', docData,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateDocument(Map<String, dynamic> docData) async {
    final db = await _db;
    final id = docData['id'] as String?;
    if (id == null) throw Exception('Document ID required for update');
    await db.update('documents', docData, where: 'id = ?', whereArgs: [id]);
  }

  Future<DocumentRecord?> getDocumentById(String id) async {
    final db = await _db;
    final rows = await db.query('documents', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : DocumentRecord.fromMap(rows.first);
  }

  Future<int> insertDocument(DocumentRecord r) async {
    final db = await _db;
    return db.insert('documents', r.toMap());
  }

  Future<List<DocumentRecord>> getDocumentsForMember(String memberId) async {
    final db = await _db;
    final rows = await db.query('documents',
        where: 'member_id = ?',
        whereArgs: [memberId],
        orderBy: 'created_at DESC');
    return rows.map(DocumentRecord.fromMap).toList();
  }

  Future<void> deleteDocument(String id) async {
    final db = await _db;
    await db.delete('documents', where: 'id = ?', whereArgs: [id]);
  }

  // ══ Vaccinations ═══════════════════════════════════════════════════════════

  Future<void> addVaccination(Map<String, dynamic> vacData) async {
    final db = await _db;
    await db.insert('vaccinations', vacData,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateVaccination(Map<String, dynamic> vacData) async {
    final db = await _db;
    final id = vacData['id'] as String?;
    if (id == null) throw Exception('Vaccination ID required for update');
    await db.update('vaccinations', vacData, where: 'id = ?', whereArgs: [id]);
  }

  Future<VaccinationRecord?> getVaccinationById(String id) async {
    final db = await _db;
    final rows = await db.query('vaccinations', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : VaccinationRecord.fromMap(rows.first);
  }

  Future<int> insertVaccination(VaccinationRecord r) async {
    final db = await _db;
    return db.insert('vaccinations', r.toMap());
  }

  Future<List<VaccinationRecord>> getVaccinationsForMember(String memberId) async {
    final db = await _db;
    final rows = await db.query('vaccinations',
        where: 'member_id = ?', whereArgs: [memberId]);
    return rows.map(VaccinationRecord.fromMap).toList();
  }

  Future<int> markVaccinationReceived(String id,
      {required String clinicName, required String receivedAt}) async {
    final db = await _db;
    return db.update(
      'vaccinations',
      {'is_received': 1, 'clinic_name': clinicName, 'received_at': receivedAt},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ══ Prenatal Tests ═════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getPrenatalTestsForMember(
      String memberId) async {
    final db = await _db;
    final rows = await db.query('prenatal_tests',
        where: 'member_id = ?',
        whereArgs: [memberId],
        orderBy: 'trimester ASC, test_name ASC');
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<void> completePrenatalTest(String testId) async {
    final db = await _db;
    await db.update(
      'prenatal_tests',
      {'is_completed': 1, 'completed_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [testId],
    );
  }

  Future<void> insertPrenatalTest(Map<String, dynamic> testData) async {
    final db = await _db;
    await db.insert('prenatal_tests', testData,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ══ Calendar ═══════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getCalendarEventsForFamily(
      String familyId) async {
    final db = await _db;
    final all = <Map<String, dynamic>>[];

    final apptRows = await db.rawQuery('''
      SELECT a.id,
             a.family_id,
             a.member_id,
             m.name as member_name,
             m.profile_type as member_profile_type,
             'appointment' as event_type,
             a.title as event_title,
             a.scheduled_at as event_date,
             strftime('%H:%M', a.scheduled_at) as event_time,
             a.doctor,
             a.location,
             a.notes,
             a.id as source_id,
             a.created_at,
             a.updated_at
      FROM appointments a
      LEFT JOIN members m ON m.id = a.member_id
      WHERE a.family_id = ? AND COALESCE(a.show_on_family_calendar, 0) = 1
    ''', [familyId]);
    all.addAll(apptRows.map((r) => Map<String, dynamic>.from(r)));

    final medRows = await db.rawQuery('''
      SELECT med.id,
             med.family_id,
             med.member_id,
             m.name as member_name,
             m.profile_type as member_profile_type,
             CASE WHEN m.profile_type = 'child' THEN 'childMedication' ELSE 'medicationReminder' END as event_type,
             med.name || ' • ' || med.dose as event_title,
             datetime('now') as event_date,
             printf('%02d:%02d', med.reminder_hour, med.reminder_minute) as event_time,
             med.dose,
             med.frequency,
             med.time_of_day,
             med.reminder_hour,
             med.reminder_minute,
             med.id as source_id,
             med.created_at,
             med.updated_at
      FROM medications med
      LEFT JOIN members m ON m.id = med.member_id
      WHERE med.family_id = ?
        AND med.is_active = 1
        AND COALESCE(med.show_on_family_calendar, 0) = 1
    ''', [familyId]);
    all.addAll(medRows.map((r) => Map<String, dynamic>.from(r)));

    final vacRows = await db.rawQuery('''
      SELECT v.id,
             v.family_id,
             v.member_id,
             m.name as member_name,
             m.profile_type as member_profile_type,
             'vaccinationReminder' as event_type,
             v.vaccine_name as event_title,
             COALESCE(v.received_at, v.created_at) as event_date,
             NULL as event_time,
             v.clinic_name,
             v.received_at,
             v.is_received,
             v.id as source_id,
             v.created_at,
             v.updated_at
      FROM vaccinations v
      LEFT JOIN members m ON m.id = v.member_id
      WHERE v.family_id = ? AND COALESCE(v.show_on_family_calendar, 0) = 1
    ''', [familyId]);
    all.addAll(vacRows.map((r) => Map<String, dynamic>.from(r)));

    if (await _tableExists(db, 'family_reminders')) {
      final familyReminderRows = await db.rawQuery('''
        SELECT fr.id,
               fr.family_id,
               COALESCE(fr.member_id, '') as member_id,
               COALESCE(m.name, 'Family') as member_name,
               m.profile_type as member_profile_type,
               'familyReminder' as event_type,
               COALESCE(fr.title, fr.name, 'Family reminder') as event_title,
               COALESCE(fr.scheduled_at, fr.remind_at, fr.date, fr.created_at) as event_date,
               fr.id as source_id,
               fr.created_at,
               COALESCE(fr.updated_at, fr.created_at) as updated_at
        FROM family_reminders fr
        LEFT JOIN members m ON m.id = fr.member_id
        WHERE fr.family_id = ? AND COALESCE(fr.show_on_family_calendar, 0) = 1
      ''', [familyId]);
      all.addAll(familyReminderRows.map((r) => Map<String, dynamic>.from(r)));
    }

    all.sort((a, b) {
      final da = '${a['event_date'] ?? ''} ${a['event_time'] ?? ''}';
      final db2 = '${b['event_date'] ?? ''} ${b['event_time'] ?? ''}';
      return da.compareTo(db2);
    });

    return all;
  }

  Future<bool> _tableExists(Database db, String tableName) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [tableName],
    );
    return rows.isNotEmpty;
  }

  // ── Private helpers ────────────────────────────────────────────────────────
  String _generateId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = List<int>.generate(
        8, (_) => DateTime.now().microsecond % 256);
    return '$timestamp${random.map((e) => e.toRadixString(16).padLeft(2, '0')).join()}';
  }
}