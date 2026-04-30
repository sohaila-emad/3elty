import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

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
  static const String _keyAuthToken = 'auth_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keyFamilyId = 'family_id';
  static const String _keyUserId = 'user_id';
  static const String _keyUserRole = 'user_role';

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
  /// Returns family_id if successful, throws exception if fails.
  Future<String> signUpFamily({
    required String familyUsername,
    required String displayName,
    required String familyPassword,
    required String adminPassword,
  }) async {
    try {
      // Validate inputs
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

      // Check if family_username already exists
      final existingFamily = await _firestore
          .collection('families')
          .where('family_username', isEqualTo: familyUsername.trim())
          .limit(1)
          .get();

      if (existingFamily.docs.isNotEmpty) {
        throw Exception('Family username already exists');
      }

      // Create family document with family password
      final familyDocRef = _firestore.collection('families').doc();
      final familyId = familyDocRef.id;

      await familyDocRef.set({
        'family_username': familyUsername.trim(),
        'display_name': displayName.trim(),
        'password_hash': _hashPassword(familyPassword),
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Create admin user document with admin password
      final userDocRef = _firestore.collection('users').doc();
      final userId = userDocRef.id;

      await userDocRef.set({
        'family_id': familyId,
        'username': 'admin', // Admin user is always 'admin'
        'password_hash': _hashPassword(adminPassword),
        'role': 'admin',
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Generate and store tokens
      final token = _generateToken(userId, familyId, 'admin');
      await _storeTokens(token, familyId, userId, 'admin');

      return familyId;
    } catch (e) {
      throw Exception('Sign up failed: $e');
    }
  }

  /// Sign in an existing family with family credentials.
  /// Returns family_id if successful, throws exception if fails.
  Future<String> signInFamily({
    required String familyUsername,
    required String familyPassword,
  }) async {
    try {
      // Find family by family_username
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
      
      // Safely get family password hash with type checking
      final data = familyDoc.data();
      final storedFamilyPasswordHash = data['password_hash'];
      if (storedFamilyPasswordHash == null || storedFamilyPasswordHash is! String) {
        throw Exception('Invalid family password configuration. Please contact support.');
      }

      // Verify family password
      final inputHash = _hashPassword(familyPassword);
      if (storedFamilyPasswordHash.toString() != inputHash) {
        throw Exception('Incorrect family password');
      }

      // Find admin user for this family (to get user role)
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

      // Generate and store tokens (initially as admin, may downgrade later)
      final token = _generateToken(userId, familyId, userRole);
      await _storeTokens(token, familyId, userId, userRole);

      return familyId;
    } catch (e) {
      throw Exception('Sign in failed: $e');
    }
  }

  /// Sign in as a family member (if they have individual login).
  /// Returns family_id if successful, throws exception if fails.
  Future<String> signInMember({
    required String familyUsername,
    required String memberUsername,
    required String password,
  }) async {
    try {
      // Find family by family_username
      final familySnapshot = await _firestore
          .collection('families')
          .where('family_username', isEqualTo: familyUsername.trim())
          .limit(1)
          .get();

      if (familySnapshot.docs.isEmpty) {
        throw Exception('Family not found');
      }

      final familyId = familySnapshot.docs.first.id;

      // Find user in this family
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

      // Verify password
      if (storedPasswordHash != _hashPassword(password)) {
        throw Exception('Invalid password');
      }

      // Generate and store tokens
      final token = _generateToken(userId, familyId, userRole);
      await _storeTokens(token, familyId, userId, userRole);

      return familyId;
    } catch (e) {
      throw Exception('Sign in failed: $e');
    }
  }

  /// Check if a family_username already exists in the database.
  /// Used to determine if user should sign up or sign in.
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

  /// Check if user is currently signed in (has valid token).
  Future<bool> isSignedIn() async {
    try {
      final token = await authToken;
      if (token == null) return false;

      // Check if token is expired
      return !JwtDecoder.isExpired(token);
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
        'family_id': userDoc['family_id'],
        'username': userDoc['username'],
        'role': userDoc['role'],
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
        'family_username': familyDoc['family_username'],
        'display_name': familyDoc['display_name'],
        ...familyDoc.data() as Map<String, dynamic>,
      };
    } catch (e) {
      return null;
    }
  }

  /// Verify admin password for current family (for admin access verification).
  /// Throws exception if password is invalid.
  Future<void> verifyAdminPassword(String adminPassword) async {
    try {
      final familyId = await this.familyId;
      if (familyId == null) {
        throw Exception('No active family session');
      }

      // Find the admin user for this family
      final adminSnapshot = await _firestore
          .collection('users')
          .where('family_id', isEqualTo: familyId)
          .where('role', isEqualTo: 'admin')
          .limit(1)
          .get();

      if (adminSnapshot.docs.isEmpty) {
        throw Exception('Admin user not found');
      }

      final adminDoc = adminSnapshot.docs.first;
      final data = adminDoc.data();
      
      // Safely get password_hash, handling type conversion
      final storedPasswordHash = data['password_hash'];
      if (storedPasswordHash == null || storedPasswordHash is! String) {
        throw Exception('Admin password not configured. Please contact support.');
      }

      // Verify password
      final inputHash = _hashPassword(adminPassword);
      if (storedPasswordHash.toString() != inputHash) {
        throw Exception('Incorrect admin password');
      }

      // Admin password verified successfully - no need to update tokens
      // they were already set during initial signin
    } catch (e) {
      throw Exception('Admin verification failed: $e');
    }
  }

  /// Downgrade admin user to member mode (if they don't verify admin password).
  /// Changes user role from 'admin' to 'member' and updates token.
  Future<void> downgradeToMemberMode() async {
    try {
      final userIdValue = await userId;
      final familyIdValue = await familyId;

      if (userIdValue == null || familyIdValue == null) {
        throw Exception('No active session to downgrade');
      }

      // Update stored role to 'member'
      await _secureStorage.write(key: _keyUserRole, value: 'member');

      // Generate new token with 'member' role
      final newToken = _generateToken(userIdValue, familyIdValue, 'member');
      await _secureStorage.write(key: _keyAuthToken, value: newToken);
    } catch (e) {
      throw Exception('Downgrade failed: $e');
    }
  }

  /// Sign out the current user (clear tokens).
  Future<void> signOut() async {
    try {
      await _secureStorage.delete(key: _keyAuthToken);
      await _secureStorage.delete(key: _keyRefreshToken);
      await _secureStorage.delete(key: _keyFamilyId);
      await _secureStorage.delete(key: _keyUserId);
      await _secureStorage.delete(key: _keyUserRole);
    } catch (e) {
      throw Exception('Sign out failed: $e');
    }
  }

  // ─── Private Helper Methods ────────────────────────────────────────────────

  /// Hash password using SHA256 (simple implementation).
  /// In production, use bcrypt on server-side and verify there.
  String _hashPassword(String password) {
    return sha256.convert(password.codeUnits).toString();
  }

  /// Generate a simple JWT-like token.
  /// In production, generate tokens on server-side.
  String _generateToken(String userId, String familyId, String role) {
    final now = DateTime.now();
    final expiry = now.add(const Duration(hours: 24));

    final payload = {
      'sub': userId,
      'family_id': familyId,
      'role': role,
      'iat': (now.millisecondsSinceEpoch ~/ 1000),
      'exp': (expiry.millisecondsSinceEpoch ~/ 1000),
    };

    // Simple base64 encoding (for demo purposes)
    // In production: use proper JWT library and sign on server
    return base64Encode(payload.toString().codeUnits);
  }

  /// Store tokens in secure storage.
  Future<void> _storeTokens(
    String token,
    String familyId,
    String userId,
    String userRole,
  ) async {
    await _secureStorage.write(key: _keyAuthToken, value: token);
    await _secureStorage.write(key: _keyFamilyId, value: familyId);
    await _secureStorage.write(key: _keyUserId, value: userId);
    await _secureStorage.write(key: _keyUserRole, value: userRole);
  }
}

// Helper function for base64 encoding
String base64Encode(List<int> bytes) {
  const String base64Alphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  final StringBuffer result = StringBuffer();

  for (int i = 0; i < bytes.length; i += 3) {
    final int b1 = bytes[i];
    final int? b2 = i + 1 < bytes.length ? bytes[i + 1] : null;
    final int? b3 = i + 2 < bytes.length ? bytes[i + 2] : null;

    final int byte1 = (b1 >> 2) & 0x3F;
    final int byte2 = (((b1 & 0x03) << 4) | (b2 != null ? (b2 >> 4) : 0)) & 0x3F;
    final int byte3 =
        b2 != null ? (((b2 & 0x0F) << 2) | (b3 != null ? (b3 >> 6) : 0)) & 0x3F : 64;
    final int byte4 = b3 != null ? (b3 & 0x3F) : 64;

    result.write(base64Alphabet[byte1]);
    result.write(base64Alphabet[byte2]);
    if (byte3 < 64) {
      result.write(base64Alphabet[byte3]);
    } else {
      result.write('=');
    }
    if (byte4 < 64) {
      result.write(base64Alphabet[byte4]);
    } else {
      result.write('=');
    }
  }

  return result.toString();
}
