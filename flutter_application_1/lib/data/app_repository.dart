import 'package:sqflite/sqflite.dart';
import 'database_provider.dart';

// ─── Lightweight data models (DB ↔ Dart) ─────────────────────────────────────

class MemberRecord {
  final String? id;
  final String? familyId;
  final String name;
  final int age;
  final String profileType;
  final String? userId;
  final String createdAt;
  final String updatedAt;

  const MemberRecord({
    this.id,
    this.familyId,
    required this.name,
    required this.age,
    required this.profileType,
    this.userId,
    this.createdAt = '',
    this.updatedAt = '',
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    if (familyId != null) 'family_id': familyId,
    'name': name,
    'age': age,
    'profile_type': profileType,
    if (userId != null) 'user_id': userId,
  };

  factory MemberRecord.fromMap(Map<String, dynamic> m) => MemberRecord(
    id: m['id'] as String?,
    familyId: m['family_id'] as String?,
    name: m['name'] as String,
    age: m['age'] as int,
    profileType: m['profile_type'] as String,
    userId: m['user_id'] as String?,
    createdAt: m['created_at'] as String? ?? '',
    updatedAt: m['updated_at'] as String? ?? '',
  );
}

class MedicationRecord {
  final String? id;
  final String? familyId;
  final String memberId;
  final String name;
  final String dose;
  final String frequency;
  final String timeOfDay;
  final bool isActive;
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
    this.isActive = true,
    this.createdAt = '',
    this.updatedAt = '',
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    if (familyId != null) 'family_id': familyId,
    'member_id': memberId,
    'name': name,
    'dose': dose,
    'frequency': frequency,
    'time_of_day': timeOfDay,
    'is_active': isActive ? 1 : 0,
  };

  factory MedicationRecord.fromMap(Map<String, dynamic> m) => MedicationRecord(
    id: m['id'] as String?,
    familyId: m['family_id'] as String?,
    memberId: m['member_id'] as String,
    name: m['name'] as String,
    dose: m['dose'] as String,
    frequency: m['frequency'] as String,
    timeOfDay: m['time_of_day'] as String,
    isActive: (m['is_active'] as int) == 1,
    createdAt: m['created_at'] as String? ?? '',
    updatedAt: m['updated_at'] as String? ?? '',
  );
}

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
    if (id != null) 'id': id,
    if (familyId != null) 'family_id': familyId,
    'member_id': memberId,
    'type': type,
    'value': value,
    'unit': unit,
  };

  factory VitalRecord.fromMap(Map<String, dynamic> m) => VitalRecord(
    id: m['id'] as String?,
    familyId: m['family_id'] as String?,
    memberId: m['member_id'] as String,
    type: m['type'] as String,
    value: (m['value'] as num).toDouble(),
    unit: m['unit'] as String,
    recordedAt: m['recorded_at'] as String? ?? '',
  );
}

class AppointmentRecord {
  final String? id;
  final String? familyId;
  final String memberId;
  final String title;
  final String? doctor;
  final String? location;
  final String scheduledAt;
  final String? notes;
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
    this.createdAt = '',
    this.updatedAt = '',
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    if (familyId != null) 'family_id': familyId,
    'member_id': memberId,
    'title': title,
    'doctor': doctor,
    'location': location,
    'scheduled_at': scheduledAt,
    'notes': notes,
  };

  factory AppointmentRecord.fromMap(Map<String, dynamic> m) =>
      AppointmentRecord(
        id: m['id'] as String?,
        familyId: m['family_id'] as String?,
        memberId: m['member_id'] as String,
        title: m['title'] as String,
        doctor: m['doctor'] as String?,
        location: m['location'] as String?,
        scheduledAt: m['scheduled_at'] as String,
        notes: m['notes'] as String?,
        createdAt: m['created_at'] as String? ?? '',
        updatedAt: m['updated_at'] as String? ?? '',
      );
}

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
    if (id != null) 'id': id,
    if (familyId != null) 'family_id': familyId,
    'member_id': memberId,
    'title': title,
    'file_path': filePath,
    'doc_type': docType,
  };

  factory DocumentRecord.fromMap(Map<String, dynamic> m) => DocumentRecord(
    id: m['id'] as String?,
    familyId: m['family_id'] as String?,
    memberId: m['member_id'] as String,
    title: m['title'] as String,
    filePath: m['file_path'] as String,
    docType: m['doc_type'] as String,
    createdAt: m['created_at'] as String? ?? '',
    updatedAt: m['updated_at'] as String? ?? '',
  );
}

class VaccinationRecord {
  final String? id;
  final String? familyId;
  final String memberId;
  final String vaccineName;
  final String? clinicName;
  final String? receivedAt;
  final bool isReceived;
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
    this.createdAt = '',
    this.updatedAt = '',
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    if (familyId != null) 'family_id': familyId,
    'member_id': memberId,
    'vaccine_name': vaccineName,
    'clinic_name': clinicName,
    'received_at': receivedAt,
    'is_received': isReceived ? 1 : 0,
  };

  factory VaccinationRecord.fromMap(Map<String, dynamic> m) =>
      VaccinationRecord(
        id: m['id'] as String?,
        familyId: m['family_id'] as String?,
        memberId: m['member_id'] as String,
        vaccineName: m['vaccine_name'] as String,
        clinicName: m['clinic_name'] as String?,
        receivedAt: m['received_at'] as String?,
        isReceived: (m['is_received'] as int) == 1,
        createdAt: m['created_at'] as String? ?? '',
        updatedAt: m['updated_at'] as String? ?? '',
      );
}

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
        id: m['id'] as int?,
        familyId: m['family_id'] as String,
        memberId: m['member_id'].toString(),
        monthLabel: m['month_label'] as String,
        sessionType: m['session_type'] as String,
        date: m['date'] as String,
        doctor: m['doctor'] as String,
        notes: m['notes'] as String,
        createdAt: m['created_at'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'family_id': familyId,
        'member_id': memberId,
        'month_label': monthLabel,
        'session_type': sessionType,
        'date': date,
        'doctor': doctor,
        'notes': notes,
      };
}

// ─── Repository ───────────────────────────────────────────────────────────────

/// Single access point for all DB reads and writes.
class AppRepository {
  AppRepository._();
  static final AppRepository instance = AppRepository._();

  factory AppRepository() => instance;

  Future<Database> get _db => DatabaseProvider.instance.database;

  // ══ Members (Generic map-based methods for Firestore sync) ══════════════════

  /// Add a member using a map (from Firestore).
  Future<void> addMember(Map<String, dynamic> memberData) async {
    final db = await _db;
    await db.insert('members', memberData,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Update a member using a map (from Firestore).
  Future<void> updateMember(Map<String, dynamic> memberData) async {
    final db = await _db;
    final id = memberData['id'] as String?;
    if (id == null) throw Exception('Member ID required for update');
    await db.update('members', memberData, where: 'id = ?', whereArgs: [id]);
  }

  /// Delete a member by ID.
  Future<void> deleteMember(String id) async {
    final db = await _db;
    await db.delete('members', where: 'id = ?', whereArgs: [id]);
  }

  /// Get member by ID.
  Future<MemberRecord?> getMemberById(String id) async {
    final db = await _db;
    final rows = await db.query('members', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : MemberRecord.fromMap(rows.first);
  }

  /// Get all members (legacy, not filtered by family).
  Future<List<MemberRecord>> getAllMembers() async {
    final db = await _db;
    final rows = await db.query('members', orderBy: 'created_at ASC');
    return rows.map(MemberRecord.fromMap).toList();
  }

  /// Get all members for a family.
  Future<List<MemberRecord>> getMembersForFamily(String familyId) async {
    final db = await _db;
    final rows = await db.query('members',
        where: 'family_id = ?',
        whereArgs: [familyId],
        orderBy: 'created_at ASC');
    return rows.map(MemberRecord.fromMap).toList();
  }

  // ══ Medications ════════════════════════════════════════════════════════════

  /// Add a medication using a map (from Firestore).
  Future<void> addMedication(Map<String, dynamic> medData) async {
    final db = await _db;
    await db.insert('medications', medData,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Update a medication using a map.
  Future<void> updateMedication(Map<String, dynamic> medData) async {
    final db = await _db;
    final id = medData['id'] as String?;
    if (id == null) throw Exception('Medication ID required for update');
    await db.update('medications', medData, where: 'id = ?', whereArgs: [id]);
  }

  /// Get medication by ID.
  Future<MedicationRecord?> getMedicationById(String id) async {
    final db = await _db;
    final rows =
        await db.query('medications', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : MedicationRecord.fromMap(rows.first);
  }

  /// Get medications for a member.
  Future<List<MedicationRecord>> getMedicationsForMember(String memberId) async {
    final db = await _db;
    final rows = await db.query('medications',
        where: 'member_id = ? AND is_active = 1',
        whereArgs: [memberId]);
    return rows.map(MedicationRecord.fromMap).toList();
  }

  /// Delete a medication.
  Future<void> deleteMedication(String id) async {
    final db = await _db;
    await db.delete('medications', where: 'id = ?', whereArgs: [id]);
  }

  /// Insert a member using legacy Record object (returns generated String ID).
  Future<String> insertMember(MemberRecord m) async {
    final db = await _db;
    final id = _generateId(); // Generate UUID-like ID
    final mapWithId = m.toMap();
    mapWithId['id'] = id;
    await db.insert('members', mapWithId);
    return id;
  }

  /// Insert a medication using legacy Record object.
  Future<int> insertMedication(MedicationRecord r) async {
    final db = await _db;
    return db.insert('medications', r.toMap());
  }

  /// Update a medication using legacy Record object.
  Future<int> updateMedicationRecord(MedicationRecord r) async {
    final db = await _db;
    return db.update('medications', r.toMap(),
        where: 'id = ?', whereArgs: [r.id]);
  }

  // Confirm today's dose for a medication
  Future<int> confirmMedication(String medicationId) async {
    final db = await _db;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return db.insert('med_confirmations', {
      'medication_id': medicationId,
      'date': today,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Check if a medication was confirmed today
  Future<bool> isMedicationConfirmedToday(String medicationId) async {
    final db = await _db;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final rows = await db.query('med_confirmations',
        where: 'medication_id = ? AND date = ?',
        whereArgs: [medicationId, today]);
    return rows.isNotEmpty;
  }

  // ══ Vital Signs ════════════════════════════════════════════════════════════

  /// Add a vital sign using a map (from Firestore).
  Future<void> addVital(Map<String, dynamic> vitalData) async {
    final db = await _db;
    await db.insert('vital_signs', vitalData,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Update a vital sign using a map.
  Future<void> updateVital(Map<String, dynamic> vitalData) async {
    final db = await _db;
    final id = vitalData['id'] as String?;
    if (id == null) throw Exception('Vital ID required for update');
    await db.update('vital_signs', vitalData, where: 'id = ?', whereArgs: [id]);
  }

  /// Get vital by ID.
  Future<VitalRecord?> getVitalById(String id) async {
    final db = await _db;
    final rows = await db.query('vital_signs', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : VitalRecord.fromMap(rows.first);
  }

  /// Insert a vital using legacy Record object.
  Future<int> insertVital(VitalRecord r) async {
    final db = await _db;
    return db.insert('vital_signs', r.toMap());
  }

  /// Get vitals for a member.
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

  /// Get latest vital for a member by type.
  Future<VitalRecord?> getLatestVital(String memberId, String type) async {
    final vitals =
        await getVitalsForMember(memberId, type: type, limit: 1);
    return vitals.isEmpty ? null : vitals.first;
  }
// ══ Ultrasounds ════════════════════════════════════════════════════════════

  /// Insert an ultrasound record.
  Future<int> insertUltrasound(UltrasoundRecord r) async {
    final db = await _db;
    return db.insert('ultrasounds', r.toMap());
  }

  /// Get ultrasound records for a member.
  Future<List<UltrasoundRecord>> getUltrasoundsForMember(String memberId) async {
    final db = await _db;
    final rows = await db.query(
      'ultrasounds',
      where: 'member_id = ?',
      whereArgs: [memberId],
      orderBy: 'created_at DESC',
    );
    return rows.map(UltrasoundRecord.fromMap).toList();
  }

  /// Delete an ultrasound record.
  Future<void> deleteUltrasound(int id) async {
    final db = await _db;
    await db.delete('ultrasounds', where: 'id = ?', whereArgs: [id]);
  }
  // ══ Appointments ═══════════════════════════════════════════════════════════

  /// Add an appointment using a map (from Firestore).
  Future<void> addAppointment(Map<String, dynamic> apptData) async {
    final db = await _db;
    await db.insert('appointments', apptData,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Update an appointment using a map.
  Future<void> updateAppointment(Map<String, dynamic> apptData) async {
    final db = await _db;
    final id = apptData['id'] as String?;
    if (id == null) throw Exception('Appointment ID required for update');
    await db.update('appointments', apptData, where: 'id = ?', whereArgs: [id]);
  }

  /// Get appointment by ID.
  Future<AppointmentRecord?> getAppointmentById(String id) async {
    final db = await _db;
    final rows =
        await db.query('appointments', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : AppointmentRecord.fromMap(rows.first);
  }

  /// Insert an appointment using legacy Record object.
  Future<int> insertAppointment(AppointmentRecord r) async {
    final db = await _db;
    return db.insert('appointments', r.toMap());
  }

  /// Get appointments for a member.
  Future<List<AppointmentRecord>> getAppointmentsForMember(String memberId) async {
    final db = await _db;
    final rows = await db.query('appointments',
        where: 'member_id = ?',
        whereArgs: [memberId],
        orderBy: 'scheduled_at ASC');
    return rows.map(AppointmentRecord.fromMap).toList();
  }

  /// Get upcoming appointments.
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

  /// Delete an appointment.
  Future<void> deleteAppointment(String id) async {
    final db = await _db;
    await db.delete('appointments', where: 'id = ?', whereArgs: [id]);
  }

  // ══ Documents ══════════════════════════════════════════════════════════════

  /// Add a document using a map (from Firestore).
  Future<void> addDocument(Map<String, dynamic> docData) async {
    final db = await _db;
    await db.insert('documents', docData,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Update a document using a map.
  Future<void> updateDocument(Map<String, dynamic> docData) async {
    final db = await _db;
    final id = docData['id'] as String?;
    if (id == null) throw Exception('Document ID required for update');
    await db.update('documents', docData, where: 'id = ?', whereArgs: [id]);
  }

  /// Get document by ID.
  Future<DocumentRecord?> getDocumentById(String id) async {
    final db = await _db;
    final rows =
        await db.query('documents', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : DocumentRecord.fromMap(rows.first);
  }

  /// Insert a document using legacy Record object.
  Future<int> insertDocument(DocumentRecord r) async {
    final db = await _db;
    return db.insert('documents', r.toMap());
  }

  /// Get documents for a member.
  Future<List<DocumentRecord>> getDocumentsForMember(String memberId) async {
    final db = await _db;
    final rows = await db.query('documents',
        where: 'member_id = ?',
        whereArgs: [memberId],
        orderBy: 'created_at DESC');
    return rows.map(DocumentRecord.fromMap).toList();
  }

  /// Delete a document.
  Future<void> deleteDocument(String id) async {
    final db = await _db;
    await db.delete('documents', where: 'id = ?', whereArgs: [id]);
  }

  // ══ Vaccinations ═══════════════════════════════════════════════════════════

  /// Add a vaccination using a map (from Firestore).
  Future<void> addVaccination(Map<String, dynamic> vacData) async {
    final db = await _db;
    await db.insert('vaccinations', vacData,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Update a vaccination using a map.
  Future<void> updateVaccination(Map<String, dynamic> vacData) async {
    final db = await _db;
    final id = vacData['id'] as String?;
    if (id == null) throw Exception('Vaccination ID required for update');
    await db.update('vaccinations', vacData, where: 'id = ?', whereArgs: [id]);
  }

  /// Get vaccination by ID.
  Future<VaccinationRecord?> getVaccinationById(String id) async {
    final db = await _db;
    final rows =
        await db.query('vaccinations', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : VaccinationRecord.fromMap(rows.first);
  }

  /// Insert a vaccination using legacy Record object.
  Future<int> insertVaccination(VaccinationRecord r) async {
    final db = await _db;
    return db.insert('vaccinations', r.toMap());
  }

  /// Get vaccinations for a member.
  Future<List<VaccinationRecord>> getVaccinationsForMember(String memberId) async {
    final db = await _db;
    final rows = await db.query('vaccinations',
        where: 'member_id = ?',
        whereArgs: [memberId]);
    return rows.map(VaccinationRecord.fromMap).toList();
  }

  /// Mark a vaccination as received.
  Future<int> markVaccinationReceived(String id,
      {required String clinicName, required String receivedAt}) async {
    final db = await _db;
    return db.update(
      'vaccinations',
      {
        'is_received': 1,
        'clinic_name': clinicName,
        'received_at': receivedAt
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ══ Prenatal Tests ═════════════════════════════════════════════════════════

  /// Get all prenatal tests for a member.
  Future<List<Map<String, dynamic>>> getPrenatalTestsForMember(
      String memberId) async {
    final db = await _db;
    final rows = await db.query(
      'prenatal_tests',
      where: 'member_id = ?',
      whereArgs: [memberId],
      orderBy: 'trimester ASC, test_name ASC',
    );
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  /// Mark a prenatal test as completed.
  Future<void> completePrenatalTest(String testId) async {
    final db = await _db;
    await db.update(
      'prenatal_tests',
      {'is_completed': 1, 'completed_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [testId],
    );
  }

  /// Insert a prenatal test record.
  Future<void> insertPrenatalTest(Map<String, dynamic> testData) async {
    final db = await _db;
    await db.insert('prenatal_tests', testData,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }
  // ══ Calendar Events ════════════════════════════════════════════════════════

  /// Get all health events (appointments + vaccinations) for a family,
  /// aggregated into a unified list for the shared calendar.
  Future<List<Map<String, dynamic>>> getCalendarEventsForFamily(
      String familyId) async {
    final db = await _db;

    // Fetch appointments
    final apptRows = await db.rawQuery('''
      SELECT a.id, a.member_id, m.name as member_name,
             a.title, a.scheduled_at as event_date,
             a.doctor, a.notes, 'appointment' as event_type
      FROM appointments a
      LEFT JOIN members m ON m.id = a.member_id
      WHERE m.family_id = ?
      ORDER BY a.scheduled_at ASC
    ''', [familyId]);

    // Fetch upcoming vaccinations not yet received
    final vacRows = await db.rawQuery('''
      SELECT v.id, v.member_id, m.name as member_name,
             v.vaccine_name as title, v.due_date as event_date,
             NULL as doctor, NULL as notes, 'vaccination' as event_type
      FROM vaccinations v
      LEFT JOIN members m ON m.id = v.member_id
      WHERE m.family_id = ? AND v.is_received = 0
      ORDER BY v.due_date ASC
    ''', [familyId]);

    final all = [
      ...apptRows.map((r) => Map<String, dynamic>.from(r)),
      ...vacRows.map((r) => Map<String, dynamic>.from(r)),
    ];

    // Sort combined list by event_date
    all.sort((a, b) {
      final da = a['event_date'] as String? ?? '';
      final db2 = b['event_date'] as String? ?? '';
      return da.compareTo(db2);
    });

    return all;
  }

  // ── Helper Methods ─────────────────────────────────────────────────────────

  /// Generate UUID-like string ID (compatible with Firestore format).
  String _generateId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = List<int>.generate(8, (i) => DateTime.now().microsecond % 256);
    return '$timestamp${random.map((e) => e.toRadixString(16).padLeft(2, '0')).join()}';
  }
}