# Firebase Setup Guide for 3elty App

## ✅ What You Need to Do Now

### Step 1: Get Firebase Credentials (google-services.json)

1. **Go to Firebase Console** → Click your **3elty-app** project
2. Click **Project Settings** (gear icon, top-left)
3. Go to **Your Apps** tab
4. Click the **Android** icon to add Android app
5. Fill in:
   - **Package name:** `com.example.flutter_application_1`
   - **App nickname:** `Flutter App` (optional)
6. Click **Register app**
7. **Download google-services.json**
8. **Move the file to:** `android/app/google-services.json`

### Step 2: Configure Android Build (Already done)

The Firebase dependencies are already added to:
- `pubspec.yaml` ✅
- `android/app/build.gradle` (needs google-services plugin)

Run this to add the plugin:
```bash
cd android/app
# Edit build.gradle.kts and add at top:
plugins {
  id 'com.android.application'
  id 'com.google.gms.google-services'  // Add this line
  id 'kotlin-android'
}
```

### Step 3: Initialize Firebase in Flutter (Already done)

✅ Updated `lib/main.dart` to initialize Firebase automatically on app startup

### Step 4: Create Firestore Collections

**Go to Firebase Console → Firestore Database:**

#### **Collection: families**
Create document with these fields:
```
Document ID: (auto-generated or custom)
├── family_username (String) - MUST be unique
├── display_name (String)
└── created_at (Timestamp)
```

#### **Collection: users**
```
Document ID: (auto-generated)
├── family_id (String) - Reference to families doc
├── username (String)
├── password_hash (String)
├── role (String) - "admin" or "member"
├── is_active (Boolean)
├── created_at (Timestamp)
└── updated_at (Timestamp)
```

#### **Collection: members**
```
Document ID: (auto-generated)
├── family_id (String)
├── name (String)
├── age (Number)
├── profile_type (String) - "child", "elderly", "pregnant", "chronic", "adult"
├── user_id (String, optional)
├── created_at (Timestamp)
└── updated_at (Timestamp)
```

#### **Collection: medications**
```
├── family_id (String)
├── member_id (String)
├── name (String)
├── dose (String)
├── frequency (String)
├── time_of_day (String)
├── is_active (Boolean)
├── created_at (Timestamp)
└── updated_at (Timestamp)
```

#### **Collection: appointments**
```
├── family_id (String)
├── member_id (String)
├── title (String)
├── doctor (String)
├── location (String)
├── scheduled_at (Timestamp)
├── notes (String)
├── created_at (Timestamp)
└── updated_at (Timestamp)
```

#### **Collection: documents**
```
├── family_id (String)
├── member_id (String)
├── title (String)
├── file_path (String)
├── doc_type (String) - "lab_result", "prescription", "xray"
├── created_at (Timestamp)
└── updated_at (Timestamp)
```

#### **Collection: vaccinations**
```
├── family_id (String)
├── member_id (String)
├── vaccine_name (String)
├── clinic_name (String)
├── received_at (Timestamp)
├── is_received (Boolean)
├── created_at (Timestamp)
└── updated_at (Timestamp)
```

#### **Collection: vital_signs**
```
├── family_id (String)
├── member_id (String)
├── type (String) - "blood_pressure_systolic", "blood_sugar", etc.
├── value (Number)
├── unit (String) - "mmHg", "mg/dL", etc.
├── recorded_at (Timestamp)
```

### Step 5: Set Firestore Security Rules

**Go to Firestore Database → Rules tab**

Copy and paste this:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper function to check if user is authenticated
    function isAuth() {
      return request.auth != null;
    }
    
    // Helper function to get family_id from request token
    function getFamilyId() {
      return request.auth.token.family_id;
    }
    
    // Allow any unauthenticated writes to families and users for testing
    // (In production, use custom auth tokens with family_id claim)
    match /families/{familyId} {
      allow read, write: if true; // Allow all for now (change in production)
    }
    
    match /users/{userId} {
      allow read, write: if true; // Allow all for now (change in production)
    }
    
    // Members - only accessible by family members
    match /members/{memberId} {
      allow read, write: if true; // Allow all for now (change in production)
    }
    
    // Medications - only accessible by family members
    match /medications/{medId} {
      allow read, write: if true; // Allow all for now
    }
    
    // Appointments - only accessible by family members
    match /appointments/{appointmentId} {
      allow read, write: if true; // Allow all for now
    }
    
    // Documents - only accessible by family members
    match /documents/{docId} {
      allow read, write: if true; // Allow all for now
    }
    
    // Vaccinations - only accessible by family members
    match /vaccinations/{vacId} {
      allow read, write: if true; // Allow all for now
    }
    
    // Vital signs - only accessible by family members
    match /vital_signs/{vitalId} {
      allow read, write: if true; // Allow all for now
    }
    
  }
}
```

**Note:** These rules allow all access for development. For production, implement proper authentication with custom claims.

---

## 🔧 Alternative: Auto-Configure with FlutterFire CLI

Instead of manual steps, you can use the official FlutterFire tool:

```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure your project (from project root)
flutterfire configure --project=3elty-app
```

This will:
- ✅ Auto-detect your app
- ✅ Generate `firebase_options.dart`
- ✅ Add google-services.json
- ✅ Set up gradle plugins

---

## ✅ Next Steps After Setup

Once Firebase is configured:

1. ✅ Run `flutter pub get`
2. ✅ Run `flutter run` to test
3. Create remaining screens:
   - MemberLoginScreen
   - Admin Member Management
   - Data Refresh button

---

## 🚨 Troubleshooting

**Error: "Failed to read google-services.json"**
- Ensure `android/app/google-services.json` exists

**Error: "FirebaseException: No FirebaseApp"**
- Make sure `Firebase.initializeApp()` is called in `main()`
- Ensure you're using the correct project name in Firestore

**Error: "Package not found: firebase_core"**  
- Run `flutter pub get`
- Run `flutter pub upgrade`

---

Feel free to message if you need help with any of these steps!
