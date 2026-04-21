# Quick Reference: Test Data & Hashes

## Pre-calculated SHA256 Hashes

### Passwords
```
"testpass123" → SHA256 → 1d7f7abc18fcb440975651f14795b0e524a62efa81dd4aa8f43acee22e5da78b
"1234"        → SHA256 → 03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f0dd5e894626
```

## Firestore Setup (Copy-Paste)

### 1. Create Family Document

**Collection:** `families`  
**Document ID:** `family_test_001`

```json
{
  "family_username": "testfamily",
  "display_name": "Test Family",
  "password_hash": "1d7f7abc18fcb440975651f14795b0e524a62efa81dd4aa8f43acee22e5da78b",
  "created_at": null,
  "updated_at": null
}
```

(Set created_at and updated_at to current server timestamp via Firestore UI)

---

### 2. Create Admin User

**Collection:** `users`  
**Document ID:** `user_admin_001`

```json
{
  "family_id": "family_test_001",
  "username": "admin",
  "password_hash": "1d7f7abc18fcb440975651f14795b0e524a62efa81dd4aa8f43acee22e5da78b",
  "role": "admin",
  "is_active": true,
  "created_at": null,
  "updated_at": null,
  "login_attempts": 0,
  "pin_attempts": 0,
  "is_locked": false,
  "lock_expiry": null,
  "last_failed_attempt": null,
  "pin_last_failed": null,
  "phone": "5551234567",
  "pin_hash": "03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f0dd5e894626",
  "login_lockout_threshold": 3,
  "login_lockout_duration_minutes": 30
}
```

---

### 3. Create Member User (PIN Login Test)

**Collection:** `users`  
**Document ID:** `user_member_001`

```json
{
  "family_id": "family_test_001",
  "username": "testmember",
  "password_hash": "1d7f7abc18fcb440975651f14795b0e524a62efa81dd4aa8f43acee22e5da78b",
  "role": "member",
  "is_active": true,
  "created_at": null,
  "updated_at": null,
  "login_attempts": 0,
  "pin_attempts": 0,
  "is_locked": false,
  "lock_expiry": null,
  "last_failed_attempt": null,
  "pin_last_failed": null,
  "phone": "5559876543",
  "pin_hash": "03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f0dd5e894626",
  "login_lockout_threshold": 3,
  "login_lockout_duration_minutes": 30
}
```

---

## Test Credentials

### Family Admin Login
```
Family Username: testfamily
Family Password: testpass123
Admin Password: testpass123 (or different if preferred)
```

### Member PIN Login
```
Phone: 5559876543
PIN: 1234
```

### Wrong PIN Test (for lockout testing)
```
Phone: 5559876543
Wrong PINs: 1111, 9999, 0000, 5555 (any 4-digit PIN except 1234)
```

---

## Steps to Set Up in Firestore

1. **Go to Firestore Console:**
   - [Firebase Console](https://console.firebase.google.com/)
   - Select your project
   - Click **Firestore Database**

2. **Create `families` collection (if not exists):**
   - Click **Create Collection**
   - Name: `families`

3. **Create first family document:**
   - Click **Add Document**
   - Document ID: `family_test_001`
   - Copy-paste fields from "Create Family Document" above
   - For timestamps: click the field, select "Timestamp", set to current time

4. **Create `users` collection:**
   - Click **Create Collection**
   - Name: `users`

5. **Create admin user:**
   - Click **Add Document**
   - Document ID: `user_admin_001`
   - Copy-paste fields from "Create Admin User" above

6. **Create member user:**
   - Click **Add Document**
   - Document ID: `user_member_001`
   - Copy-paste fields from "Create Member User" above

---

## Alternative: Using Firestore REST API

```bash
# Set family document
curl -X PATCH \
  'https://firestore.googleapis.com/v1/projects/YOUR_PROJECT_ID/databases/(default)/documents/families/family_test_001' \
  -H 'Authorization: Bearer YOUR_ACCESS_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{
    "fields": {
      "family_username": {"stringValue": "testfamily"},
      "display_name": {"stringValue": "Test Family"},
      "password_hash": {"stringValue": "1d7f7abc18fcb440975651f14795b0e524a62efa81dd4aa8f43acee22e5da78b"},
      "created_at": {"timestampValue": "2024-01-01T00:00:00Z"},
      "updated_at": {"timestampValue": "2024-01-01T00:00:00Z"}
    }
  }'
```

---

## Firestore Data Validation

After setup, verify documents exist:

**Collections view should show:**
```
families/
  └─ family_test_001 (with fields: family_username, display_name, password_hash)

users/
  ├─ user_admin_001 (with fields: family_id, username, phone, pin_hash, is_locked, etc.)
  └─ user_member_001 (with fields: family_id, username, phone, pin_hash, is_locked, etc.)
```

---

## Quick Checks

✅ All three documents exist in Firestore  
✅ Phone fields match test inputs:
  - Admin: `5551234567`
  - Member: `5559876543`
✅ PIN hashes match (both should be: `03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f0dd5e894626`)  
✅ `is_locked` = false (not locked initially)  
✅ `login_attempts` = 0 (no attempts yet)  
✅ `pin_attempts` = 0 (no PIN attempts yet)  

---

## SHA256 Hash Generator

To verify hashes or generate new ones:

### Online Tool
https://www.sha256online.com/
- Enter text: `1234`
- Copy hash: `03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f0dd5e894626`

### Dart/Flutter Code
```dart
import 'package:crypto/crypto.dart';

String generateHash(String text) {
  return sha256.convert(text.codeUnits).toString();
}

// Usage
String pinHash = generateHash('1234');
print(pinHash); // 03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f0dd5e894626
```

---

## Ready to Test?

1. ✅ Set up test data in Firestore (use TESTING_PHASE_1_3.md)
2. ✅ Run app: `flutter run`
3. ✅ Tap "Login as Member (PIN)"
4. ✅ Enter test credentials
5. ✅ Follow test cases in TESTING_PHASE_1_3.md

Good luck! 🚀
