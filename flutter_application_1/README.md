# 3elty — Family Health Management 🏥

> One app to manage the health of your entire family, tailored for each member's needs.

---

## 📱 About

**3elty** (عيلتي) is a Flutter-based mobile app that helps Egyptian families manage the health of every family member from a single account. Each member gets a personalized health dashboard based on their profile type — Child, Elderly, Pregnant, Chronic, or Adult.

---

## ✨ Features

### 👨‍👩‍👧‍👦 Family Management
- Create a family account with a username, display name, and admin password
- Add multiple family members with name, age, and profile type
- Each member gets a tailored health dashboard
- Long press to delete a member

### 👶 Child Profile
- **Vaccination Schedule** — Egypt MOH calendar with digital booklet, tracks completed vaccines (e.g. 8/12)
- **Growth Tracking** — Log height & weight, compare against WHO percentiles
- **Appointments** — Pediatric visits & reminders
- **Medical Records** — Lab results, prescriptions & profile

### 🤰 Pregnant Profile
- **Prenatal Tests** — Trimester checklist with reminders (e.g. Week 28 due)
- **Prenatal Medications** — Folic acid, iron, calcium tracking
- **Food Safety Guide** — Safe & unsafe local Egyptian dishes
- **Appointments** — OB/GYN visits & ultrasounds
- **Medical Records** — Pregnancy docs & test results

### 🧓 Elderly Profile
- **Emergency Panic Button** — Broadcasts GPS location to all family members
- **Medication Confirmation** — One-tap daily dose tracking with missed-dose alerts
- **Vital Signs** — Blood pressure, glucose & more
- **Appointments** — Doctor visits & follow-ups
- **Medical Records** — Profile, conditions & documents

### 🫀 Chronic Profile
- **Vital Signs Logger** — Blood sugar, blood pressure & trends
- **Medication Adherence** — Daily dose tracker & missed-dose alerts (shows % adherence)
- **Monthly Clinical Summary** — Auto-generated PDF for doctor visits
- **Appointments** — Specialist follow-ups & lab tests
- **Medical Records** — Conditions, allergies & lab results

---

## 🛠️ Tech Stack

- **Framework:** Flutter (Dart)
- **Backend:** Firebase (Firestore)
- **Storage:** flutter_secure_storage
- **Database:** sqflite (local)
- **Platform:** Android

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK 3.x
- Android SDK (Platform Tools)
- A Firebase project configured for the app

### Installation

```bash
# Clone the repository
git clone https://github.com/sohaila-emad/3elty.git

# Navigate to project folder
cd 3elty/flutter_application_1

# Install dependencies
flutter pub get

# Build APK
flutter build apk --release
```

The APK will be at:
```
build/app/outputs/flutter-apk/app-release.apk
```
