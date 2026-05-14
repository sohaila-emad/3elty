import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite/sqflite.dart';

import '../services/remote_auth_service.dart';
import 'database_provider.dart';

// ─── Helpers ────────────────────────────────────────────────────────────────
int _boolToInt(bool value) => value ? 1 : 0;

bool _readBool(dynamic value, {bool fallback = false}) {
  if (value == null) return fallback;
  if (value is bool) return value;
  if (value is int) return value == 1;
  if (value is num) return value.toInt() == 1;
  if (value is String) {
    final v = value.toLowerCase().trim();
    return v == 'true' || v == '1' || v == 'yes';
  }
  return fallback;
}

String? _readDateString(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate().toIso8601String();
  if (value is DateTime) return value.toIso8601String();
  return value.toString();
}

// ─── MemberRecord ───────────────────────────────────────────────────────────
class MemberRecord {
  final String? id;
  final String? familyId;
  final String name;
  final int age;
  final String profileType;
  final String? userId;
  final String? phone;
  final String createdAt;
  final String updatedAt;

  const MemberRecord({
    this.id,
    this.familyId,
    required this.name,
    required this.age,
    required this.profileType,
    this.userId,
    this.phone,
    this.createdAt = '',
    this.updatedAt = '',
  });

  MemberRecord copyWith({
    String? id,
    String? familyId,
    String? name,
    int? age,
    String? profileType,
    String? userId,
    String? phone,
    String? createdAt,
    String? updatedAt,
  }) => MemberRecord(
        id: id ?? this.id,
        familyId: familyId ?? this.familyId,
        name: name ?? this.name,
        age: age ?? this.age,
        profileType: profileType ?? this.profileType,
        userId: userId ?? this.userId,
        phone: phone ?? this.phone,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        if (familyId != null) 'family_id': familyId,
        'name': name,
        'age': age,
        'profile_type': profileType,
        'phone': phone,
        'user_id': userId,
        if (createdAt.isNotEmpty) 'created_at': createdAt,
        if (updatedAt.isNotEmpty) 'updated_at': updatedAt,
      };

  factory MemberRecord.fromMap(Map<String, dynamic> m) => MemberRecord(
        id: m['id'] as String?,
        familyId: m['family_id'] as String?,
        name: (m['name'] ?? '') as String,
        age: (m['age'] as num?)?.toInt() ?? 0,
        profileType: (m['profile_type'] ?? 'adult') as String,
        userId: m['user_id'] as String?,
        phone: m['phone'] as String?,
        createdAt: _readDateString(m['created_at']) ?? '',
        updatedAt: _readDateString(m['updated_at']) ?? '',
      );
}

// ─── MedicationRecord ───────────────────────────────────────────────────────
class MedicationRecord {
  final String? id;
  final String? familyId;
  final String memberId;
  final String name;
  final String dose;
  final String frequency;
  final String timeOfDay;
  final int reminderHour;
  final int reminderMinute;
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
    this.showOnFamilyCalendar = true,
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
        id: id ?? this.id,
        familyId: familyId ?? this.familyId,
        memberId: memberId ?? this.memberId,
        name: name ?? this.name,
        dose: dose ?? this.dose,
        frequency: frequency ?? this.frequency,
        timeOfDay: timeOfDay ?? this.timeOfDay,
        reminderHour: reminderHour ?? this.reminderHour,
        reminderMinute: reminderMinute ?? this.reminderMinute,
        isActive: isActive ?? this.isActive,
        showOnFamilyCalendar:
            showOnFamilyCalendar ?? this.showOnFamilyCalendar,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        if (familyId != null) 'family_id': familyId,
        'member_id': memberId,
        'name': name,
        'dose': dose,
        'frequency': frequency,
        'time_of_day': timeOfDay,
        'reminder_hour': reminderHour,
        'reminder_minute': reminderMinute,
        'is_active': _boolToInt(isActive),
        'show_on_calendar': _boolToInt(showOnFamilyCalendar),
        if (createdAt.isNotEmpty) 'created_at': createdAt,
        if (updatedAt.isNotEmpty) 'updated_at': updatedAt,
      };

  factory MedicationRecord.fromMap(Map<String, dynamic> m) => MedicationRecord(
        id: m['id'] as String?,
        familyId: m['family_id'] as String?,
        memberId: (m['member_id'] ?? '') as String,
        name: (m['name'] ?? '') as String,
        dose: (m['dose'] ?? '') as String,
        frequency: (m['frequency'] ?? '') as String,
        timeOfDay: (m['time_of_day'] ?? '') as String,
        reminderHour: (m['reminder_hour'] as num?)?.toInt() ?? 8,
        reminderMinute: (m['reminder_minute'] as num?)?.toInt() ?? 0,
        isActive: _readBool(m['is_active'], fallback: true),
        showOnFamilyCalendar:
            _readBool(m['show_on_calendar'], fallback: true),
        createdAt: _readDateString(m['created_at']) ?? '',
        updatedAt: _readDateString(m['updated_at']) ?? '',
      );
}

// ─── VitalRecord ────────────────────────────────────────────────────────────
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

  VitalRecord copyWith({String? id, String? familyId, String? recordedAt}) =>
      VitalRecord(
        id: id ?? this.id,
        familyId: familyId ?? this.familyId,
        memberId: memberId,
        type: type,
        value: value,
        unit: unit,
        recordedAt: recordedAt ?? this.recordedAt,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        if (familyId != null) 'family_id': familyId,
        'member_id': memberId,
        'type': type,
        'value': value,
        'unit': unit,
        if (recordedAt.isNotEmpty) 'recorded_at': recordedAt,
      };

  factory VitalRecord.fromMap(Map<String, dynamic> m) => VitalRecord(
        id: m['id'] as String?,
        familyId: m['family_id'] as String?,
        memberId: (m['member_id'] ?? '') as String,
        type: (m['type'] ?? '') as String,
        value: (m['value'] as num?)?.toDouble() ?? 0,
        unit: (m['unit'] ?? '') as String,
        recordedAt: _readDateString(m['recorded_at']) ?? '',
      );
}

// ─── AppointmentRecord ──────────────────────────────────────────────────────
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
    this.showOnFamilyCalendar = true,
    this.createdAt = '',
    this.updatedAt = '',
  });

  AppointmentRecord copyWith({
    String? id,
    String? familyId,
    String? memberId,
    String? title,
    String? doctor,
    String? location,
    String? scheduledAt,
    String? notes,
    bool? showOnFamilyCalendar,
  }) => AppointmentRecord(
        id: id ?? this.id,
        familyId: familyId ?? this.familyId,
        memberId: memberId ?? this.memberId,
        title: title ?? this.title,
        doctor: doctor ?? this.doctor,
        location: location ?? this.location,
        scheduledAt: scheduledAt ?? this.scheduledAt,
        notes: notes ?? this.notes,
        showOnFamilyCalendar:
            showOnFamilyCalendar ?? this.showOnFamilyCalendar,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        if (familyId != null) 'family_id': familyId,
        'member_id': memberId,
        'title': title,
        'doctor': doctor,
        'location': location,
        'scheduled_at': scheduledAt,
        'notes': notes,
        'show_on_calendar': _boolToInt(showOnFamilyCalendar),
        if (createdAt.isNotEmpty) 'created_at': createdAt,
        if (updatedAt.isNotEmpty) 'updated_at': updatedAt,
      };

  factory AppointmentRecord.fromMap(Map<String, dynamic> m) =>
      AppointmentRecord(
        id: m['id'] as String?,
        familyId: m['family_id'] as String?,
        memberId: (m['member_id'] ?? '') as String,
        title: (m['title'] ?? '') as String,
        doctor: m['doctor'] as String?,
        location: m['location'] as String?,
        scheduledAt: (_readDateString(m['scheduled_at']) ??
            _readDateString(m['date']) ??
            ''),
        notes: m['notes'] as String?,
        showOnFamilyCalendar:
            _readBool(m['show_on_calendar'], fallback: true),
        createdAt: _readDateString(m['created_at']) ?? '',
        updatedAt: _readDateString(m['updated_at']) ?? '',
      );
}

// ─── DocumentRecord ─────────────────────────────────────────────────────────
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

  DocumentRecord copyWith({String? id, String? familyId}) => DocumentRecord(
        id: id ?? this.id,
        familyId: familyId ?? this.familyId,
        memberId: memberId,
        title: title,
        filePath: filePath,
        docType: docType,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        if (familyId != null) 'family_id': familyId,
        'member_id': memberId,
        'title': title,
        'file_path': filePath,
        'doc_type': docType,
        if (createdAt.isNotEmpty) 'created_at': createdAt,
        if (updatedAt.isNotEmpty) 'updated_at': updatedAt,
      };

  factory DocumentRecord.fromMap(Map<String, dynamic> m) => DocumentRecord(
        id: m['id'] as String?,
        familyId: m['family_id'] as String?,
        memberId: (m['member_id'] ?? '') as String,
        title: (m['title'] ?? '') as String,
        filePath: (m['file_path'] ?? m['file_url'] ?? '') as String,
        docType: (m['doc_type'] ?? m['type'] ?? 'document') as String,
        createdAt: _readDateString(m['created_at']) ?? '',
        updatedAt: _readDateString(m['updated_at']) ?? '',
      );
}

// ─── VaccinationRecord ──────────────────────────────────────────────────────
class VaccinationRecord {
  final String? id;
  final String? familyId;
  final String memberId;
  final String vaccineName;
  final String? clinicName;
  final String? receivedAt;
  final String? nextDue;
  final String? notes;
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
    this.nextDue,
    this.notes,
    this.isReceived = false,
    this.showOnFamilyCalendar = true,
    this.createdAt = '',
    this.updatedAt = '',
  });

  VaccinationRecord copyWith({
    String? id,
    String? familyId,
    bool? isReceived,
    String? receivedAt,
    String? clinicName,
  }) => VaccinationRecord(
        id: id ?? this.id,
        familyId: familyId ?? this.familyId,
        memberId: memberId,
        vaccineName: vaccineName,
        clinicName: clinicName ?? this.clinicName,
        receivedAt: receivedAt ?? this.receivedAt,
        nextDue: nextDue,
        notes: notes,
        isReceived: isReceived ?? this.isReceived,
        showOnFamilyCalendar: showOnFamilyCalendar,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        if (familyId != null) 'family_id': familyId,
        'member_id': memberId,
        'vaccine_name': vaccineName,
        'clinic_name': clinicName,
        'received_at': receivedAt,
        'date_given': receivedAt,
        'next_due': nextDue,
        'notes': notes,
        'is_received': _boolToInt(isReceived),
        'show_on_calendar': _boolToInt(showOnFamilyCalendar),
        if (createdAt.isNotEmpty) 'created_at': createdAt,
        if (updatedAt.isNotEmpty) 'updated_at': updatedAt,
      };

  factory VaccinationRecord.fromMap(Map<String, dynamic> m) => VaccinationRecord(
        id: m['id'] as String?,
        familyId: m['family_id'] as String?,
        memberId: (m['member_id'] ?? '') as String,
        vaccineName: (m['vaccine_name'] ?? '') as String,
        clinicName: m['clinic_name'] as String?,
        receivedAt: _readDateString(m['received_at']) ??
            _readDateString(m['date_given']),
        nextDue: _readDateString(m['next_due']),
        notes: m['notes'] as String?,
        isReceived: _readBool(m['is_received'], fallback: false),
        showOnFamilyCalendar:
            _readBool(m['show_on_calendar'], fallback: true),
        createdAt: _readDateString(m['created_at']) ?? '',
        updatedAt: _readDateString(m['updated_at']) ?? '',
      );
}

// ─── UltrasoundRecord ───────────────────────────────────────────────────────
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

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'family_id': familyId,
        'member_id': memberId,
        'month_label': monthLabel,
        'session_type': sessionType,
        'date': date,
        'doctor': doctor,
        'notes': notes,
        if (createdAt.isNotEmpty) 'created_at': createdAt,
      };

  factory UltrasoundRecord.fromMap(Map<String, dynamic> m) => UltrasoundRecord(
        id: m['id'] as int?,
        familyId: (m['family_id'] ?? '') as String,
        memberId: (m['member_id'] ?? '') as String,
        monthLabel: (m['month_label'] ?? '') as String,
        sessionType: (m['session_type'] ?? '') as String,
        date: (m['date'] ?? '') as String,
        doctor: (m['doctor'] ?? '') as String,
        notes: (m['notes'] ?? '') as String,
        createdAt: _readDateString(m['created_at']) ?? '',
      );
}

// ─── AppRepository ──────────────────────────────────────────────────────────
class AppRepository {
  AppRepository._();
  static final AppRepository instance = AppRepository._();
  factory AppRepository() => instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RemoteAuthService _authService = RemoteAuthService.instance;

  Future<Database> get _db => DatabaseProvider.instance.database;

  String _generateId() {
    final now = DateTime.now();
    return '${now.microsecondsSinceEpoch}';
  }

  Future<String?> _activeFamilyId() => _authService.familyId;

  Future<String> _requiredFamilyId(String? recordFamilyId) async {
    final id = recordFamilyId ?? await _activeFamilyId();
    if (id == null || id.isEmpty) {
      throw Exception('No active family session. Please log in again.');
    }
    return id;
  }

  Future<void> _localUpsert(String table, Map<String, dynamic> data) async {
    final db = await _db;
    await db.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _localUpdate(
      String table, String id, Map<String, dynamic> data) async {
    final db = await _db;
    await db.update(table, data, where: 'id = ?', whereArgs: [id]);
  }

  Map<String, dynamic> _cleanForLocal(Map<String, dynamic> data) {
    final result = <String, dynamic>{};
    data.forEach((key, value) {
      if (value is Timestamp) {
        result[key] = value.toDate().toIso8601String();
      } else if (value is DateTime) {
        result[key] = value.toIso8601String();
      } else if (value is bool) {
        result[key] = value ? 1 : 0;
      } else {
        result[key] = value;
      }
    });
    return result;
  }

  Future<void> _setFirestoreDoc(
    String collection,
    String id,
    Map<String, dynamic> data, {
    required bool isNew,
  }) async {
    final firestoreData = Map<String, dynamic>.from(data)..remove('id');
    firestoreData['updated_at'] = FieldValue.serverTimestamp();
    if (isNew) firestoreData['created_at'] = FieldValue.serverTimestamp();
    await _firestore
        .collection(collection)
        .doc(id)
        .set(firestoreData, SetOptions(merge: true));
  }

  // ══ Members ════════════════════════════════════════════════════════════════

  Future<void> addMember(Map<String, dynamic> memberData) async {
    await _localUpsert('members', _cleanForLocal(memberData));
  }

  Future<void> updateMember(Map<String, dynamic> memberData) async {
    final id = memberData['id'] as String?;
    if (id == null) throw Exception('Member ID required for update');
    await _localUpdate('members', id, _cleanForLocal(memberData));
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
    final rows = await db.query('members', orderBy: 'created_at DESC');
    return rows.map(MemberRecord.fromMap).toList();
  }

  Future<List<MemberRecord>> getMembersForFamily(String familyId) async {
    final db = await _db;
    final rows = await db.query('members',
        where: 'family_id = ?', whereArgs: [familyId], orderBy: 'created_at DESC');
    return rows.map(MemberRecord.fromMap).toList();
  }

  Future<String> insertMember(MemberRecord m) async {
    final id = m.id ?? _generateId();
    final familyId = await _requiredFamilyId(m.familyId);
    final saved = m.copyWith(id: id, familyId: familyId);
    await _localUpsert('members', saved.toMap());
    await _setFirestoreDoc('members', id, {
      'family_id': familyId,
      'name': saved.name,
      'age': saved.age,
      'profile_type': saved.profileType,
      'phone': saved.phone,
      'user_id': saved.userId,
    }, isNew: m.id == null);
    return id;
  }

  // ══ Medications ════════════════════════════════════════════════════════════

  Future<void> addMedication(Map<String, dynamic> medData) async {
    await _localUpsert('medications', _cleanForLocal(medData));
  }

  Future<void> updateMedication(Map<String, dynamic> medData) async {
    final id = medData['id'] as String?;
    if (id == null) throw Exception('Medication ID required for update');
    await _localUpdate('medications', id, _cleanForLocal(medData));
  }

  Future<MedicationRecord?> getMedicationById(String id) async {
    final db = await _db;
    final rows = await db.query('medications', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : MedicationRecord.fromMap(rows.first);
  }

  Future<List<MedicationRecord>> getMedicationsForMember(String memberId) async {
    final db = await _db;
    final rows = await db.query('medications',
        where: 'member_id = ? AND is_active = 1',
        whereArgs: [memberId],
        orderBy: 'created_at DESC');
    return rows.map(MedicationRecord.fromMap).toList();
  }

  Future<void> deleteMedication(String id) async {
    final db = await _db;
    await db.update('medications',
        {'is_active': 0, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?', whereArgs: [id]);
    await _firestore.collection('medications').doc(id).set({
      'is_active': false,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<MedicationRecord> insertMedication(MedicationRecord r) async {
    final id = r.id ?? _generateId();
    final familyId = await _requiredFamilyId(r.familyId);
    final saved = r.copyWith(id: id, familyId: familyId);
    await _localUpsert('medications', saved.toMap());
    await _setFirestoreDoc('medications', id, {
      'family_id': familyId,
      'member_id': saved.memberId,
      'name': saved.name,
      'dose': saved.dose,
      'frequency': saved.frequency,
      'time_of_day': saved.timeOfDay,
      'is_active': saved.isActive,
      'show_on_calendar': saved.showOnFamilyCalendar,
      // Kept in Firebase because the device needs to re-schedule local reminders after login/sync.
      'reminder_hour': saved.reminderHour,
      'reminder_minute': saved.reminderMinute,
    }, isNew: r.id == null);
    return saved;
  }

  Future<void> updateMedicationRecord(MedicationRecord r) async {
    if (r.id == null) throw Exception('Medication ID required for update');
    final familyId = await _requiredFamilyId(r.familyId);
    final saved = r.copyWith(familyId: familyId);
    final map = saved.toMap()..['updated_at'] = DateTime.now().toIso8601String();
    await _localUpdate('medications', r.id!, map);
    await _setFirestoreDoc('medications', r.id!, {
      'family_id': familyId,
      'member_id': saved.memberId,
      'name': saved.name,
      'dose': saved.dose,
      'frequency': saved.frequency,
      'time_of_day': saved.timeOfDay,
      'is_active': saved.isActive,
      'show_on_calendar': saved.showOnFamilyCalendar,
      'reminder_hour': saved.reminderHour,
      'reminder_minute': saved.reminderMinute,
    }, isNew: false);
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
    await _localUpsert('vital_signs', _cleanForLocal(vitalData));
  }

  Future<void> updateVital(Map<String, dynamic> vitalData) async {
    final id = vitalData['id'] as String?;
    if (id == null) throw Exception('Vital ID required for update');
    await _localUpdate('vital_signs', id, _cleanForLocal(vitalData));
  }

  Future<VitalRecord?> getVitalById(String id) async {
    final db = await _db;
    final rows = await db.query('vital_signs', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : VitalRecord.fromMap(rows.first);
  }

  Future<int> insertVital(VitalRecord r) async {
    final db = await _db;
    final id = r.id ?? _generateId();
    final familyId = await _requiredFamilyId(r.familyId);
    final recordedAt = r.recordedAt.isNotEmpty
        ? r.recordedAt
        : DateTime.now().toIso8601String();
    final saved = r.copyWith(id: id, familyId: familyId, recordedAt: recordedAt);
    final localId = await db.insert('vital_signs', saved.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    await _setFirestoreDoc('vital_signs', id, {
      'family_id': familyId,
      'member_id': saved.memberId,
      'type': saved.type,
      'value': saved.value,
      'unit': saved.unit,
      'recorded_at': saved.recordedAt,
    }, isNew: r.id == null);
    return localId;
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
    return db.insert('ultrasounds', r.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
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
    await _localUpsert('appointments', _cleanForLocal(_normalizeAppointmentMap(apptData)));
  }

  Future<void> updateAppointment(Map<String, dynamic> apptData) async {
    final id = apptData['id'] as String?;
    if (id == null || id.isEmpty) {
      throw Exception('Appointment ID required for update');
    }

    final normalized = _normalizeAppointmentMap(apptData);
    final localMap = _cleanForLocal(normalized);
    await _localUpdate('appointments', id, localMap);

    // Keep this legacy Map-based update Firebase-backed as well. Some screens
    // still call updateAppointment(record.toMap()), so updating only SQLite here
    // makes edits disappear after the next Firebase sync.
    final familyId = await _requiredFamilyId(localMap['family_id'] as String?);
    final record = AppointmentRecord.fromMap({
      ...localMap,
      'id': id,
      'family_id': familyId,
    });

    await _setFirestoreDoc('appointments', id, {
      'family_id': familyId,
      'member_id': record.memberId,
      'title': record.title,
      'date': record.scheduledAt,
      'doctor': record.doctor,
      'notes': record.notes,
      'show_on_calendar': record.showOnFamilyCalendar,
      'location': record.location,
    }, isNew: false);
  }

  Map<String, dynamic> _normalizeAppointmentMap(Map<String, dynamic> data) {
    final result = Map<String, dynamic>.from(data);
    result['scheduled_at'] = _readDateString(result['scheduled_at']) ??
        _readDateString(result['date']) ??
        DateTime.now().toIso8601String();
    result.remove('date');
    return result;
  }

  Future<AppointmentRecord?> getAppointmentById(String id) async {
    final db = await _db;
    final rows = await db.query('appointments', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : AppointmentRecord.fromMap(rows.first);
  }

  Future<int> insertAppointment(AppointmentRecord r) async {
    final db = await _db;
    final id = r.id ?? _generateId();
    final familyId = await _requiredFamilyId(r.familyId);
    final saved = r.copyWith(id: id, familyId: familyId);
    final localId = await db.insert('appointments', saved.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    await _setFirestoreDoc('appointments', id, {
      'family_id': familyId,
      'member_id': saved.memberId,
      'title': saved.title,
      'date': saved.scheduledAt,
      'doctor': saved.doctor,
      'notes': saved.notes,
      'show_on_calendar': saved.showOnFamilyCalendar,
      // Existing app field; safe extension for UI display.
      'location': saved.location,
    }, isNew: r.id == null);
    return localId;
  }

  Future<void> updateAppointmentRecord(AppointmentRecord r) async {
    if (r.id == null) throw Exception('Appointment ID required for update');
    final familyId = await _requiredFamilyId(r.familyId);
    final saved = r.copyWith(familyId: familyId);
    final map = saved.toMap()..['updated_at'] = DateTime.now().toIso8601String();
    await _localUpdate('appointments', r.id!, map);
    await _setFirestoreDoc('appointments', r.id!, {
      'family_id': familyId,
      'member_id': saved.memberId,
      'title': saved.title,
      'date': saved.scheduledAt,
      'doctor': saved.doctor,
      'notes': saved.notes,
      'show_on_calendar': saved.showOnFamilyCalendar,
      'location': saved.location,
    }, isNew: false);
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
    await _firestore.collection('appointments').doc(id).delete();
  }

  // ══ Documents ══════════════════════════════════════════════════════════════

  Future<void> addDocument(Map<String, dynamic> docData) async {
    await _localUpsert('documents', _cleanForLocal(_normalizeDocumentMap(docData)));
  }

  Future<void> updateDocument(Map<String, dynamic> docData) async {
    final id = docData['id'] as String?;
    if (id == null) throw Exception('Document ID required for update');
    await _localUpdate('documents', id, _cleanForLocal(_normalizeDocumentMap(docData)));
  }

  Map<String, dynamic> _normalizeDocumentMap(Map<String, dynamic> data) {
    final result = Map<String, dynamic>.from(data);
    result['file_path'] = result['file_path'] ?? result['file_url'] ?? '';
    result['doc_type'] = result['doc_type'] ?? result['type'] ?? 'document';
    result.remove('file_url');
    result.remove('type');
    return result;
  }

  Future<DocumentRecord?> getDocumentById(String id) async {
    final db = await _db;
    final rows = await db.query('documents', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : DocumentRecord.fromMap(rows.first);
  }

  Future<int> insertDocument(DocumentRecord r) async {
    final db = await _db;
    final id = r.id ?? _generateId();
    final familyId = await _requiredFamilyId(r.familyId);
    final saved = r.copyWith(id: id, familyId: familyId);
    final localId = await db.insert('documents', saved.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    await _setFirestoreDoc('documents', id, {
      'family_id': familyId,
      'member_id': saved.memberId,
      'title': saved.title,
      'type': saved.docType,
      'file_url': saved.filePath,
    }, isNew: r.id == null);
    return localId;
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
    await _firestore.collection('documents').doc(id).delete();
  }

  // ══ Vaccinations ═══════════════════════════════════════════════════════════

  Future<void> addVaccination(Map<String, dynamic> vacData) async {
    await _localUpsert('vaccinations', _cleanForLocal(_normalizeVaccinationMap(vacData)));
  }

  Future<void> updateVaccination(Map<String, dynamic> vacData) async {
    final id = vacData['id'] as String?;
    if (id == null) throw Exception('Vaccination ID required for update');
    await _localUpdate('vaccinations', id, _cleanForLocal(_normalizeVaccinationMap(vacData)));
  }

  Map<String, dynamic> _normalizeVaccinationMap(Map<String, dynamic> data) {
    final result = Map<String, dynamic>.from(data);
    result['received_at'] = _readDateString(result['received_at']) ??
        _readDateString(result['date_given']);
    result['is_received'] = result['is_received'] ?? (result['received_at'] != null ? 1 : 0);
    return result;
  }

  Future<VaccinationRecord?> getVaccinationById(String id) async {
    final db = await _db;
    final rows = await db.query('vaccinations', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : VaccinationRecord.fromMap(rows.first);
  }

  Future<int> insertVaccination(VaccinationRecord r) async {
    final db = await _db;
    final id = r.id ?? _generateId();
    final familyId = await _requiredFamilyId(r.familyId);
    final saved = r.copyWith(id: id, familyId: familyId);
    final localId = await db.insert('vaccinations', saved.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    await _setFirestoreDoc('vaccinations', id, {
      'family_id': familyId,
      'member_id': saved.memberId,
      'vaccine_name': saved.vaccineName,
      'date_given': saved.receivedAt,
      'next_due': saved.nextDue,
      'notes': saved.notes,
      'show_on_calendar': saved.showOnFamilyCalendar,
      'clinic_name': saved.clinicName,
      'is_received': saved.isReceived,
    }, isNew: r.id == null);
    return localId;
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
    final result = await db.update(
      'vaccinations',
      {
        'is_received': 1,
        'clinic_name': clinicName,
        'received_at': receivedAt,
        'date_given': receivedAt,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    await _firestore.collection('vaccinations').doc(id).set({
      'clinic_name': clinicName,
      'date_given': receivedAt,
      'is_received': true,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return result;
  }

  // ══ Prenatal Tests ═════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getPrenatalTestsForMember(String memberId) async {
    final db = await _db;
    final rows = await db.query('prenatal_tests',
        where: 'member_id = ?',
        whereArgs: [memberId],
        orderBy: 'trimester ASC, test_name ASC');
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<void> completePrenatalTest(String testId) async {
    final completedAt = DateTime.now().toIso8601String();
    final db = await _db;
    await db.update(
      'prenatal_tests',
      {'is_completed': 1, 'completed_at': completedAt},
      where: 'id = ?',
      whereArgs: [testId],
    );
    await _firestore.collection('prenatal_tests').doc(testId).set({
      'is_completed': true,
      'completed_at': completedAt,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> insertPrenatalTest(Map<String, dynamic> testData) async {
    final id = testData['id'] as String? ?? _generateId();
    final data = Map<String, dynamic>.from(testData)..['id'] = id;
    data['is_completed'] = _readBool(data['is_completed']) ? 1 : 0;
    await _localUpsert('prenatal_tests', _cleanForLocal(data));
  }

  Future<void> upsertPrenatalTestToFirebase(Map<String, dynamic> testData) async {
    final id = testData['id'] as String? ?? _generateId();
    final familyId = await _requiredFamilyId(testData['family_id'] as String?);
    await insertPrenatalTest({...testData, 'id': id, 'family_id': familyId});
    await _setFirestoreDoc('prenatal_tests', id, {
      'family_id': familyId,
      'member_id': testData['member_id'],
      'trimester': testData['trimester'],
      'test_name': testData['test_name'],
      'is_completed': _readBool(testData['is_completed']),
      'completed_at': testData['completed_at'],
    }, isNew: testData['id'] == null);
  }

  // ══ Calendar ═══════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getCalendarEventsForFamily(String familyId) async {
    final db = await _db;

    final apptRows = await db.rawQuery('''
      SELECT a.id, a.member_id, m.name AS member_name, m.profile_type AS member_profile_type,
             a.title, a.scheduled_at AS event_date,
             a.doctor, a.notes, 'appointment' AS event_type
      FROM appointments a
      LEFT JOIN members m ON m.id = a.member_id
      WHERE a.family_id = ? AND COALESCE(a.show_on_calendar, 1) = 1
    ''', [familyId]);

    final medRows = await db.rawQuery('''
      SELECT md.id, md.member_id, m.name AS member_name, m.profile_type AS member_profile_type,
             md.name AS title, md.time_of_day AS event_date,
             NULL AS doctor, md.dose AS notes, 'medication' AS event_type
      FROM medications md
      LEFT JOIN members m ON m.id = md.member_id
      WHERE md.family_id = ? AND md.is_active = 1 AND COALESCE(md.show_on_calendar, 1) = 1
    ''', [familyId]);

    final vacRows = await db.rawQuery('''
      SELECT v.id, v.member_id, m.name AS member_name, m.profile_type AS member_profile_type,
             v.vaccine_name AS title,
             COALESCE(v.next_due, v.received_at, v.date_given) AS event_date,
             NULL AS doctor, v.notes AS notes, 'vaccination' AS event_type
      FROM vaccinations v
      LEFT JOIN members m ON m.id = v.member_id
      WHERE v.family_id = ? AND COALESCE(v.show_on_calendar, 1) = 1
    ''', [familyId]);

    final all = [
      ...apptRows,
      ...medRows,
      ...vacRows,
    ].map((r) => Map<String, dynamic>.from(r)).toList();

    all.sort((a, b) {
      final da = a['event_date'] as String? ?? '';
      final db2 = b['event_date'] as String? ?? '';
      return da.compareTo(db2);
    });

    return all;
  }
}
