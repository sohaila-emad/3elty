import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Remote authentication service using Firebase Firestore.
/// Manages family signup, signin, and token management.
class RemoteAuthService {
  RemoteAuthService._();
  static final RemoteAuthService _instance = RemoteAuthService._();

  factory RemoteAuthService() => _instance;
  static RemoteAuthService get instance => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Secure storage keys
  static const String _keyAuthToken    = 'auth_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keyFamilyId     = 'family_id';
  static const String _keyUserId       = 'user_id';
  static const String _keyUserRole     = 'user_role';
  static const String _keyTokenExpiry  = 'token_expiry'; // ← NEW: replaces JwtDecoder

  // Getters for current session info
  Future<String?> get authToken async =>
      await _secureStorage.read(key: _keyAuthToken);

  Future<String?> get familyId async =>
      await _secureStorage.read(key: _keyFamilyId);

  Future<String?> get userId async =>
      await _secureStorage.read(key: _keyUserId);

  Future<String?> get userRole async =>
      await _secureStorage.read(key: _keyUserRole);

  /// Sign up a new family with admin credentials.
  Future<String> signUpFamily({
    required String familyUsername,
    required String displayName,
    required String familyPassword,
    required String adminPassword,
  }) async {
    try {
      if (familyUsername.trim().isEmpty || familyUsername.trim().length < 3) {
        throw Exception('Family username must be at least 3 characters');
      }
      if (displayName.trim().isEmpty) {
        throw Exception('Family name cannot be empty');
      }
      if (familyPassword.isEmpty || familyPassword.length < 6) {
        throw Exception('Family password must be at least 6 characters');
      }
      if (adminPassword.isEmpty || adminPassword.length < 6) {
        throw Exception('Admin password must be at least 6 characters');
      }

      final existingFamily = await _firestore
          .collection('families')
          .where('family_username', isEqualTo: familyUsername.trim())
          .limit(1)
          .get();

      if (existingFamily.docs.isNotEmpty) {
        throw Exception('Family username already exists');
      }

      final familyDocRef = _firestore.collection('families').doc();
      final familyId = familyDocRef.id;

      await familyDocRef.set({
        'family_username': familyUsername.trim(),
        'display_name': displayName.trim(),
        'password_hash': _hashPassword(familyPassword),
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      final userDocRef = _firestore.collection('users').doc();
      final userId = userDocRef.id;

      await userDocRef.set({
        'family_id': familyId,
        'username': 'admin',
        'password_hash': _hashPassword(adminPassword),
        'role': 'admin',
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      final token = _generateToken(userId, familyId, 'admin');
      await _storeTokens(token, familyId, userId, 'admin');

      return familyId;
    } catch (e) {
      throw Exception('Sign up failed: $e');
    }
  }

  /// Sign in an existing family with family credentials.
  Future<String> signInFamily({
    required String familyUsername,
    required String familyPassword,
  }) async {
    try {
      final familySnapshot = await _firestore
          .collection('families')
          .where('family_username', isEqualTo: familyUsername.trim())
          .limit(1)
          .get();

      if (familySnapshot.docs.isEmpty) {
        throw Exception('Family not found');
      }

      final familyDoc = familySnapshot.docs.first;
      final familyId = familyDoc.id;

      final data = familyDoc.data();
      final storedFamilyPasswordHash = data['password_hash'];
      if (storedFamilyPasswordHash == null || storedFamilyPasswordHash is! String) {
        throw Exception('Invalid family password configuration.');
      }

      final inputHash = _hashPassword(familyPassword);
      if (storedFamilyPasswordHash != inputHash) {
        throw Exception('Incorrect family password');
      }

      final userSnapshot = await _firestore
          .collection('users')
          .where('family_id', isEqualTo: familyId)
          .where('role', isEqualTo: 'admin')
          .limit(1)
          .get();

      if (userSnapshot.docs.isEmpty) {
        throw Exception('Admin user not found');
      }

      final userDoc = userSnapshot.docs.first;
      final userId = userDoc.id;
      final userRole = userDoc['role'] as String;

      final token = _generateToken(userId, familyId, userRole);
      await _storeTokens(token, familyId, userId, userRole);

      return familyId;
    } catch (e) {
      throw Exception('Sign in failed: $e');
    }
  }

  Future<String> signInWithPin({
    required String phone,
    required String pin,
  }) async {
    final currentFamilyId = await familyId; // ← ADD THIS
    if (currentFamilyId == null) throw Exception('No active family session.');

    final result = await _firestore
        .collection('users')
        .where('phone', isEqualTo: phone.trim())
        .where('family_id', isEqualTo: currentFamilyId)
        .where('role', isEqualTo: 'member')
        .limit(1)
        .get();

    if (result.docs.isEmpty) {
      throw Exception('No account found for this phone number.');
    }

    final userDoc = result.docs.first;
    final data = userDoc.data();
    final userId = userDoc.id;
    final linkedFamilyId = data['family_id'] as String?; // ← renamed to avoid conflict

    if (linkedFamilyId == null) throw Exception('Account not linked to a family.');

    // Check lockout
    final lockedUntil = data['locked_until'] as String?;
    if (lockedUntil != null) {
      final lockTime = DateTime.tryParse(lockedUntil);
      if (lockTime != null && DateTime.now().isBefore(lockTime)) {
        throw Exception('Account locked. Try again later.');
      }
    }

    final storedHash = data['pin_hash'] as String?;
    if (storedHash == null) throw Exception('PIN not set up for this account.');

    final failedAttempts = data['failed_attempts'] as int? ?? 0;

    if (storedHash != _hashPassword(pin)) {
      final newAttempts = failedAttempts + 1;
      final updateData = <String, dynamic>{'failed_attempts': newAttempts};
      if (newAttempts >= 5) {
        updateData['locked_until'] =
            DateTime.now().add(const Duration(minutes: 30)).toIso8601String();
      }
      await _firestore.collection('users').doc(userId).update(updateData);
      final remaining = 5 - newAttempts;
      throw Exception(remaining > 0
          ? 'Invalid PIN. Attempts remaining: $remaining'
          : 'Account locked for 30 minutes.');
    }

    // Correct PIN — reset counters
    await _firestore.collection('users').doc(userId).update({
      'failed_attempts': 0,
      'locked_until': FieldValue.delete(),
      'last_login': FieldValue.serverTimestamp(),
    });

    final token = _generateToken(userId, linkedFamilyId, 'member');
    await _storeTokens(token, linkedFamilyId, userId, 'member');
    return linkedFamilyId;
  }
  /// Sign in as a member using family username + member username + password.
  Future<String> signInMember({
    required String familyUsername,
    required String memberUsername,
    required String password,
  }) async {
    try {
      final familySnapshot = await _firestore
          .collection('families')
          .where('family_username', isEqualTo: familyUsername.trim())
          .limit(1)
          .get();

      if (familySnapshot.docs.isEmpty) {
        throw Exception('Family not found');
      }

      final familyId = familySnapshot.docs.first.id;

      final userSnapshot = await _firestore
          .collection('users')
          .where('family_id', isEqualTo: familyId)
          .where('username', isEqualTo: memberUsername.trim())
          .limit(1)
          .get();

      if (userSnapshot.docs.isEmpty) {
        throw Exception('User not found in this family');
      }

      final userDoc = userSnapshot.docs.first;
      final userId = userDoc.id;
      final storedPasswordHash = userDoc['password_hash'] as String;
      final userRole = userDoc['role'] as String;

      if (storedPasswordHash != _hashPassword(password)) {
        throw Exception('Invalid password');
      }

      final token = _generateToken(userId, familyId, userRole);
      await _storeTokens(token, familyId, userId, userRole);

      return familyId;
    } catch (e) {
      throw Exception('Sign in failed: $e');
    }
  }

  /// Check if a family_username already exists.
  Future<bool> familyExists(String familyUsername) async {
    try {
      final result = await _firestore
          .collection('families')
          .where('family_username', isEqualTo: familyUsername.trim())
          .limit(1)
          .get();
      return result.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Check if user is currently signed in (has valid non-expired session).
  /// FIX: No longer uses JwtDecoder — stores expiry separately in secure storage.
  Future<bool> isSignedIn() async {
    try {
      final token = await authToken;
      if (token == null) return false;

      final expiryStr = await _secureStorage.read(key: _keyTokenExpiry);
      if (expiryStr == null) return false;

      final expiry = DateTime.tryParse(expiryStr);
      if (expiry == null) return false;

      return DateTime.now().isBefore(expiry);
    } catch (e) {
      return false;
    }
  }

  /// Get current user's full information.
  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final userIdValue = await userId;
      if (userIdValue == null) return null;

      final userDoc =
          await _firestore.collection('users').doc(userIdValue).get();
      if (!userDoc.exists) return null;

      return {
        'id': userDoc.id,
        ...userDoc.data() as Map<String, dynamic>,
      };
    } catch (e) {
      return null;
    }
  }

  /// Get current family information.
  Future<Map<String, dynamic>?> getCurrentFamily() async {
    try {
      final familyIdValue = await familyId;
      if (familyIdValue == null) return null;

      final familyDoc =
          await _firestore.collection('families').doc(familyIdValue).get();
      if (!familyDoc.exists) return null;

      return {
        'id': familyDoc.id,
        ...familyDoc.data() as Map<String, dynamic>,
      };
    } catch (e) {
      return null;
    }
  }

  /// Verify admin password for current family.
  Future<void> verifyAdminPassword(String adminPassword) async {
    try {
      final familyIdValue = await familyId;
      if (familyIdValue == null) throw Exception('No active family session');

      final adminSnapshot = await _firestore
          .collection('users')
          .where('family_id', isEqualTo: familyIdValue)
          .where('role', isEqualTo: 'admin')
          .limit(1)
          .get();

      if (adminSnapshot.docs.isEmpty) throw Exception('Admin user not found');

      final data = adminSnapshot.docs.first.data();
      final storedHash = data['password_hash'];
      if (storedHash == null || storedHash is! String) {
        throw Exception('Admin password not configured.');
      }

      if (storedHash != _hashPassword(adminPassword)) {
        throw Exception('Incorrect admin password');
      }
    } catch (e) {
      throw Exception('Admin verification failed: $e');
    }
  }

  /// Downgrade admin user to member mode.
  Future<void> downgradeToMemberMode() async {
    try {
      final userIdValue = await userId;
      final familyIdValue = await familyId;
      if (userIdValue == null || familyIdValue == null) {
        throw Exception('No active session to downgrade');
      }
      await _secureStorage.write(key: _keyUserRole, value: 'member');
      final newToken = _generateToken(userIdValue, familyIdValue, 'member');
      await _secureStorage.write(key: _keyAuthToken, value: newToken);
    } catch (e) {
      throw Exception('Downgrade failed: $e');
    }
  }

  /// Sign out — clear all tokens.
  Future<void> signOut() async {
    try {
      await _secureStorage.delete(key: _keyAuthToken);
      await _secureStorage.delete(key: _keyRefreshToken);
      await _secureStorage.delete(key: _keyFamilyId);
      await _secureStorage.delete(key: _keyUserId);
      await _secureStorage.delete(key: _keyUserRole);
      await _secureStorage.delete(key: _keyTokenExpiry);
    } catch (e) {
      throw Exception('Sign out failed: $e');
    }
  }

  // ── Member PIN helpers ─────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getUserDocument(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;
      return {'id': doc.id, ...doc.data() as Map<String, dynamic>};
    } catch (e) {
      return null;
    }
  }

  Future<void> setupMemberPin({
    required String userId,
    required String phoneNumber,
    required String newPin,
  }) async {
    await _firestore.collection('users').doc(userId).update({
      'phone': phoneNumber,
      'pin_hash': _hashPassword(newPin),
      'pin_set_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<bool> verifyPin(String userId, String pin) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return false;
      final data = doc.data() as Map<String, dynamic>;
      final storedHash = data['pin_hash'] as String?;
      if (storedHash == null) return false;
      return storedHash == _hashPassword(pin);
    } catch (e) {
      return false;
    }
  }

  Future<void> setupMemberCredentials({
    required String memberId,
    required String phone,
    required String pin,
  }) async {
    await _firestore.collection('users').doc(memberId).update({
      'phone': phone.trim(),
      'pin_hash': _hashPassword(pin),
      'is_active': true,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> recordFailedAttempt(
      String userId, String familyId, String attemptType) async {
    await _firestore.collection('access_log').add({
      'user_id': userId,
      'family_id': familyId,
      'event': 'failed_$attemptType',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> recordAccessSession({
    required String accessorId,
    required String targetMemberId,
    required String familyId,
    required String accessType,
  }) async {
    await _firestore.collection('access_log').add({
      'user_id': accessorId,
      'target_member_id': targetMemberId,
      'family_id': familyId,
      'event': accessType,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<List<Map<String, dynamic>>> getMemberAccessHistory(
      String memberId) async {
    try {
      final snapshot = await _firestore
          .collection('access_log')
          .where('target_member_id', isEqualTo: memberId)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();
      return snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Check if a phone number was registered by any admin in Firestore.
  /// Used by FirstTimeSetupScreen before sending OTP.
  Future<bool> isPhoneRegisteredByAdmin(String phone) async {
    try {
      final currentFamilyId = await familyId; // await the getter
      if (currentFamilyId == null) return false;

      // Check members collection (where admin adds new members)
      final memberResult = await _firestore
          .collection('members')
          .where('phone', isEqualTo: phone.trim())
          .where('family_id', isEqualTo: currentFamilyId)
          .limit(1)
          .get();
      if (memberResult.docs.isNotEmpty) return true;

      // Also check users collection (members who already set up PIN)
      final userResult = await _firestore
          .collection('users')
          .where('phone', isEqualTo: phone.trim())
          .where('family_id', isEqualTo: currentFamilyId) // ← same filter
          .where('role', isEqualTo: 'member')              // ← role filter here
          .limit(1)
          .get();
      return userResult.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Get family ID for a phone number (from member record created by admin)
  /// Used during first-time setup to create user document
  Future<String?> getFamilyIdByPhone(String phone) async {
    try {
      final result = await _firestore
          .collection('members')
          .where('phone', isEqualTo: phone.trim())
          .limit(1)
          .get();
      if (result.docs.isEmpty) return null;
      return result.docs.first['family_id'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// Check if a member has set up their PIN (pin_hash exists in Firestore)
  Future<bool> hasMemberSetPin(String phone) async {
    try {
      final result = await _firestore
          .collection('users')
          .where('phone', isEqualTo: phone.trim())
          .limit(1)
          .get();
      if (result.docs.isEmpty) return false;
      
      final userData = result.docs.first.data();
      final pinHash = userData['pin_hash'] as String?;
      return pinHash != null && pinHash.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Create a user document in Firestore for a member during first-time OTP setup
  /// This links the Firebase Auth phone to a Firestore user with pin_hash later
  Future<String> createMemberUserByPhone({
    required String phone,
  }) async {
    try {
      final familyId = await getFamilyIdByPhone(phone);
      if (familyId == null) {
        throw Exception('Phone number not registered by admin');
      }

      final userRef = _firestore.collection('users').doc();
      await userRef.set({
        'phone': phone.trim(),
        'family_id': familyId,
        'role': 'member',
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      return userRef.id;
    } catch (e) {
      throw Exception('Failed to create member user: $e');
    }
  }
  
  /// Save PIN hash to the user document identified by phone number.
  /// Called after OTP is verified and user sets their PIN.
  /// The user document should already exist (created by createMemberUserByPhone)
  /// 
  /// [userId] - Optional: if provided, uses this directly (avoids query race condition)
  /// [phone] - Required if userId not provided
  Future<void> setupMemberPinByPhone({
    String? userId,
    String? phone,
    required String pin,
  }) async {
    String finalUserId = userId ?? '';
    
    // If userId not provided, query by phone
    if (finalUserId.isEmpty && phone != null) {
      final result = await _firestore
          .collection('users')
          .where('phone', isEqualTo: phone.trim())
          .limit(1)
          .get();
    
      if (result.docs.isEmpty) {
        throw Exception('No member user found with this phone number. Please contact your admin.');
      }
      finalUserId = result.docs.first.id;
    } else if (finalUserId.isEmpty) {
      throw Exception('Either userId or phone must be provided');
    }
  
    await _firestore.collection('users').doc(finalUserId).update({
      'pin_hash':   _hashPassword(pin),
      'pin_set_at': FieldValue.serverTimestamp(),
    });
  }
  // ── Private helpers ────────────────────────────────────────────────────────

  String _hashPassword(String password) {
    return sha256.convert(password.codeUnits).toString();
  }

  /// Generates a simple base64 token for local session tracking.
  /// NOTE: This is NOT a real JWT — do not use JwtDecoder on it.
  /// Expiry is tracked separately in _keyTokenExpiry.
  String _generateToken(String userId, String familyId, String role) {
    final payload = json.encode({
      'sub': userId,
      'family_id': familyId,
      'role': role,
      'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    });
    return base64Url.encode(utf8.encode(payload));
  }

  /// Store tokens + expiry in secure storage.
  Future<void> _storeTokens(
    String token,
    String familyId,
    String userId,
    String userRole,
  ) async {
    final expiry =
        DateTime.now().add(const Duration(hours: 24)).toIso8601String();
    await _secureStorage.write(key: _keyAuthToken, value: token);
    await _secureStorage.write(key: _keyFamilyId, value: familyId);
    await _secureStorage.write(key: _keyUserId, value: userId);
    await _secureStorage.write(key: _keyUserRole, value: userRole);
    await _secureStorage.write(key: _keyTokenExpiry, value: expiry); // ← FIX
  }
}