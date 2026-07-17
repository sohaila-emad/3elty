<div align="center">

<img width="200" height="200" alt="Image" src="https://github.com/user-attachments/assets/18e84bcc-56cf-4831-ad50-f802bd72c35d" />

# 3elty (عيلتي) — The Egyptian Family Health Companion

### *One app. One family. Every generation's health, connected.*

<!-- Badges: no changes needed, these render automatically from shields.io -->
![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-Auth%20%7C%20Firestore%20%7C%20FCM-FFCA28?logo=firebase&logoColor=black)
![Platforms](https://img.shields.io/badge/platforms-Android%20%7C%20iOS-blueviolet)
![Status](https://img.shields.io/badge/status-in%20active%20development-orange)
![Hackathon](https://img.shields.io/badge/🏆-Hackathon%20Winner-gold)
![License](https://img.shields.io/badge/license-MIT-green)

</div>

<br/>

<!--
🖼️ SCREENSHOT / IMAGE PLACEHOLDER #2 — HERO BANNER
What to put here: A wide banner (1200x500px) showing 3-4 phone mockups side-by-side:
e.g. the Family Dashboard, the Child Vaccination Schedule, the Elderly "Companion" screen,
and the Chronic Disease vitals chart. This is the single most important image in the README —
it's the first thing recruiters/judges/visitors will see.
Suggested filename: docs/screenshots/hero-banner.png
-->
<p align="center">

</p>

<blockquote align="center">
🏆 <b>Awarded 1st place at a Qabilah hackathon</b> — The app is <b>under active development</b> and Features Adding.
</blockquote>

---

## 📚 Table of Contents

- [Overview](#-overview)
- [The Problem](#-the-problem)
- [Our Solution](#-our-solution)
- [Demo](#-demo)
- [Who It's For](#-who-its-for)
- [Features](#-features)
- [Tech Stack](#️-tech-stack)
- [Project Structure](#-project-structure)
- [Getting Started](#-getting-started)
- [Meet the Team](#-meet-the-team)

---

## 🌟 Overview

**3elty** *(Arabic: عيلتي — "my family")* is a digital health platform built on a simple idea:
**Egyptian families don't manage health individually — they manage it together.**

A single app lets a family admin coordinate vaccinations for their newborn, prenatal checkups for
an expecting mother, daily medication for an elderly parent living alone, and blood-sugar trends
for a diabetic relative — all from one shared, Arabic-first dashboard.

> *"3elty is a digital health platform that treats the family as one unit — managing children's
> vaccinations, pregnancy follow-up, elderly medication, and chronic disease tracking in a single
> Arabic-first application."*

---

## 🚩 The Problem

Egyptian families face three critical, documented healthcare gaps — and no unified digital tool
to manage them.

### 1. Vaccination Records Are Paper-Only
Childhood vaccinations in Egypt are tracked exclusively on a paper booklet issued at birth.
- Booklets are frequently **lost, damaged, or forgotten** — especially when families travel
- Parents have **no way to know which vaccines are upcoming or overdue** without a hospital visit
- There is **no national digital vaccination registry** accessible to parents
- When a family relocates, their child's paper record is effectively lost to the healthcare system

### 2. Families Are Geographically Separated
Urban migration and a growing expatriate community create a serious care gap.
- Millions of Egyptians work abroad while elderly parents remain home with **no digital monitoring**
- Students in other governorates can't easily coordinate care for aging relatives
- Distant caregivers have **no visibility** into medication adherence, vitals, or appointments
- In emergencies, distant family members have **no access** to the patient's medical information

### 3. Fragmented Chronic Disease Management
Non-communicable diseases are Egypt's leading health burden, yet patients manage them alone.
- Egypt ranks **9th globally in diabetes prevalence** — 8.85M patients, projected to reach 20M by 2045
- **Hypertension affects 40%** of Egyptian adults
- No digital tool exists to log readings, track trends, or alert a doctor to dangerous values
- Medical records are scattered across paper prescriptions and photocopied lab results

---

## 💡 Our Solution

An Egyptian family today manages its health with paper booklets, scattered prescriptions,
and WhatsApp messages to distant relatives. **3elty replaces all of it with one connected,
role-based family health platform.**

---

## 🎥 Demo

<!--
🖼️ SCREENSHOT / IMAGE PLACEHOLDER #3 — DEMO GIF OR VIDEO THUMBNAIL
What to put here: A short (15-30s) screen recording turned into a GIF showing the core flow:
open app → family dashboard → tap child profile → mark vaccine as received → see it appear
on the shared calendar. If you have your hackathon demo video on YouTube/Drive, embed a
thumbnail image here that links to it instead.
Suggested filename: docs/screenshots/demo.gif
-->
<p align="center">
  <img src="docs/screenshots/demo.gif" alt="3elty app walkthrough demo" width="300"/>
</p>

<p align="center"><i>Watch the full demo: <a href="#">[Insert YouTube/Drive link here]</a></i></p>

---

## 👨‍👩‍👧‍👦 Who It's For

3elty serves the Egyptian family as a single unit through five member profiles, each unlocking
its own tailored module:

| Profile | Who | Core Problem | 3elty's Answer |
|---|---|---|---|
| 👨 **Family Admin** | Parent managing the household | No tool to coordinate the whole family's health | Family account + shared calendar + dashboard |
| 👶 **Child (0–12)** | Infants & young children | Vaccinations tracked on paper that gets lost | Digital MOH vaccine schedule + automated reminders |
| 🤰 **Pregnant Woman** | Mothers during pregnancy | Prenatal care scattered across clinics & papers | Week-by-week tracking + test reminders |
| 👴 **Elderly Parent** | Age 60+, often chronically ill | Missed medication, family far away can't monitor | Medication tracker + vitals log + panic button |
| 🏥 **Chronic Patient** | Diabetic, hypertensive, cardiac patients | Daily readings untracked, no doctor alert system | Vitals dashboard + red-flag alerts to doctor |


<p align="center">
 <img width="900" height="380" alt="Image" src="https://github.com/user-attachments/assets/827025f5-f919-4eba-a118-2c1b921eb30c" />
</p>

---

## ✨ Features

### 🔐 Family Account & Role System
- One Family Admin account represents the entire household
- Admin adds members and assigns a profile type; permissions cascade automatically
- **Simplified PIN-based login** for elderly members — no complex passwords
- Remote access — family members abroad can view linked profiles from anywhere

<!--
🖼️ SCREENSHOT / IMAGE PLACEHOLDER #5 — AUTH / ONBOARDING
What to put here: Two screens side by side — (1) the family account registration form
(name, phone, password) and (2) the PIN-login screen used by elderly/less tech-savvy members.
Suggested filename: docs/screenshots/auth-onboarding.png
-->
<p align="center">
  <img src="docs/screenshots/auth-onboarding.png" alt="Registration and PIN login screens" width="500"/>
</p>

### 👶 Child Module — "Growing Up"
- Egypt's official **Ministry of Health vaccination schedule** pre-loaded
- Automated reminder 3 days before each upcoming vaccine
- Mark vaccines as received — records clinic name, date, and batch number
- Growth tracking: weight & height plotted against **WHO percentile charts**
- Interactive milestone checklist (first smile, first word, first steps)
- Illness log with symptoms, diagnosis, and treatment
- Full child health record exportable as PDF for any clinic visit


<p align="center">
 <img width="750" height="500" alt="Image" src="https://github.com/user-attachments/assets/cb7951cf-e280-41e2-9df7-8d66a978ec9b" />
</p>

### 🤰 Pregnancy Module — "Journey to Motherhood"
- Week-by-week pregnancy tracker with fetal development & maternal body changes
- Trimester-based prenatal test checklist (blood tests, ultrasounds, glucose screening) with reminders
- Medication log for folic acid, iron, and calcium with adherence tracking
- **Red Flag Alert** system for symptoms requiring immediate emergency attention
- Nutrition guidance using common Egyptian foods (molokhia, ful, lentils) — safe/unsafe tags
- Ultrasound and appointment history timeline


<p align="center">
  <img width="1603" height="729" alt="Image" src="https://github.com/user-attachments/assets/2f67669d-8ae9-4b42-9b60-b0cfe1b2428f" />
</p>

### 👴 Elderly Module — "Companion for Seniors"
- Daily medication schedule with one-tap dose confirmation
- Vital signs log: blood pressure, blood sugar, heart rate, weight
- **Automatic danger alert** — a reading past a safe threshold instantly notifies the family
- **Panic Button** — one tap sends GPS location + medical summary to all family members
- Remote family view — children abroad see medication adherence and latest readings
- **Accessibility-first UI** — large fonts, high contrast, simple navigation

<!--
🖼️ SCREENSHOT / IMAGE PLACEHOLDER #8 — ELDERLY MODULE
What to put here: The elderly home screen with the large one-tap "Taken" medication button
and the prominent red Panic Button — this is one of the most visually distinctive screens,
worth showing clearly (large fonts / high contrast UI).
Suggested filename: docs/screenshots/elderly-module.png
-->
<p align="center">
  <img width="1580" height="800" alt="Image" src="https://github.com/user-attachments/assets/8c1b5fa0-7803-4c4c-a2ad-01434362d0d6" />
</p>

### 🏥 Chronic Disease Module — "Disease Management"
- Supports Diabetes, Hypertension, Cardiovascular Disease, and Kidney Disease profiles
- Daily readings log with clinical threshold alerts
- Medication adherence tracker with missed-dose escalation
- Periodic exam reminders (HbA1c every 3 months, kidney function tests, eye exams)
- **Monthly auto-generated clinical summary** ready for doctor visits

<!--
🖼️ SCREENSHOT / IMAGE PLACEHOLDER #9 — CHRONIC DISEASE MODULE
What to put here: The daily vitals logging screen plus the trend chart (e.g. blood sugar
over the last 30 days) — ideally showing a threshold-breach alert banner.
Suggested filename: docs/screenshots/chronic-module.png
-->
<p align="center">
  <img src="docs/screenshots/chronic-module.png" alt="Chronic disease vitals log and trend chart" width="500"/>
</p>

### 💳 Medical Record — "Health Wallet"
- Comprehensive digital medical file for every family member (conditions, allergies, blood type, meds)
- Upload photos of lab results, prescriptions, X-rays, and scan reports
- One-page medical summary **PDF** generated on demand
- **Emergency QR Code** — scanned by paramedics to instantly reveal critical medical data

<!--
🖼️ SCREENSHOT / IMAGE PLACEHOLDER #10 — HEALTH WALLET
What to put here: The medical profile screen and, if possible, the Emergency QR code screen —
these two together sell the "Health Wallet" concept well.
Suggested filename: docs/screenshots/health-wallet.png
-->
<p align="center">
  <img src="docs/screenshots/health-wallet.png" alt="Medical profile and emergency QR code screens" width="500"/>
</p>

### 📅 Family Health Calendar — "Shared Schedule"
- Single calendar aggregating every appointment, vaccine, prenatal test, and checkup
- Admin sees the full family picture; each member sees only their own events
- Smart, automated reminders before every event
- **Color-coded by member** for quick visual scanning

<!--
🖼️ SCREENSHOT / IMAGE PLACEHOLDER #11 — FAMILY CALENDAR
What to put here: The shared family calendar month view, color-coded by member, ideally
with a mix of event types (vaccine, appointment, test) visible at once.
Suggested filename: docs/screenshots/family-calendar.png
-->
<p align="center">
  <img src="docs/screenshots/family-calendar.png" alt="Shared, color-coded family health calendar" width="500"/>
</p>

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| **Framework** | Flutter 3.x (stable channel) |
| **Language** | Dart 3.x |
| **State Management** | BLoC / Cubit |
| **Backend** | Firebase (Auth, Firestore, Cloud Storage, Cloud Messaging) |
| **Platforms** | Android & iOS (Flutter also scaffolds Web, Windows, macOS, Linux) |
| **Testing** | `flutter_test`, `mockito`, `bloc_test`, `integration_test` |
| **Notifications** | Firebase Cloud Messaging (push), scheduled Cloud Functions |
| **PDF & QR Generation** | On-device PDF export, QR encoding for emergency medical data |

---

## 🧱 Project Structure

```
3elty/
├── .vscode/                 # Editor configuration
├── android/                 # Android platform project
├── ios/                     # iOS platform project
├── lib/                     # 🎯 Main Dart application source code
├── linux/                   # Linux platform scaffold
├── macos/                   # macOS platform scaffold
├── test/                    # Unit & widget tests
├── web/                     # Web platform scaffold
├── windows/                 # Windows platform scaffold
├── .gitignore
├── .metadata
├── FIREBASE_SETUP.md         # Firebase configuration guide
├── README.md
├── analysis_options.yaml     # Lint rules
├── pubspec.lock
└── pubspec.yaml              # Dependencies & project metadata
```


---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.x (stable channel)
- Dart 3.x (bundled with Flutter)
- A Firebase project (Auth, Firestore, Storage, and Cloud Messaging enabled)
- Android Studio and/or Xcode for platform builds

### Installation

```bash
# 1. Clone the repository
git clone https://github.com/<your-org>/3elty.git
cd 3elty

# 2. Install dependencies
flutter pub get

# 3. Configure Firebase
# Follow the step-by-step guide in FIREBASE_SETUP.md to add your
# google-services.json (Android) and GoogleService-Info.plist (iOS)

# 4. Run the app
flutter run
```
---

## 👥 Meet the Team

**BitCare Team** is a student team from the Department of Systems and Biomedical Engineering, Cairo University — established as part of the *Software Engineering in Healthcare Course*, and awarded 1st place at Qabilah Hackathon.

| Member | Email | LinKedIn |
|---|---|---|
| Abdullah Gamil Nasr | abdullahgamil285@gmail.com  | https://www.linkedin.com/in/abdullahgamil05/ | 
| Abdulrahman Yasser Gamal Alden | abdulrahmanyasser21211@gmail.com | https://www.linkedin.com/in/ayasser21/ |
| Sohaila Emad Abdelmageed | sohaila.abdelmageed05@eng-st.cu.edu.eg | https://www.linkedin.com/in/sohaila-emad-b1296131a/ |
| Amat Al-Rahman Sayed Mohammed | amatalrahmansayed@gmail.com | https://www.linkedin.com/in/amatalrahman-sayed/ |
| Mariam Mohammed Mohammed | mariam.ahmed05@eng-st.cu.edu.eg | https://www.linkedin.com/in/mariam-mohamed-602688320/ |

---

<div align="center">

**Made with ❤️ for Egyptian families, by the BitCare Team.**

</div>
