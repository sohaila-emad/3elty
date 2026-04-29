import 'package:shared_preferences/shared_preferences.dart';

/// Singleton authentication service using SharedPreferences.
/// Manages user sign-up, sign-in, and persistent session storage.
class AuthService {
  AuthService._();
  static final AuthService _instance = AuthService._();

  factory AuthService() => _instance;

  static AuthService get instance => _instance;

  // ─── Keys for SharedPreferences ────────────────────────────────────────────
  static const String _keyAdminName = 'admin_name';
  static const String _keyAdminPhone = 'admin_phone';
  static const String _keyAdminPassword = 'admin_password';
  static const String _keyIsSignedIn = 'is_signed_in';

  /// Sign up a new admin user.
  /// Returns true if signup successful, false if validation fails.
  /// Allows switching to a new account (with different phone) - overwrites old account.
  Future<bool> signUp({
    required String name,
    required String phone,
    required String password,
  }) async {
    try {
      // Validation
      if (name.trim().isEmpty || name.trim().length < 2) {
        throw Exception('Name must be at least 2 characters');
      }
      if (phone.trim().isEmpty || phone.trim().length < 10) {
        throw Exception('Phone number must be at least 10 digits');
      }
      if (password.isEmpty || password.length < 6) {
        throw Exception('Password must be at least 6 characters');
      }

      final prefs = await SharedPreferences.getInstance();

      // Get existing phone (if any)
      final existingPhone = prefs.getString(_keyAdminPhone);

      // If trying to sign up with same phone as existing account, reject
      if (existingPhone != null && existingPhone == phone.trim()) {
        throw Exception('You already have an account with this phone. Use Sign In instead.');
      }

      // Save new credentials (overwrites old account if different phone)
      await prefs.setString(_keyAdminName, name.trim());
      await prefs.setString(_keyAdminPhone, phone.trim());
      await prefs.setString(_keyAdminPassword, password);
      await prefs.setBool(_keyIsSignedIn, true);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Sign in with phone and password.
  /// Returns true if credentials are correct, false otherwise.
  Future<bool> signIn({
    required String phone,
    required String password,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final storedPhone = prefs.getString(_keyAdminPhone);
      final storedPassword = prefs.getString(_keyAdminPassword);

      if (storedPhone == null ||
          storedPassword == null ||
          storedPhone != phone.trim() ||
          storedPassword != password) {
        return false;
      }

      // Mark as signed in
      await prefs.setBool(_keyIsSignedIn, true);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Check if a user is currently signed in.
  Future<bool> isSignedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final signedIn = prefs.getBool(_keyIsSignedIn);
      final phoneExists = prefs.getString(_keyAdminPhone) != null;
      return signedIn == true && phoneExists;
    } catch (e) {
      return false;
    }
  }

  /// Get the current admin user's name.
  Future<String?> getCurrentUserName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyAdminName);
    } catch (e) {
      return null;
    }
  }

  /// Sign out the current user.
  Future<void> signOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsSignedIn, false);
    } catch (e) {
      // Silent fail on sign out
    }
  }

  /// Clear all user data (useful for testing).
  Future<void> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyAdminName);
      await prefs.remove(_keyAdminPhone);
      await prefs.remove(_keyAdminPassword);
      await prefs.remove(_keyIsSignedIn);
    } catch (e) {
      // Silent fail
    }
  }

  /// Get the stored phone number.
  Future<String?> getStoredPhone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyAdminPhone);
    } catch (e) {
      return null;
    }
  }
}
