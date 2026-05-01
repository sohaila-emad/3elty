import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Constants ────────────────────────────────────────────────────────────────
const String kPinPrefix              = 'member_pin_';            // secure storage
const String kLoginCountPrefix        = 'login_count_';          // shared prefs (legacy)
const String kSessionPinVerifiedKey   = 'session_pin_verified_';  // shared prefs
const int    kPinPromptEvery          = 10;                      // ask PIN every N logins (legacy)

// ─── Phone Formatting ─────────────────────────────────────────────────────────
/// Normalizes phone number to E.164 format (+20XXXXXXXXXX for Egypt)
/// Removes leading zeros and handles various input formats.
String normalizePhoneNumber(String phone) {
  // Remove all non-digits
  String digits = phone.replaceAll(RegExp(r'\D'), '');
  
  // Remove leading zeros
  if (digits.startsWith('0')) {
    digits = digits.substring(1);
  }
  
  // If already has country code 20, remove it to avoid duplication
  if (digits.startsWith('20') && digits.length > 10) {
    digits = digits.substring(2);
  }
  
  // Add country code
  return '+20$digits';
}

// ─── Helper: check if this phone is already set up on this device ─────────────
/// Returns true if a PIN is stored for this phone number on this device.
Future<bool> isPhoneSetupOnDevice(String phone) async {
  final storage = const FlutterSecureStorage();
  final normalizedPhone = normalizePhoneNumber(phone);
  final pin = await storage.read(key: '$kPinPrefix$normalizedPhone');
  return pin != null;
}

// ─── Helper: get + increment login count, return whether PIN is needed ────────
/// Increments login count and returns whether PIN should be requested.
/// Requests PIN on first login and every kPinPromptEvery logins after that.
Future<bool> shouldAskPinThisLogin(String phone) async {
  final prefs = await SharedPreferences.getInstance();
  final normalizedPhone = normalizePhoneNumber(phone);
  final key   = '$kLoginCountPrefix$normalizedPhone';
  final count = (prefs.getInt(key) ?? 0) + 1;
  await prefs.setInt(key, count);
  // Ask PIN on the 1st login (always) and every kPinPromptEvery after that
  return count == 1 || count % kPinPromptEvery == 0;
}

// ─── Helper: read stored PIN ──────────────────────────────────────────────────
/// Returns the stored PIN for this phone, or null if not set.
Future<String?> getStoredPin(String phone) async {
  final storage = const FlutterSecureStorage();
  final normalizedPhone = normalizePhoneNumber(phone);
  return storage.read(key: '$kPinPrefix$normalizedPhone');
}

// ─── Helper: save PIN ─────────────────────────────────────────────────────────
/// Saves a PIN to secure storage for this phone number.
Future<void> savePin(String phone, String pin) async {
  final storage = const FlutterSecureStorage();
  final normalizedPhone = normalizePhoneNumber(phone);
  await storage.write(key: '$kPinPrefix$normalizedPhone', value: pin);
}

// ─── Helper: clear PIN ────────────────────────────────────────────────────────
/// Clears the stored PIN for this phone number.
Future<void> clearPin(String phone) async {
  final storage = const FlutterSecureStorage();
  final normalizedPhone = normalizePhoneNumber(phone);
  await storage.delete(key: '$kPinPrefix$normalizedPhone');
}

// ─── Session-based PIN verification (NEW) ──────────────────────────────────────
/// Checks if PIN was verified for this phone DURING THIS APP SESSION
/// Returns true if PIN was successfully entered in this session, false otherwise
Future<bool> hasPinBeenVerifiedThisSession(String phone) async {
  final prefs = await SharedPreferences.getInstance();
  final normalizedPhone = normalizePhoneNumber(phone);
  final key = '$kSessionPinVerifiedKey$normalizedPhone';
  return prefs.getBool(key) ?? false;
}

/// Marks PIN as verified for this phone in the current session
/// Called after user successfully enters PIN and passes validation
Future<void> markPinVerifiedThisSession(String phone) async {
  final prefs = await SharedPreferences.getInstance();
  final normalizedPhone = normalizePhoneNumber(phone);
  final key = '$kSessionPinVerifiedKey$normalizedPhone';
  await prefs.setBool(key, true);
}

/// Resets all session PIN verification flags
/// Called on app startup to ensure fresh session (new app start = new PIN check)
Future<void> resetSessionPinVerification() async {
  final prefs = await SharedPreferences.getInstance();
  final keys = prefs.getKeys();
  for (final key in keys) {
    if (key.startsWith(kSessionPinVerifiedKey)) {
      await prefs.remove(key);
    }
  }
}
