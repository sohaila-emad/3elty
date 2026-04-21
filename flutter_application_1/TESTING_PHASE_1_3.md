# Testing Guide: Phases 1-3 (PIN Login & Account Locking)

## Prerequisites

1. ✅ Flutter app compiles without errors
2. ✅ Firebase connection works (check other features)
3. ✅ You have access to Firestore console

## Test Setup: Create Test User in Firestore

### Step 1: Open Firestore Console
- Go to [Firebase Console](https://console.firebase.google.com/)
- Select your project: `3elty-app` (or your project name)
- Navigate to **Firestore Database**

### Step 2: Create Test Family (if not exists)

In **Collections** → **families**, create new document:

```
Document ID: family_test_001
Fields:
  family_username (string): "testfamily"
  display_name (string): "Test Family"
  password_hash (string): "1d7f7abc18fcb440975651f14795b0e524a62efa81dd4aa8f43acee22e5da78b" 
                          // This is SHA256 hash of "testpass123"
  created_at (timestamp): server timestamp
  updated_at (timestamp): server timestamp
```

**How to get SHA256 hash:**
- Go to [SHA256 online tool](https://www.sha256online.com/)
- Enter: `testpass123`
- Copy hash: `1d7f7abc18fcb440975651f14795b0e524a62efa81dd4aa8f43acee22e5da78b`

### Step 3: Create Test User (Admin)

In **Collections** → **users**, create new document:

```
Document ID: user_admin_001
Fields:
  family_id (string): "family_test_001"           // Match family ID above
  username (string): "admin"
  password_hash (string): "1d7f7abc18fcb440975651f14795b0e524a62efa81dd4aa8f43acee22e5da78b"
                          // Same as above (or different if you prefer)
  role (string): "admin"
  is_active (bool): true
  created_at (timestamp): server timestamp
  updated_at (timestamp): server timestamp
  
  // NEW FIELDS FOR PIN LOGIN
  login_attempts (number): 0
  pin_attempts (number): 0
  is_locked (bool): false
  lock_expiry (timestamp): null
  last_failed_attempt (timestamp): null
  pin_last_failed (timestamp): null
  phone (string): "5551234567"
  pin_hash (string): "03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f0dd5e894626"
                     // This is SHA256 hash of "1234" (the PIN)
  login_lockout_threshold (number): 3
  login_lockout_duration_minutes (number): 30
```

**PIN Hash Calculation:**
- Go to [SHA256 online tool](https://www.sha256online.com/)
- Enter: `1234`
- Copy hash: `03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f0dd5e894626`

### Step 4: Create Test Member User (PIN Login)

In **Collections** → **users**, create new document:

```
Document ID: user_member_001
Fields:
  family_id (string): "family_test_001"
  username (string): "testmember"
  password_hash (string): "1d7f7abc18fcb440975651f14795b0e524a62efa81dd4aa8f43acee22e5da78b"
  role (string): "member"
  is_active (bool): true
  created_at (timestamp): server timestamp
  updated_at (timestamp): server timestamp
  
  // NEW FIELDS FOR PIN LOGIN
  login_attempts (number): 0
  pin_attempts (number): 0
  is_locked (bool): false
  lock_expiry (timestamp): null
  last_failed_attempt (timestamp): null
  pin_last_failed (timestamp): null
  phone (string): "5559876543"
  pin_hash (string): "03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f0dd5e894626"
                     // SHA256 of "1234"
  login_lockout_threshold (number): 3
  login_lockout_duration_minutes (number): 30
```

---

## Test Cases

### TEST 1: Verify Member PIN Login Screen Loads

**Steps:**
1. Run app: `flutter run`
2. On login screen, tap **"Login as Member (PIN)"** button
3. Verify new screen appears with:
   - ✅ Title: "Member Login"
   - ✅ Phone number input field
   - ✅ Large numeric keypad (0-9, backspace, clear)
   - ✅ PIN display area (4 circles, masked as ●)
   - ✅ "Confirm" button
   - ✅ "Back to Family Login" button

**Expected Result:** ✅ All UI elements display correctly, buttons are large (44x44px+)

---

### TEST 2: Valid PIN Login (Happy Path)

**Steps:**
1. On Member PIN Login screen:
   - Phone field: enter `5551234567`
   - PIN: tap `1` → `2` → `3` → `4`
   - Tap "Confirm"

2. Verify:
   - ✅ Loading indicator appears briefly
   - ✅ After 2-3 seconds, redirected to dashboard
   - ✅ User is logged in as member

**Expected Result:** ✅ Login succeeds, user reaches dashboard

---

### TEST 3: Invalid PIN - Failed Attempts (3/3)

**Test Case 3A: Wrong PIN First Attempt**

**Steps:**
1. On Member PIN Login screen:
   - Phone: `5551234567`
   - PIN: `1111` (wrong PIN)
   - Tap "Confirm"

2. Verify error message:
   - ✅ Error appears: **"Invalid PIN. Attempts remaining: 2"**
   - ✅ Error is displayed in red box with high contrast
   - ✅ Form remains on screen (not dismissed)
   - ✅ Attempt counter shows: **"Failed attempts: 1/3"**

**Expected Result:** ✅ Error shown, counter updates

---

**Test Case 3B: Wrong PIN Second Attempt**

**Steps:**
1. Clear phone and PIN fields
2. Re-enter:
   - Phone: `5551234567`
   - PIN: `9999` (different wrong PIN)
   - Tap "Confirm"

3. Verify:
   - ✅ Error appears: **"Invalid PIN. Attempts remaining: 1"**
   - ✅ Attempt counter shows: **"Failed attempts: 2/3"**

**Expected Result:** ✅ Attempt counter increments

---

**Test Case 3C: Wrong PIN Third Attempt (TRIGGER LOCKOUT)**

**Steps:**
1. Clear fields again
2. Re-enter:
   - Phone: `5551234567`
   - PIN: `0000` (different wrong PIN again)
   - Tap "Confirm"

3. Verify account locks:
   - ✅ Error appears: **"Account locked. Try again in 30 minutes"** (or similar)
   - ✅ Error is in **ORANGE** box (lockout warning color)
   - ✅ Lockout countdown timer appears: **"Account Locked - Try again in 30 minutes"**
   - ✅ Phone and PIN inputs become **DISABLED** (greyed out)
   - ✅ "Confirm" button becomes **DISABLED**
   - ✅ Countdown timer shows: **"30"** or similar

**Expected Result:** ✅ Account locked, form disabled, countdown starts

---

### TEST 4: Lockout Countdown Timer

**Test Case 4A: Verify Timer Counts Down**

**Steps:**
1. Account is locked (from Test 3C)
2. Watch the countdown timer for 10-15 seconds
3. Verify:
   - ✅ Timer updates every second
   - ✅ Display changes: 30 → 29 → 28 → 27...
   - ✅ Form remains disabled during countdown

**Expected Result:** ✅ Timer counts down correctly

---

**Test Case 4B: Verify Account Auto-Unlocks (Optional)**

⚠️ **NOTE:** Testing full 30-minute lockout is not practical. Instead:

**Option A: Manual Testing in Firestore**
1. In Firestore, find user document `user_member_001`
2. Edit `lock_expiry` field: set to **current time - 1 second**
   - This makes the lock appear expired
3. Go back to app, wait 5 seconds
4. Verify:
   - ✅ Countdown disappears
   - ✅ Error message changes to: **"Account unlocked. You can try again."**
   - ✅ Form becomes **ENABLED** again
   - ✅ Phone and PIN fields can be edited
   - ✅ "Confirm" button is clickable

**Expected Result:** ✅ Account unlocks, form re-enables

---

### TEST 5: Correct PIN After Lockout (Happy Path Recovery)

**Prerequisites:** Account must be unlocked (from Test 4B)

**Steps:**
1. On Member PIN Login screen (should be unlocked):
   - Phone: `5551234567`
   - PIN: `1234` (correct PIN)
   - Tap "Confirm"

2. Verify:
   - ✅ No error messages
   - ✅ Login succeeds
   - ✅ Redirected to dashboard
   - ✅ User is logged in as member

**Expected Result:** ✅ Login succeeds after unlock

---

### TEST 6: Verify Attempt Counters Reset on Successful Login

**Prerequisites:** User must be logged in successfully

**Steps:**
1. Log out (navigate to settings/logout if available)
2. Log back in with correct PIN again
3. Check Firestore document `user_member_001`:
   - ✅ `login_attempts` = 0
   - ✅ `pin_attempts` = 0
   - ✅ `last_failed_attempt` = null
   - ✅ `pin_last_failed` = null

**Expected Result:** ✅ Attempt counters reset to 0

---

### TEST 7: Invalid Phone Number

**Steps:**
1. On Member PIN Login screen:
   - Phone: `555` (too short, less than 10 digits)
   - PIN: `1234`
   - Tap "Confirm"

2. Verify error:
   - ✅ Error message: **"Invalid phone number"** or **"Please enter a valid phone number (at least 10 digits)"**
   - ✅ No login attempt is made (not recorded in Firestore)
   - ✅ Form stays on screen

**Expected Result:** ✅ Validation error shown, no attempt recorded

---

### TEST 8: Phone Number Not Found

**Steps:**
1. On Member PIN Login screen:
   - Phone: `9999999999` (10 digits, but no user with this phone)
   - PIN: `1234`
   - Tap "Confirm"

2. Verify error:
   - ✅ Error message: **"User not found"**
   - ✅ No lockout triggered (this is not a failed PIN, it's a missing user)
   - ✅ Form stays on screen

**Expected Result:** ✅ "User not found" error, no lockout

---

### TEST 9: Empty Fields

**Steps:**
1. On Member PIN Login screen:
   - Phone: empty
   - PIN: empty
   - Tap "Confirm"

2. Verify error:
   - ✅ Error message: **"Please enter a valid phone number..."** or similar
   - ✅ No login attempt made
   - ✅ Form stays on screen

**Expected Result:** ✅ Validation error shown

---

### TEST 10: UI/UX - Large Buttons & Accessibility

**Steps:**
1. On Member PIN Login screen, test with elderly user simulation:
   - Tap numeric keypad buttons
   - Verify buttons are easy to tap (not too small)
   - Verify PIN display (●●●●) is clearly visible
   - Verify error messages are readable (large font, high contrast)
   - Verify attempt counter is visible
   - Verify lockout timer is easy to read

2. Measurements (manual check):
   - ✅ Button size: approximately 44-56 pixels (large)
   - ✅ Font sizes: body text 16px+, alerts 20px+
   - ✅ Colors: dark text on light background (high contrast)
   - ✅ Spacing: comfortable gaps between buttons

**Expected Result:** ✅ All accessibility features work correctly

---

## Troubleshooting

### Issue: "User not found"
- **Cause:** Phone number in Firestore doesn't match entered phone
- **Fix:** Double-check phone field in Firestore matches test input exactly

### Issue: "Invalid PIN" immediately
- **Cause:** PIN hash doesn't match
- **Fix:** 
  1. Calculate SHA256 of your PIN correctly
  2. Verify pin_hash field in Firestore matches exactly
  3. Test with PIN "1234" (hash: `03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f0dd5e894626`)

### Issue: Lockout not working
- **Cause:** is_locked field not updated, or lockout logic not triggered
- **Fix:**
  1. Check Firestore for `is_locked: true` after 3 failed attempts
  2. Check `lock_expiry` timestamp is set
  3. Verify `login_lockout_threshold` = 3 in Firestore

### Issue: Countdown timer not appearing
- **Cause:** is_locked might not be true, or UI not updating
- **Fix:**
  1. Force quit app and restart
  2. Check Firestore to verify is_locked = true
  3. Check lock_expiry is set to a future timestamp

### Issue: "Back to Family Login" button doesn't work
- **Cause:** Navigation not configured
- **Fix:** Verify MemberPinLoginScreen is imported in family_auth_screen.dart

---

## Success Criteria (All Must Pass)

- ✅ TEST 1: UI loads correctly
- ✅ TEST 2: Valid PIN login works
- ✅ TEST 3: Failed attempts tracked (1/3 → 2/3 → 3/3)
- ✅ TEST 4: Account locks after 3 failed attempts
- ✅ TEST 5: Lockout timer counts down correctly
- ✅ TEST 6: Account can be unlocked and login succeeds
- ✅ TEST 7: Attempt counters reset to 0 on success
- ✅ TEST 8: Input validation works (phone/PIN)
- ✅ TEST 9: Empty fields handled
- ✅ TEST 10: UI is accessible (large buttons, readable text)

**Phase 1-3 passes if ALL tests pass.** ✅

---

## Next: Phase 4 Integration Tests

After Phase 1-3 passes:
1. Test lockout display on dashboard
2. Test session persistence (24h login)
3. Test token refresh mechanism
4. Test sign-out behavior

