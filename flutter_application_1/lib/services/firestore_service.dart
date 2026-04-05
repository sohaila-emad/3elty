import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_1/data/app_repository.dart';
import 'package:flutter_application_1/services/remote_auth_service.dart';
import 'package:flutter_application_1/services/permission_service.dart';

/// Firestore service for syncing family data from Firebase to local SQLite.
/// Implements "pull on login" strategy.
class FirestoreService {
  FirestoreService._();
  static final FirestoreService _instance = FirestoreService._();

  factory FirestoreService() => _instance;
  static FirestoreService get instance => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AppRepository _repository = AppRepository();
  final RemoteAuthService _authService = RemoteAuthService.instance;
  final PermissionService _permissionService = PermissionService.instance;

  /// Sync all family data from Firestore to local SQLite.
  /// Called after successful login to populate local database.
  Future<void> syncFamilyData() async {
    try {
      final familyId = await _authService.familyId;
      if (familyId == null) {
        throw Exception('No active family session');
      }

      // Fetch all members for this family
      final membersSnapshot = await _firestore
          .collection('members')
          .where('family_id', isEqualTo: familyId)
          .get();

      // Sync members to local SQLite
      for (final memberDoc in membersSnapshot.docs) {
        final memberData = memberDoc.data();
        memberData['id'] = memberDoc.id;
        memberData['family_id'] = familyId;
        
        // Check if member exists locally
        final existingMember =
            await _repository.getMemberById(memberDoc.id);
        
        if (existingMember != null) {
          // Update existing member
          await _repository.updateMember(memberData);
        } else {
          // Insert new member
          await _repository.addMember(memberData);
        }
      }

      // Fetch and sync medications
      final medicationsSnapshot = await _firestore
          .collection('medications')
          .where('family_id', isEqualTo: familyId)
          .get();

      for (final medDoc in medicationsSnapshot.docs) {
        final medData = medDoc.data();
        medData['id'] = medDoc.id;
        medData['family_id'] = familyId;

        final existingMed =
            await _repository.getMedicationById(medDoc.id);

        if (existingMed != null) {
          await _repository.updateMedication(medData);
        } else {
          await _repository.addMedication(medData);
        }
      }

      // Fetch and sync appointments
      final appointmentsSnapshot = await _firestore
          .collection('appointments')
          .where('family_id', isEqualTo: familyId)
          .get();

      for (final apptDoc in appointmentsSnapshot.docs) {
        final apptData = apptDoc.data();
        apptData['id'] = apptDoc.id;
        apptData['family_id'] = familyId;

        final existingAppt =
            await _repository.getAppointmentById(apptDoc.id);

        if (existingAppt != null) {
          await _repository.updateAppointment(apptData);
        } else {
          await _repository.addAppointment(apptData);
        }
      }

      // Fetch and sync documents
      final documentsSnapshot = await _firestore
          .collection('documents')
          .where('family_id', isEqualTo: familyId)
          .get();

      for (final docDoc in documentsSnapshot.docs) {
        final docData = docDoc.data();
        docData['id'] = docDoc.id;
        docData['family_id'] = familyId;

        final existingDoc = await _repository.getDocumentById(docDoc.id);

        if (existingDoc != null) {
          await _repository.updateDocument(docData);
        } else {
          await _repository.addDocument(docData);
        }
      }

      // Fetch and sync vaccinations
      final vaccinationsSnapshot = await _firestore
          .collection('vaccinations')
          .where('family_id', isEqualTo: familyId)
          .get();

      for (final vacDoc in vaccinationsSnapshot.docs) {
        final vacData = vacDoc.data();
        vacData['id'] = vacDoc.id;
        vacData['family_id'] = familyId;

        final existingVac =
            await _repository.getVaccinationById(vacDoc.id);

        if (existingVac != null) {
          await _repository.updateVaccination(vacData);
        } else {
          await _repository.addVaccination(vacData);
        }
      }

      // Fetch and sync vital signs
      final vitalsSnapshot = await _firestore
          .collection('vital_signs')
          .where('family_id', isEqualTo: familyId)
          .get();

      for (final vitalDoc in vitalsSnapshot.docs) {
        final vitalData = vitalDoc.data();
        vitalData['id'] = vitalDoc.id;
        vitalData['family_id'] = familyId;

        final existingVital =
            await _repository.getVitalById(vitalDoc.id);

        if (existingVital != null) {
          await _repository.updateVital(vitalData);
        } else {
          await _repository.addVital(vitalData);
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Add a new family member and sync to Firestore.
  /// Only callable by admin users.
  Future<String> addFamilyMember({
    required String name,
    required int age,
    required String profileType,
  }) async {
    try {
      // Check if user has permission to add members
      final canAdd = await _permissionService.canAddMember();
      if (!canAdd) {
        throw Exception('Only admins can add family members');
      }

      final familyId = await _authService.familyId;
      if (familyId == null) {
        throw Exception('No active family session');
      }

      // Add to Firestore
      final memberRef = _firestore.collection('members').doc();
      await memberRef.set({
        'family_id': familyId,
        'name': name.trim(),
        'age': age,
        'profile_type': profileType,
        'user_id': null, // No login by default
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Also add to local SQLite for offline access
      await _repository.addMember({
        'id': memberRef.id,
        'family_id': familyId,
        'name': name.trim(),
        'age': age,
        'profile_type': profileType,
      });

      return memberRef.id;
    } catch (e) {
      throw Exception('Failed to add family member: $e');
    }
  }

  /// Add a new user account for a family member.
  /// Only callable by admin users.
  Future<String> createMemberAccount({
    required String memberId,
    required String username,
    required String password,
  }) async {
    try {
      final familyId = await _authService.familyId;
      if (familyId == null) {
        throw Exception('No active family session');
      }

      final userRole = await _authService.userRole;
      if (userRole != 'admin') {
        throw Exception('Only admins can create member accounts');
      }

      // Create user in Firestore
      final userRef = _firestore.collection('users').doc();
      final passwordHash = _simpleHash(password);

      await userRef.set({
        'family_id': familyId,
        'username': username.trim(),
        'password_hash': passwordHash,
        'role': 'member',
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Link member to user account
      await _firestore
          .collection('members')
          .doc(memberId)
          .update({'user_id': userRef.id});

      return userRef.id;
    } catch (e) {
      throw Exception('Failed to create member account: $e');
    }
  }

  /// Get all family members from Firestore.
  Future<List<Map<String, dynamic>>> getFamilyMembers() async {
    try {
      final familyId = await _authService.familyId;
      if (familyId == null) {
        throw Exception('No active family session');
      }

      final snapshot = await _firestore
          .collection('members')
          .where('family_id', isEqualTo: familyId)
          .get();

      return snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch family members: $e');
    }
  }

  /// Update a family member (admin only).
  Future<void> updateFamilyMember({
    required String memberId,
    required String name,
    required int age,
    required String profileType,
  }) async {
    try {
      // Check if user has permission to edit members
      final canEdit = await _permissionService.canEditMember();
      if (!canEdit) {
        throw Exception('Only admins can update members');
      }

      await _firestore.collection('members').doc(memberId).update({
        'name': name.trim(),
        'age': age,
        'profile_type': profileType,
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Also update locally
      await _repository.updateMember({
        'id': memberId,
        'name': name.trim(),
        'age': age,
        'profile_type': profileType,
      });
    } catch (e) {
      throw Exception('Failed to update member: $e');
    }
  }

  /// Delete a family member (admin only).
  Future<void> deleteFamilyMember(String memberId) async {
    try {
      // Check if user has permission to delete members
      final canDelete = await _permissionService.canDeleteMember();
      if (!canDelete) {
        throw Exception('Only admins can delete members');
      }

      // Delete from Firestore
      await _firestore.collection('members').doc(memberId).delete();

      // Delete from local SQLite
      await _repository.deleteMember(memberId);
    } catch (e) {
      throw Exception('Failed to delete member: $e');
    }
  }

  // ─── Private Helpers ───────────────────────────────────────────────────────

  String _simpleHash(String input) {
    // Simple hash for demo (in production, use server-side bcrypt)
    int hash = 0;
    for (int i = 0; i < input.length; i++) {
      hash = ((hash << 5) - hash) + input.codeUnitAt(i);
      hash = hash & hash; // Convert to 32-bit integer
    }
    return hash.abs().toString();
  }
}
