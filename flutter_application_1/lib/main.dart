import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'services/remote_auth_service.dart';
import 'screens/family_auth_screen.dart';
import 'screens/admin_member_management_screen.dart';
import 'persistent_dashboard.dart';
import 'widgets/protected_route.dart';
import 'modules/medications_screen.dart';
import 'modules/vitals_screen.dart';
import 'modules/appointments_screen.dart';
import 'modules/documents_screen.dart';
import 'modules/vaccinations_screen.dart';
import 'modules/growth_tracking_screen.dart';
import 'screens/first_time_setup_screen.dart';

// ─── DESIGN TOKENS ───────────────────────────────────────────────────────────
class AppColors {
  static const teal      = Color(0xFF00796B);
  static const tealLight = Color(0xFFE0F2F1);
  static const red       = Color(0xFFD32F2F);
  static const redLight  = Color(0xFFFFEBEE);
  static const green     = Color(0xFF2E7D32);
  static const greenLight= Color(0xFFE8F5E9);
  static const orange    = Color(0xFFE65100);
  static const orangeLight = Color(0xFFFFF3E0);
  static const grey50    = Color(0xFFFAFAFA);
  static const grey100   = Color(0xFFF5F5F5);
  static const grey200   = Color(0xFFEEEEEE);
  static const grey400   = Color(0xFFBDBDBD);
  static const grey500   = Color(0xFF9E9E9E);
  static const grey600   = Color(0xFF757575);
  static const grey900   = Color(0xFF212121);
}

const double kMinTouch = 44.0;

// ─── PROFILE TYPE ────────────────────────────────────────────────────────────
enum ProfileType { child, elderly, pregnant, chronic, adult }

extension ProfileTypeX on ProfileType {
  String get label {
    switch (this) {
      case ProfileType.child:    return 'Child';
      case ProfileType.elderly:  return 'Elderly';
      case ProfileType.pregnant: return 'Pregnant';
      case ProfileType.chronic:  return 'Chronic';
      case ProfileType.adult:    return 'Adult';
    }
  }

  IconData get icon {
    switch (this) {
      case ProfileType.child:    return Icons.child_care_rounded;
      case ProfileType.elderly:  return Icons.elderly_rounded;
      case ProfileType.pregnant: return Icons.pregnant_woman_rounded;
      case ProfileType.chronic:  return Icons.monitor_heart_outlined;
      case ProfileType.adult:    return Icons.person_rounded;
    }
  }

  Color get color {
    switch (this) {
      case ProfileType.child:    return const Color(0xFF1565C0);
      case ProfileType.elderly:  return const Color(0xFF6A1B9A);
      case ProfileType.pregnant: return const Color(0xFFAD1457);
      case ProfileType.chronic:  return const Color(0xFFBF360C);
      case ProfileType.adult:    return AppColors.teal;
    }
  }

  Color get bgColor {
    switch (this) {
      case ProfileType.child:    return const Color(0xFFE3F2FD);
      case ProfileType.elderly:  return const Color(0xFFF3E5F5);
      case ProfileType.pregnant: return const Color(0xFFFCE4EC);
      case ProfileType.chronic:  return const Color(0xFFFBE9E7);
      case ProfileType.adult:    return AppColors.tealLight;
    }
  }
}

// ─── DATA MODELS ─────────────────────────────────────────────────────────────
class FamilyMember {
  final String? id;
  final String name;
  final int age;
  final ProfileType profileType;
  final String? phone;           // ← NEW
 
  const FamilyMember({
    this.id,
    required this.name,
    required this.age,
    required this.profileType,
    this.phone,                  // ← NEW
  });
 
  factory FamilyMember.fromRecord(dynamic r) => FamilyMember(
    id:          r.id as String?,
    name:        r.name,
    age:         r.age,
    profileType: ProfileType.values.firstWhere(
      (p) => p.name == r.profileType,
      orElse: () => ProfileType.adult,
    ),
    phone:       r.phone as String?,   // ← NEW
  );
}

// Health module definition
class HealthModule {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final String? badge; // e.g. "2 due", "Missed today"
  final Color? badgeColor;

  const HealthModule({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.bgColor,
    this.badge,
    this.badgeColor,
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// SCREEN — MEMBER PROFILE HUB
// ═══════════════════════════════════════════════════════════════════════════════
class MemberProfileScreen extends StatelessWidget {
  final FamilyMember member;
  const MemberProfileScreen({super.key, required this.member});

  @override
  Widget build(BuildContext context) {
    final t       = member.profileType;
    final modules = modulesFor(t);

    return Scaffold(
      backgroundColor: AppColors.grey50,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: Colors.white,
            foregroundColor: AppColors.grey900,
            elevation: 0,
            scrolledUnderElevation: 1,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () {},
                tooltip: 'Edit profile',
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: _ProfileHeroHeader(member: member),
            ),
          ),

          if (t == ProfileType.elderly)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _PanicButton(memberName: member.name),
              ),
            ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: _QuickStatsRow(member: member),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: Text(
                '${t.label} Health Modules',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.grey900,
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _ModuleCard(
                  module: modules[i],
                  onTap: () => _onModuleTap(context, modules[i]),
                ),
                childCount: modules.length,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.05,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onModuleTap(BuildContext context, HealthModule module) {
    Widget screen;
    switch (module.id) {
      case 'medications':
        screen = MedicationsScreen(member: member);
        break;
      case 'vitals':
        screen = VitalsScreen(member: member);
        break;
      case 'appointments':
        screen = AppointmentsScreen(member: member);
        break;
      case 'records':
        screen = DocumentsScreen(member: member);
        break;
      case 'vaccines':
        screen = VaccinationsScreen(member: member);
        break;
      case 'growth':
        screen = GrowthTrackingScreen(member: member);
        break;
      case 'prenatal_tests':
      case 'food_safety':
      case 'monthly_report':
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: module.color,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
            content: Row(children: [
              Icon(module.icon, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              const Text('Coming soon…', style: TextStyle(color: Colors.white)),
            ]),
          ),
        );
        return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}

// ─── Profile hero header ──────────────────────────────────────────────────────
class _ProfileHeroHeader extends StatelessWidget {
  final FamilyMember member;
  const _ProfileHeroHeader({required this.member});

  @override
  Widget build(BuildContext context) {
    final t = member.profileType;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: t.bgColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: t.color.withOpacity(0.25), width: 2),
            ),
            child: Icon(t.icon, color: t.color, size: 36),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(member.name,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                        color: AppColors.grey900)),
                const SizedBox(height: 6),
                Row(children: [
                  _ProfileChip(label: t.label, color: t.color, bgColor: t.bgColor),
                  const SizedBox(width: 8),
                  _ProfileChip(
                    label: '${member.age} yrs',
                    color: AppColors.grey600,
                    bgColor: AppColors.grey100,
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color bgColor;
  const _ProfileChip({required this.label, required this.color, required this.bgColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

// ─── Quick stats row ──────────────────────────────────────────────────────────
class _QuickStatsRow extends StatelessWidget {
  final FamilyMember member;
  const _QuickStatsRow({required this.member});

  @override
  Widget build(BuildContext context) {
    final stats = _statsFor(member.profileType);
    return Row(
      children: stats.map((s) => Expanded(
        child: Padding(
          padding: EdgeInsets.only(right: s != stats.last ? 10 : 0),
          child: _StatTile(stat: s),
        ),
      )).toList(),
    );
  }

  List<_StatData> _statsFor(ProfileType t) {
    switch (t) {
      case ProfileType.child:
        return [
          _StatData('Vaccines', '8/12', Icons.vaccines_rounded, AppColors.teal),
          _StatData('Next visit', '3 days', Icons.calendar_today_rounded, AppColors.orange),
        ];
      case ProfileType.elderly:
        return [
          _StatData('Medications', '0/3 today', Icons.medication_rounded, AppColors.red),
          _StatData('Last check', '2 hrs ago', Icons.access_time_rounded, AppColors.teal),
        ];
      case ProfileType.pregnant:
        return [
          _StatData('Trimester', '2nd', Icons.pregnant_woman_rounded,
              const Color(0xFFAD1457)),
          _StatData('Next test', 'Week 28', Icons.science_rounded, AppColors.orange),
        ];
      case ProfileType.chronic:
        return [
          _StatData('Vitals', 'Not logged', Icons.monitor_heart_rounded, AppColors.orange),
          _StatData('Adherence', '87%', Icons.medication_rounded, AppColors.green),
        ];
      case ProfileType.adult:
        return [
          _StatData('Next visit', 'None set', Icons.calendar_today_rounded, AppColors.teal),
          _StatData('Records', '2 docs', Icons.folder_rounded, AppColors.teal),
        ];
    }
  }
}

class _StatData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatData(this.label, this.value, this.icon, this.color);
}

class _StatTile extends StatelessWidget {
  final _StatData stat;
  const _StatTile({required this.stat});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(stat.icon, size: 20, color: stat.color),
          const SizedBox(height: 8),
          Text(stat.value,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: stat.color)),
          const SizedBox(height: 2),
          Text(stat.label,
              style: const TextStyle(fontSize: 12, color: AppColors.grey600)),
        ],
      ),
    );
  }
}

// ─── Panic button (elderly only) ──────────────────────────────────────────────
class _PanicButton extends StatelessWidget {
  final String memberName;
  const _PanicButton({required this.memberName});

  void _confirm(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(color: AppColors.redLight, shape: BoxShape.circle),
          child: const Icon(Icons.sos_rounded, color: AppColors.red, size: 32),
        ),
        title: const Text('Send emergency alert?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        content: Text(
          "This will broadcast $memberName's GPS location to ALL family members.\n\nOnly use in a real emergency.",
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, color: AppColors.grey600, height: 1.5),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          Column(children: [
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, kMinTouch),
                  side: const BorderSide(color: AppColors.grey200),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: AppColors.grey900)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.red,
                  minimumSize: const Size(double.infinity, kMinTouch),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  HapticFeedback.heavyImpact();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    backgroundColor: AppColors.red,
                    duration: const Duration(seconds: 5),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    content: const Row(children: [
                      Icon(Icons.check_circle_rounded, color: Colors.white),
                      SizedBox(width: 12),
                      Expanded(child: Text('Emergency alert sent to all family members',
                          style: TextStyle(color: Colors.white))),
                    ]),
                  ));
                },
                child: const Text('Yes, send SOS',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.redLight,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _confirm(context),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: AppColors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.sos_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Emergency Panic Button',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                        color: AppColors.red)),
                SizedBox(height: 2),
                Text('Broadcasts GPS to all family members',
                    style: TextStyle(fontSize: 13, color: AppColors.grey600)),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.red),
          ]),
        ),
      ),
    );
  }
}

// ─── Module card ──────────────────────────────────────────────────────────────
class _ModuleCard extends StatelessWidget {
  final HealthModule module;
  final VoidCallback onTap;
  const _ModuleCard({required this.module, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: module.bgColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(module.icon, color: module.color, size: 22),
                  ),
                  if (module.badge != null) ...[
                    const SizedBox(width: 6),
                    Expanded(
                      child: Align(
                        alignment: Alignment.topRight,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: (module.badgeColor ?? module.color).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            module.badge!,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: module.badgeColor ?? module.color,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const Spacer(),
              Text(module.title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                      color: AppColors.grey900),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(module.subtitle,
                  style: const TextStyle(fontSize: 11, color: AppColors.grey600, height: 1.4),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── MODULE DEFINITIONS PER PROFILE TYPE ─────────────────────────────────────
List<HealthModule> modulesFor(ProfileType type) {
  switch (type) {
    case ProfileType.child:
      return const [
        HealthModule(
          id: 'vaccines',
          title: 'Vaccination Schedule',
          subtitle: "Egypt MOH calendar with digital booklet",
          icon: Icons.vaccines_rounded,
          color: Color(0xFF1565C0),
          bgColor: Color(0xFFE3F2FD),
          badge: '2 due soon',
          badgeColor: Color(0xFFE65100),
        ),
        HealthModule(
          id: 'growth',
          title: 'Growth Tracking',
          subtitle: 'Weight & height vs WHO percentiles',
          icon: Icons.show_chart_rounded,
          color: Color(0xFF1565C0),
          bgColor: Color(0xFFE3F2FD),
        ),
        HealthModule(
          id: 'appointments',
          title: 'Appointments',
          subtitle: 'Pediatric visits & reminders',
          icon: Icons.calendar_month_rounded,
          color: Color(0xFF1565C0),
          bgColor: Color(0xFFE3F2FD),
        ),
        HealthModule(
          id: 'records',
          title: 'Medical Records',
          subtitle: 'Lab results, prescriptions & profile',
          icon: Icons.folder_special_rounded,
          color: Color(0xFF1565C0),
          bgColor: Color(0xFFE3F2FD),
        ),
      ];

    case ProfileType.elderly:
      return const [
        HealthModule(
          id: 'medications',
          title: 'Medication Confirmation',
          subtitle: 'One-tap daily dose tracking',
          icon: Icons.medication_rounded,
          color: Color(0xFF6A1B9A),
          bgColor: Color(0xFFF3E5F5),
          badge: 'Missed today',
          badgeColor: AppColors.red,
        ),
        HealthModule(
          id: 'vitals',
          title: 'Vital Signs',
          subtitle: 'Blood pressure, glucose & more',
          icon: Icons.favorite_rounded,
          color: Color(0xFF6A1B9A),
          bgColor: Color(0xFFF3E5F5),
        ),
        HealthModule(
          id: 'appointments',
          title: 'Appointments',
          subtitle: 'Doctor visits & follow-ups',
          icon: Icons.calendar_month_rounded,
          color: Color(0xFF6A1B9A),
          bgColor: Color(0xFFF3E5F5),
        ),
        HealthModule(
          id: 'records',
          title: 'Medical Records',
          subtitle: 'Profile, conditions & documents',
          icon: Icons.folder_special_rounded,
          color: Color(0xFF6A1B9A),
          bgColor: Color(0xFFF3E5F5),
        ),
      ];

    case ProfileType.pregnant:
      return const [
        HealthModule(
          id: 'prenatal_tests',
          title: 'Prenatal Tests',
          subtitle: 'Trimester checklist with reminders',
          icon: Icons.science_rounded,
          color: Color(0xFFAD1457),
          bgColor: Color(0xFFFCE4EC),
          badge: 'Week 28 due',
          badgeColor: Color(0xFFE65100),
        ),
        HealthModule(
          id: 'medications',
          title: 'Prenatal Medications',
          subtitle: 'Folic acid, iron, calcium tracking',
          icon: Icons.medication_rounded,
          color: Color(0xFFAD1457),
          bgColor: Color(0xFFFCE4EC),
        ),
        HealthModule(
          id: 'food_safety',
          title: 'Food Safety Guide',
          subtitle: 'Safe & unsafe local Egyptian dishes',
          icon: Icons.restaurant_rounded,
          color: Color(0xFFAD1457),
          bgColor: Color(0xFFFCE4EC),
        ),
        HealthModule(
          id: 'appointments',
          title: 'Appointments',
          subtitle: 'OB/GYN visits & ultrasounds',
          icon: Icons.calendar_month_rounded,
          color: Color(0xFFAD1457),
          bgColor: Color(0xFFFCE4EC),
        ),
        HealthModule(
          id: 'records',
          title: 'Medical Records',
          subtitle: 'Pregnancy docs & test results',
          icon: Icons.folder_special_rounded,
          color: Color(0xFFAD1457),
          bgColor: Color(0xFFFCE4EC),
        ),
      ];

    case ProfileType.chronic:
      return const [
        HealthModule(
          id: 'vitals',
          title: 'Vital Signs Logger',
          subtitle: 'Blood sugar, blood pressure & trends',
          icon: Icons.monitor_heart_rounded,
          color: Color(0xFFBF360C),
          bgColor: Color(0xFFFBE9E7),
          badge: 'Log today',
          badgeColor: AppColors.orange,
        ),
        HealthModule(
          id: 'medications',
          title: 'Medication Adherence',
          subtitle: 'Daily dose tracker & missed-dose alerts',
          icon: Icons.medication_rounded,
          color: Color(0xFFBF360C),
          bgColor: Color(0xFFFBE9E7),
        ),
        HealthModule(
          id: 'monthly_report',
          title: 'Monthly Clinical Summary',
          subtitle: 'Auto-generated PDF for doctor visits',
          icon: Icons.summarize_rounded,
          color: Color(0xFFBF360C),
          bgColor: Color(0xFFFBE9E7),
        ),
        HealthModule(
          id: 'appointments',
          title: 'Appointments',
          subtitle: 'Specialist follow-ups & lab tests',
          icon: Icons.calendar_month_rounded,
          color: Color(0xFFBF360C),
          bgColor: Color(0xFFFBE9E7),
        ),
        HealthModule(
          id: 'records',
          title: 'Medical Records',
          subtitle: 'Conditions, allergies & lab results',
          icon: Icons.folder_special_rounded,
          color: Color(0xFFBF360C),
          bgColor: Color(0xFFFBE9E7),
        ),
      ];

    case ProfileType.adult:
      return const [
        HealthModule(
          id: 'appointments',
          title: 'Appointments',
          subtitle: 'Schedule & track doctor visits',
          icon: Icons.calendar_month_rounded,
          color: AppColors.teal,
          bgColor: AppColors.tealLight,
        ),
        HealthModule(
          id: 'medications',
          title: 'Medications',
          subtitle: 'Track prescriptions & doses',
          icon: Icons.medication_rounded,
          color: AppColors.teal,
          bgColor: AppColors.tealLight,
        ),
        HealthModule(
          id: 'records',
          title: 'Medical Records',
          subtitle: 'Profile, documents & history',
          icon: Icons.folder_special_rounded,
          color: AppColors.teal,
          bgColor: AppColors.tealLight,
        ),
      ];
  }
}

// ─── APP ─────────────────────────────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print('Firebase initialization error: $e');
  }

  runApp(const E3ltyApp());
}

class E3ltyApp extends StatelessWidget {
  const E3ltyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '3elty',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: AppColors.teal,
        scaffoldBackgroundColor: AppColors.grey50,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.grey200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.grey200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.teal, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.red),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.red, width: 2),
          ),
          labelStyle: const TextStyle(color: AppColors.grey600),
          floatingLabelStyle: const TextStyle(
            color: AppColors.teal,
            fontWeight: FontWeight.w500,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.teal,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, kMinTouch + 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.grey900,
          elevation: 0,
          scrolledUnderElevation: 1,
          titleTextStyle: TextStyle(
            color: AppColors.grey900,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          iconTheme: IconThemeData(color: AppColors.grey900),
        ),
      ),
      home: const _AuthWrapper(),
      routes: {
        '/persistent_dashboard': (context) => const FamilyDashboard(),
        '/admin_member_management': (context) => ProtectedRoute(
          requiredRole: 'admin',
          child: const AdminMemberManagementScreen(),
        ),
        '/first_time_setup': (context) => const FirstTimeSetupScreen(),
        '/login': (context) => const FamilyAuthScreen(),
      },
    );
  }
}

class _AuthWrapper extends StatefulWidget {
  const _AuthWrapper();

  @override
  State<_AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<_AuthWrapper> {
  final _authService = RemoteAuthService();
  Widget? _destination;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final isSignedIn = await _authService.isSignedIn();
    final role = await _authService.userRole;

    Widget dest;
    if (isSignedIn && role == 'admin') {
      dest = const FamilyDashboard();
    } else if (isSignedIn && role == 'member') {
      final userId = await _authService.userId ?? '';
      final familyId = await _authService.familyId ?? '';
      final shouldAsk = await shouldAskPinThisLogin(userId);
      if (shouldAsk) {
        dest = PinCheckScreen(phone: userId, familyId: familyId);
      } else {
        dest = const FamilyDashboard();
      }
    } else {
      dest = const FamilyAuthScreen();
    }

    if (mounted) setState(() => _destination = dest);
  }

  @override
  Widget build(BuildContext context) {
    if (_destination == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.teal),
        ),
      );
    }
    return _destination!;
  }
}

