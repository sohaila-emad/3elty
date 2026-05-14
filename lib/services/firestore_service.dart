import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_1/data/app_repository.dart';
import 'package:flutter_application_1/services/permission_service.dart';
import 'package:flutter_application_1/services/remote_auth_service.dart';

/// Firestore service for Firebase-first family data.
///
/// Firestore is the source of truth. SQLite is refreshed from Firestore and used
/// as an offline/cache layer by the UI and local notification scheduling.
class FirestoreService {
  FirestoreService._();
  static final FirestoreService _instance = FirestoreService._();

  factory FirestoreService() => _instance;
  static FirestoreService get instance => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AppRepository _repository = AppRepository.instance;
  final RemoteAuthService _authService = RemoteAuthService.instance;
  final PermissionService _permissionService = PermissionService.instance;

  /// Sync all supported family data from Firestore to the local SQLite cache.
  Future<void> syncFamilyData() async {
    final familyId = await _authService.familyId;
    if (familyId == null) {
      throw Exception('No active family session');
    }

    await _syncMembers(familyId);
    await _syncMedications(familyId);
    await _syncAppointments(familyId);
    await _syncDocuments(familyId);
    await _syncVaccinations(familyId);
    await _syncVitalSigns(familyId);
    await _syncPrenatalTests(familyId);
  }

  Future<void> _syncMembers(String familyId) async {
    final snapshot = await _firestore
        .collection('members')
        .where('family_id', isEqualTo: familyId)
        .get();

    for (final doc in snapshot.docs) {
      final data = _sanitizeData(doc.data());
      data['id'] = doc.id;
      data['family_id'] = familyId;
      await _repository.addMember(data);
    }
  }

  Future<void> _syncMedications(String familyId) async {
    final snapshot = await _firestore
        .collection('medications')
        .where('family_id', isEqualTo: familyId)
        .get();

    for (final doc in snapshot.docs) {
      final data = _sanitizeData(doc.data());
      data['id'] = doc.id;
      data['family_id'] = familyId;
      data['is_active'] = _boolToInt(data['is_active'], fallback: true);
      data['show_on_calendar'] =
          _boolToInt(data['show_on_calendar'], fallback: true);
      await _repository.addMedication(data);
    }
  }

  Future<void> _syncAppointments(String familyId) async {
    final snapshot = await _firestore
        .collection('appointments')
        .where('family_id', isEqualTo: familyId)
        .get();

    for (final doc in snapshot.docs) {
      final data = _sanitizeData(doc.data());
      data['id'] = doc.id;
      data['family_id'] = familyId;
      data['scheduled_at'] = data['scheduled_at'] ?? data['date'];
      data['show_on_calendar'] =
          _boolToInt(data['show_on_calendar'], fallback: true);
      await _repository.addAppointment(data);
    }
  }

  Future<void> _syncDocuments(String familyId) async {
    final snapshot = await _firestore
        .collection('documents')
        .where('family_id', isEqualTo: familyId)
        .get();

    for (final doc in snapshot.docs) {
      final data = _sanitizeData(doc.data());
      data['id'] = doc.id;
      data['family_id'] = familyId;
      data['file_path'] = data['file_path'] ?? data['file_url'] ?? '';
      data['doc_type'] = data['doc_type'] ?? data['type'] ?? 'document';
      await _repository.addDocument(data);
    }
  }

  Future<void> _syncVaccinations(String familyId) async {
    final snapshot = await _firestore
        .collection('vaccinations')
        .where('family_id', isEqualTo: familyId)
        .get();

    for (final doc in snapshot.docs) {
      final data = _sanitizeData(doc.data());
      data['id'] = doc.id;
      data['family_id'] = familyId;
      data['received_at'] = data['received_at'] ?? data['date_given'];
      data['is_received'] = _boolToInt(data['is_received'], fallback: data['received_at'] != null);
      data['show_on_calendar'] =
          _boolToInt(data['show_on_calendar'], fallback: true);
      await _repository.addVaccination(data);
    }
  }

  Future<void> _syncVitalSigns(String familyId) async {
    final snapshot = await _firestore
        .collection('vital_signs')
        .where('family_id', isEqualTo: familyId)
        .get();

    for (final doc in snapshot.docs) {
      final data = _sanitizeData(doc.data());
      data['id'] = doc.id;
      data['family_id'] = familyId;
      await _repository.addVital(data);
    }
  }

  Future<void> _syncPrenatalTests(String familyId) async {
    final snapshot = await _firestore
        .collection('prenatal_tests')
        .where('family_id', isEqualTo: familyId)
        .get();

    for (final doc in snapshot.docs) {
      final data = _sanitizeData(doc.data());
      data['id'] = doc.id;
      data['family_id'] = familyId;
      data['is_completed'] = _boolToInt(data['is_completed'], fallback: false);
      await _repository.insertPrenatalTest(data);
    }
  }

  /// Seed default prenatal tests for a newly added pregnant member.
  Future<void> seedPrenatalTestsForMember({
    required String memberId,
    required String familyId,
  }) async {
    const defaultTests = [
      {'trimester': 1, 'test_name': 'Complete Blood Count (CBC)'},
      {'trimester': 1, 'test_name': 'Blood Type & Rh Factor'},
      {'trimester': 1, 'test_name': 'Urine Analysis'},
      {'trimester': 1, 'test_name': 'Fasting Blood Sugar'},
      {'trimester': 1, 'test_name': 'First-Trimester Ultrasound (NT Scan)'},
      {'trimester': 2, 'test_name': 'Anomaly Scan Ultrasound (Level 2)'},
      {'trimester': 2, 'test_name': 'Glucose Challenge Test (GCT)'},
      {'trimester': 2, 'test_name': 'Hemoglobin Level'},
      {'trimester': 3, 'test_name': 'Group B Streptococcus (GBS)'},
      {'trimester': 3, 'test_name': 'Non-Stress Test (NST)'},
      {'trimester': 3, 'test_name': 'Third-Trimester Ultrasound'},
    ];

    for (final test in defaultTests) {
      final docRef = _firestore.collection('prenatal_tests').doc();
      final data = {
        'family_id': familyId,
        'member_id': memberId,
        'trimester': test['trimester'],
        'test_name': test['test_name'],
        'is_completed': false,
        'completed_at': null,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };
      await docRef.set(data);
      await _repository.insertPrenatalTest({
        'id': docRef.id,
        'family_id': familyId,
        'member_id': memberId,
        'trimester': test['trimester'],
        'test_name': test['test_name'],
        'is_completed': 0,
        'completed_at': null,
      });
    }
  }

  Future<void> completePrenatalTest(String testId) async {
    await _repository.completePrenatalTest(testId);
  }

  /// Add a new family member and sync to Firestore.
  Future<String> addFamilyMember({
    required String name,
    required int age,
    required String profileType,
    String? phone,
  }) async {
    final canAdd = await _permissionService.canAddMember();
    if (!canAdd) throw Exception('Only admins can add family members');

    final familyId = await _authService.familyId;
    if (familyId == null) throw Exception('No active family session');

    final memberRef = _firestore.collection('members').doc();
    await memberRef.set({
      'family_id': familyId,
      'name': name.trim(),
      'age': age,
      'profile_type': profileType,
      'phone': phone,
      'user_id': null,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });

    await _repository.addMember({
      'id': memberRef.id,
      'family_id': familyId,
      'name': name.trim(),
      'age': age,
      'profile_type': profileType,
      'phone': phone,
      'user_id': null,
    });

    return memberRef.id;
  }

  /// Add a new user account for a family member.
  Future<String> createMemberAccount({
    required String memberId,
    required String username,
    required String password,
  }) async {
    final familyId = await _authService.familyId;
    if (familyId == null) throw Exception('No active family session');

    final userRole = await _authService.userRole;
    if (userRole != 'admin') {
      throw Exception('Only admins can create member accounts');
    }

    final userRef = _firestore.collection('users').doc();
    final passwordHash = _simpleHash(password);

    await userRef.set({
      'family_id': familyId,
      'username': username.trim(),
      'password_hash': passwordHash,
      'role': 'member',
      'phone': null,
      'pin_hash': null,
      'is_active': true,
      'failed_attempts': 0,
      'locked_until': null,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });

    await _firestore.collection('members').doc(memberId).update({
      'user_id': userRef.id,
      'updated_at': FieldValue.serverTimestamp(),
    });

    final member = await _repository.getMemberById(memberId);
    if (member != null) {
      await _repository.updateMember(member.copyWith(userId: userRef.id).toMap());
    }

    return userRef.id;
  }

  Future<List<Map<String, dynamic>>> getFamilyMembers() async {
    final familyId = await _authService.familyId;
    if (familyId == null) throw Exception('No active family session');

    final snapshot = await _firestore
        .collection('members')
        .where('family_id', isEqualTo: familyId)
        .get();

    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  Future<void> updateFamilyMember({
    required String memberId,
    required String name,
    required int age,
    required String profileType,
    String? phone,
  }) async {
    final canEdit = await _permissionService.canEditMember();
    if (!canEdit) throw Exception('Only admins can update members');

    await _firestore.collection('members').doc(memberId).update({
      'name': name.trim(),
      'age': age,
      'profile_type': profileType,
      'phone': phone,
      'updated_at': FieldValue.serverTimestamp(),
    });

    final existing = await _repository.getMemberById(memberId);
    await _repository.updateMember({
      'id': memberId,
      'family_id': existing?.familyId ?? await _authService.familyId,
      'name': name.trim(),
      'age': age,
      'profile_type': profileType,
      'phone': phone,
      'user_id': existing?.userId,
    });
  }

  Future<void> deleteFamilyMember(String memberId) async {
    final canDelete = await _permissionService.canDeleteMember();
    if (!canDelete) throw Exception('Only admins can delete members');

    await _firestore.collection('members').doc(memberId).delete();
    await _repository.deleteMember(memberId);
  }

  Map<String, dynamic> _sanitizeData(Map<String, dynamic> data) {
    final sanitized = <String, dynamic>{};
    data.forEach((key, value) {
      if (value is Timestamp) {
        sanitized[key] = value.toDate().toIso8601String();
      } else if (value is DateTime) {
        sanitized[key] = value.toIso8601String();
      } else {
        sanitized[key] = value;
      }
    });
    return sanitized;
  }

  int _boolToInt(dynamic value, {required bool fallback}) {
    if (value == null) return fallback ? 1 : 0;
    if (value is bool) return value ? 1 : 0;
    if (value is int) return value == 0 ? 0 : 1;
    if (value is num) return value == 0 ? 0 : 1;
    if (value is String) {
      final normalized = value.toLowerCase().trim();
      return normalized == 'false' || normalized == '0' ? 0 : 1;
    }
    return fallback ? 1 : 0;
  }

  String _simpleHash(String input) {
    int hash = 0;
    for (int i = 0; i < input.length; i++) {
      hash = ((hash << 5) - hash) + input.codeUnitAt(i);
      hash = hash & hash;
    }
    return hash.abs().toString();
  }
}
