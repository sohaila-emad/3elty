# Quick Start: Phase 1-3 Testing Checklist

## 5-Minute Setup

### Step 1: Firestore Data Setup (2 min)
- [ ] Open [Firestore Console](https://console.firebase.google.com/)
- [ ] Go to your project → **Firestore Database**
- [ ] Create 3 documents using **TEST_DATA_SETUP.md**:
  - [ ] `families/family_test_001`
  - [ ] `users/user_admin_001`
  - [ ] `users/user_member_001`
- [ ] Verify all documents created with correct fields

### Step 2: Build & Run (2 min)
```bash
cd c:\src\3elty\flutter_application_1
flutter clean
flutter pub get
flutter run
```
- [ ] App builds successfully
- [ ] App launches on device/emulator
- [ ] Login screen appears

### Step 3: Navigate to PIN Login (1 min)
- [ ] On login screen, tap **"Login as Member (PIN)"** button
- [ ] New screen appears with title "Member Login"
- [ ] Phone input field visible
- [ ] 4-digit PIN numeric keypad visible

---

## Test Cases (Run in Order)

### ✅ TEST 1: Valid PIN Login
```
Phone: 5559876543
PIN: 1234
Expected: ✅ Redirect to dashboard
```

**After successful login:**
1. Log out or navigate back to login screen
2. Proceed to TEST 2

---

### ✅ TEST 2: Wrong PIN - Attempt 1/3
```
Phone: 5559876543
PIN: 1111 (WRONG)
Expected: 
  ✅ Error: "Invalid PIN. Attempts remaining: 2"
  ✅ Attempt counter: "Failed attempts: 1/3"
  ✅ Form stays on screen
```

---

### ✅ TEST 3: Wrong PIN - Attempt 2/3
```
Phone: 5559876543
PIN: 9999 (WRONG)
Expected:
  ✅ Error: "Invalid PIN. Attempts remaining: 1"
  ✅ Attempt counter: "Failed attempts: 2/3"
```

---

### ✅ TEST 4: Wrong PIN - Attempt 3/3 (LOCKOUT)
```
Phone: 5559876543
PIN: 0000 (WRONG)
Expected:
  ✅ Error: "Account locked. Try again in 30 minutes"
  ✅ Error in ORANGE box (lockout color)
  ✅ Countdown timer: "Account Locked - Try again in 30 minutes"
  ✅ Phone input: DISABLED (greyed out)
  ✅ PIN keypad: DISABLED (greyed out)
  ✅ "Confirm" button: DISABLED
  ✅ Countdown shows: "30" (minutes remaining)
```

---

### ✅ TEST 5: Unlock Account (Manual Reset)
**Goal:** Simulate lock expiry by editing Firestore

1. In Firestore, open `users/user_member_001`
2. Edit `lock_expiry` field:
   - Change value to: **current time - 1 second**
   - (Make it in the past so it's already expired)
3. Go back to app, wait 5 seconds
4. Expected:
   - ✅ Countdown disappears
   - ✅ Message: "Account unlocked. You can try again."
   - ✅ Phone input: ENABLED (editable)
   - ✅ PIN keypad: ENABLED (clickable)
   - ✅ "Confirm" button: ENABLED (clickable)

---

### ✅ TEST 6: Login After Unlock
```
Phone: 5559876543
PIN: 1234 (CORRECT)
Expected:
  ✅ No errors
  ✅ Redirect to dashboard
  ✅ Successful login
```

---

### ✅ TEST 7: Verify Counters Reset
1. In Firestore, check `users/user_member_001`
2. Expected values:
   - ✅ `login_attempts`: 0
   - ✅ `pin_attempts`: 0
   - ✅ `last_failed_attempt`: null
   - ✅ `pin_last_failed`: null

---

### ✅ TEST 8: Input Validation
```
Phone: 123 (TOO SHORT)
PIN: 1234
Expected:
  ✅ Error: "Invalid phone number (at least 10 digits)"
```

---

### ✅ TEST 9: User Not Found
```
Phone: 9999999999 (VALID FORMAT but no user)
PIN: 1234
Expected:
  ✅ Error: "User not found"
  ✅ NO lockout (this is validation, not a failed PIN)
```

---

## Test Results

### UI/UX Checks
- [ ] Buttons are **LARGE** (easy to tap)
- [ ] Text is **READABLE** (16px+ for body, 20px+ for alerts)
- [ ] Colors have **HIGH CONTRAST** (dark text on light background)
- [ ] Error messages are **CLEAR** (easy to understand)
- [ ] Countdown timer is **VISIBLE** (easy to read)
- [ ] PIN dots (●●●●) are **CLEAR** (not hard to count)

### Functionality Checks
- [ ] Phone validation works
- [ ] PIN input accepts only 0-9
- [ ] PIN limited to 4 digits (no more)
- [ ] Attempt counter increments correctly
- [ ] Lockout triggered after 3 attempts
- [ ] Countdown timer counts down
- [ ] Account auto-unlocks after expiry
- [ ] Successful login redirects to dashboard
- [ ] Counters reset to 0 on success

### Phase 1-3 Complete if:
- [ ] All 9 tests pass
- [ ] All UI checks pass
- [ ] All functionality checks pass

---

## Troubleshooting Quick Fixes

| Problem | Fix |
|---------|-----|
| "User not found" | Check phone in Firestore matches exactly |
| "Invalid PIN" always | Verify pin_hash in Firestore: `03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f0dd5e894626` |
| Lockout not working | Check `is_locked` = true in Firestore after 3 attempts |
| Countdown not showing | Check `lock_expiry` has a future timestamp |
| Button too small | Buttons should be ~50x50 pixels (verify in code) |
| Text too small | Body text should be 16px+, alerts 20px+ |

---

## Post-Testing

### ✅ If All Tests Pass:
- Proceed to **Phase 4: Integration & Testing**
- Document any issues/tweaks needed
- Commit code to repository

### ⚠️ If Any Test Fails:
1. Review the test case carefully
2. Check Firestore data matches TEST_DATA_SETUP.md exactly
3. Check error messages in app for clues
4. Review code changes in TESTING_PHASE_1_3.md
5. Feel free to ask questions or debug

---

## Need Help?

**Files for Reference:**
- `TESTING_PHASE_1_3.md` - Detailed test cases (10+ scenarios)
- `TEST_DATA_SETUP.md` - Firestore setup with JSON
- `lib/screens/member_pin_login_screen.dart` - UI code
- `lib/services/remote_auth_service.dart` - Backend logic

**Quick Commands:**
```bash
# View test file
cat TESTING_PHASE_1_3.md

# View setup data
cat TEST_DATA_SETUP.md

# Rebuild app
flutter clean && flutter pub get && flutter run

# View logs
flutter logs
```

---

**Ready to test? Start with Step 1 above! 🚀**
