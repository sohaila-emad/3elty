import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'firebase_options.dart';
import 'modules/food_safety_screen.dart';
import 'modules/pregnancy_medications_screen.dart';
import 'modules/ultrasound_log_screen.dart';
import 'services/remote_auth_service.dart';
import 'screens/family_auth_screen.dart';
import 'screens/admin_member_management_screen.dart';
import 'screens/member_pin_login_screen.dart';
import 'screens/member_setup_screen.dart';
import 'screens/member_access_validation_dialog.dart';
import 'screens/security_audit_screen.dart';
import 'persistent_dashboard.dart';
import 'widgets/protected_route.dart';
import 'modules/medications_screen.dart';
import 'modules/vitals_screen.dart';
import 'modules/appointments_screen.dart';
import 'modules/documents_screen.dart';
import 'modules/vaccinations_screen.dart';
import 'modules/growth_tracking_screen.dart';
import 'screens/admin_family_calendar_screen.dart';
import 'modules/family_calendar_screen.dart';
import 'modules/pregnancy_module_screen.dart';
import 'screens/first_time_setup_screen.dart';
import 'screens/pin_check_screen.dart';
import 'services/notification_helper.dart';
import 'services/report_service.dart';
import 'services/vital_alert_service.dart';
import 'services/medication_service.dart';
import 'services/pdf_service.dart';
import 'services/document_file_helper.dart';
import 'utils/auth_helpers.dart';
import 'data/models/calendar_event.dart';


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
      case ProfileType.child:    return 'طفل';
      case ProfileType.elderly:  return 'كبير سن';
      case ProfileType.pregnant: return 'حامل';
      case ProfileType.chronic:  return 'مريض مزمن';
      case ProfileType.adult:    return 'بالغ';
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
  final String? phone;

  const FamilyMember({
    this.id,
    required this.name,
    required this.age,
    required this.profileType,
    this.phone,
  });

  factory FamilyMember.fromRecord(dynamic r) => FamilyMember(
    id:          r.id as String?,
    name:        r.name,
    age:         r.age,
    profileType: ProfileType.values.firstWhere(
      (p) => p.name == r.profileType,
      orElse: () => ProfileType.adult,
    ),
    phone: r.phone as String?,
  );

  /// عرض العمر بالعربي — يُستخدم في ReportService وغيره
  /// للطفل: العمر مخزّن بالشهور دائماً في قاعدة البيانات
  String get formattedAge {
    if (profileType == ProfileType.child) {
      // العمر مخزّن بالشهور للطفل
      if (age == 0) return 'أقل من شهر';
      if (age < 12) return '$age شهراً';
      final years = age ~/ 12;
      final months = age % 12;
      if (months == 0) return '$years سنة';
      return '$years سنة و$months شهراً';
    }
    if (age == 0) return 'أقل من سنة';
    return '$age سنة';
  }
}

// Health module definition
class HealthModule {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final String? badge;
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

// ─── MODULE DEFINITIONS PER PROFILE TYPE ─────────────────────────────────────
List<HealthModule> modulesFor(ProfileType type) {
  switch (type) {
    case ProfileType.child:
      return const [
        HealthModule(
          id: 'vaccines',
          title: 'جدول التطعيمات',
          subtitle: 'تقويم وزارة الصحة مع الدفتر الرقمي',
          icon: Icons.vaccines_rounded,
          color: Color(0xFF1565C0),
          bgColor: Color(0xFFE3F2FD),
          badge: 'موعدان قريباً',
          badgeColor: Color(0xFFE65100),
        ),
        HealthModule(
          id: 'growth',
          title: 'تتبع النمو',
          subtitle: 'الوزن والطول مقارنةً بمعايير منظمة الصحة',
          icon: Icons.show_chart_rounded,
          color: Color(0xFF1565C0),
          bgColor: Color(0xFFE3F2FD),
        ),
        HealthModule(
          id: 'appointments',
          title: 'المواعيد',
          subtitle: 'زيارات طبيب الأطفال والتذكيرات',
          icon: Icons.calendar_month_rounded,
          color: Color(0xFF1565C0),
          bgColor: Color(0xFFE3F2FD),
        ),
        HealthModule(
          id: 'records',
          title: 'السجلات الطبية',
          subtitle: 'نتائج التحاليل والوصفات والملف الشخصي',
          icon: Icons.folder_special_rounded,
          color: Color(0xFF1565C0),
          bgColor: Color(0xFFE3F2FD),
        ),
      ];

    case ProfileType.elderly:
      return const [
        HealthModule(
          id: 'medications',
          title: 'تأكيد الدواء',
          subtitle: 'تتبع الجرعة اليومية بنقرة واحدة',
          icon: Icons.medication_rounded,
          color: Color(0xFF6A1B9A),
          bgColor: Color(0xFFF3E5F5),
          badge: 'فاتتك اليوم',
          badgeColor: AppColors.red,
        ),
        HealthModule(
          id: 'vitals',
          title: 'العلامات الحيوية',
          subtitle: 'ضغط الدم والسكر والمزيد',
          icon: Icons.favorite_rounded,
          color: Color(0xFF6A1B9A),
          bgColor: Color(0xFFF3E5F5),
        ),
        HealthModule(
          id: 'appointments',
          title: 'المواعيد',
          subtitle: 'زيارات الأطباء والمتابعات',
          icon: Icons.calendar_month_rounded,
          color: Color(0xFF6A1B9A),
          bgColor: Color(0xFFF3E5F5),
        ),
        HealthModule(
          id: 'records',
          title: 'السجلات الطبية',
          subtitle: 'الملف الشخصي والحالات والوثائق',
          icon: Icons.folder_special_rounded,
          color: Color(0xFF6A1B9A),
          bgColor: Color(0xFFF3E5F5),
        ),
      ];

    case ProfileType.pregnant:
      return const [
        HealthModule(
          id: 'prenatal_tests',
          title: 'فحوصات ما قبل الولادة',
          subtitle: 'قائمة التحقق الثلاثية مع التذكيرات',
          icon: Icons.science_rounded,
          color: Color(0xFFAD1457),
          bgColor: Color(0xFFFCE4EC),
          badge: 'الأسبوع 28',
          badgeColor: Color(0xFFE65100),
        ),
        HealthModule(
          id: 'medications',
          title: 'أدوية الحمل',
          subtitle: 'تتبع حمض الفوليك والحديد والكالسيوم',
          icon: Icons.medication_rounded,
          color: Color(0xFFAD1457),
          bgColor: Color(0xFFFCE4EC),
        ),
        HealthModule(
          id: 'food_safety',
          title: 'دليل الأغذية الآمنة',
          subtitle: 'الأطعمة المصرية الآمنة وغير الآمنة',
          icon: Icons.restaurant_rounded,
          color: Color(0xFFAD1457),
          bgColor: Color(0xFFFCE4EC),
        ),
        HealthModule(
          id: 'appointments',
          title: 'المواعيد',
          subtitle: 'زيارات طبيب النساء والسونار',
          icon: Icons.calendar_month_rounded,
          color: Color(0xFFAD1457),
          bgColor: Color(0xFFFCE4EC),
        ),
        HealthModule(
          id: 'records',
          title: 'السجلات الطبية',
          subtitle: 'وثائق الحمل ونتائج التحاليل',
          icon: Icons.folder_special_rounded,
          color: Color(0xFFAD1457),
          bgColor: Color(0xFFFCE4EC),
        ),
        HealthModule(
          id: 'vitals', // نفس الـ ID اللي ضفناه في الـ switch
          title: 'العلامات الحيوية',
          subtitle: 'تتبع الضغط والسكر والوزن أثناء الحمل',
          icon: Icons.favorite_rounded,
          color: Color(0xFFAD1457),
          bgColor: Color(0xFFFCE4EC),
    ),
      ];

    case ProfileType.chronic:
      return const [
        HealthModule(
          id: 'vitals',
          title: 'تسجيل العلامات الحيوية',
          subtitle: 'سكر الدم وضغط الدم والاتجاهات',
          icon: Icons.monitor_heart_rounded,
          color: Color(0xFFBF360C),
          bgColor: Color(0xFFFBE9E7),
          badge: 'سجّل اليوم',
          badgeColor: AppColors.orange,
        ),
        HealthModule(
          id: 'medications',
          title: 'الالتزام بالدواء',
          subtitle: 'تتبع الجرعة اليومية وتنبيهات الجرعات الفائتة',
          icon: Icons.medication_rounded,
          color: Color(0xFFBF360C),
          bgColor: Color(0xFFFBE9E7),
        ),
        HealthModule(
          id: 'monthly_report',
          title: 'الملخص السريري الشهري',
          subtitle: 'PDF تلقائي لزيارات الطبيب',
          icon: Icons.summarize_rounded,
          color: Color(0xFFBF360C),
          bgColor: Color(0xFFFBE9E7),
        ),
        HealthModule(
          id: 'appointments',
          title: 'المواعيد',
          subtitle: 'متابعات الأخصائيين وتحاليل المختبر',
          icon: Icons.calendar_month_rounded,
          color: Color(0xFFBF360C),
          bgColor: Color(0xFFFBE9E7),
        ),
        HealthModule(
          id: 'records',
          title: 'السجلات الطبية',
          subtitle: 'الحالات والحساسية ونتائج التحاليل',
          icon: Icons.folder_special_rounded,
          color: Color(0xFFBF360C),
          bgColor: Color(0xFFFBE9E7),
        ),
      ];

    case ProfileType.adult:
      return const [
        HealthModule(
          id: 'appointments',
          title: 'المواعيد',
          subtitle: 'جدولة زيارات الأطباء وتتبعها',
          icon: Icons.calendar_month_rounded,
          color: AppColors.teal,
          bgColor: AppColors.tealLight,
        ),
        HealthModule(
          id: 'medications',
          title: 'الأدوية',
          subtitle: 'تتبع الوصفات والجرعات',
          icon: Icons.medication_rounded,
          color: AppColors.teal,
          bgColor: AppColors.tealLight,
        ),
        HealthModule(
          id: 'records',
          title: 'السجلات الطبية',
          subtitle: 'الملف الشخصي والوثائق والتاريخ المرضي',
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
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

  runApp(const E3ltyApp());
}

class E3ltyApp extends StatelessWidget {
  const E3ltyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'عيلتي',
      locale: const Locale('ar', 'EG'),
      supportedLocales: const [Locale('ar', 'EG')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: AppColors.teal,
        scaffoldBackgroundColor: AppColors.grey50,
        fontFamily: 'Roboto',
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
        '/admin_family_calendar': (context) => ProtectedRoute(
          requiredRole: 'admin',
          child: const AdminFamilyCalendarScreen(),
        ),
        '/member_pin_login': (context) => const MemberPinLoginScreen(),
        '/first_time_setup': (context) => const FirstTimeSetupScreen(),
        '/login': (context) => const FamilyAuthScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/security_audit') {
          final args = settings.arguments as Map<String, String>?;
          return MaterialPageRoute(
            builder: (context) => ProtectedRoute(
              requiredRole: 'admin',
              child: SecurityAuditScreen(
                memberId: args?['memberId'] ?? '',
                memberName: args?['memberName'] ?? '',
              ),
            ),
          );
        }
        if (settings.name == '/member_setup') {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (context) => MemberSetupScreen(
              newMemberId: args?['newMemberId'] ?? '',
              newMemberName: args?['newMemberName'] ?? '',
              newMemberAge: args?['newMemberAge'] ?? 0,
              familyId: args?['familyId'] ?? '',
            ),
          );
        }
        if (settings.name == '/pin_check') {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (context) => PinCheckScreen(
              phone: args?['phone'] ?? '',
              familyId: args?['familyId'] ?? '',
            ),
          );
        }
        return null;
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
  late Future<bool> _authCheckFuture;
  final _authService = RemoteAuthService();

  @override
  void initState() {
    super.initState();
    _authCheckFuture = _authService.isSignedIn();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _authCheckFuture,
      builder: (ctx, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppColors.teal),
            ),
          );
        }
        final isSignedIn = snapshot.data ?? false;
        return isSignedIn ? const FamilyDashboard() : const FamilyAuthScreen();
      },
    );
  }
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
                tooltip: 'تعديل الملف',
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
                'وحدات صحة ${t.label}',
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
                childAspectRatio: 0.85
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
          // هنا بنفتح الشاشة المخصصة للحوامل اللي إنتِ تعبتي فيها
          if (member.profileType == ProfileType.pregnant) {
            screen = PregnancyMedicationsScreen(member: member);
          } else {
            screen = MedicationsScreen(member: member);
          }
          break;

        case 'food_safety':
          screen = const FoodSafetyScreen();
          break;

        case 'prenatal_tests':
          screen = UltrasoundLogScreen(member: member);
          break;

        // ... باقي الحالات (vitals, growth, etc.)
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

        case 'monthly_report':
          // يفتح خدمة التقرير الشهري PDF
          if (member.id != null) {
            ReportService.instance.generateAndShare(
              member: member,
              memberId: member.id!,
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تعذّر إنشاء التقرير: معرّف العضو غير متاح')),
            );
          }
          return;

        case 'family_calendar':
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => FamilyCalendarScreen(familyMembers: const []),
          ));
          return;

        case 'pregnancy_module':
          screen = PregnancyModuleScreen(member: member);
          break;

        default:
          // لو مفيش شاشة مربوطة هيطلع SnackBar
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('قريباً…')),
          );
          return;
      }
      
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    }
}

// ─── Profile hero header widget ───────────────────────────────────────────────
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
              border: Border.all(color: t.color.withValues(alpha: 0.25), width: 2),
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
                    label: '${member.age} سنة',
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
          padding: EdgeInsets.only(left: s != stats.last ? 10 : 0),
          child: _StatTile(stat: s),
        ),
      )).toList(),
    );
  }

  List<_StatData> _statsFor(ProfileType t) {
    switch (t) {
      case ProfileType.child:
        return [
          _StatData('التطعيمات', '٨/١٢', Icons.vaccines_rounded, AppColors.teal),
          _StatData('الزيارة القادمة', 'بعد ٣ أيام', Icons.calendar_today_rounded, AppColors.orange),
        ];
      case ProfileType.elderly:
        return [
          _StatData('الأدوية', '٠/٣ اليوم', Icons.medication_rounded, AppColors.red),
          _StatData('آخر فحص', 'منذ ساعتين', Icons.access_time_rounded, AppColors.teal),
        ];
      case ProfileType.pregnant:
        return [
          _StatData('الثلث', 'الثاني', Icons.pregnant_woman_rounded,
              const Color(0xFFAD1457)),
          _StatData('الفحص القادم', 'الأسبوع ٢٨', Icons.science_rounded, AppColors.orange),
        ];
      case ProfileType.chronic:
        return [
          _StatData('العلامات الحيوية', 'لم تُسجَّل', Icons.monitor_heart_rounded, AppColors.orange),
          _StatData('الالتزام', '٨٧٪', Icons.medication_rounded, AppColors.green),
        ];
      case ProfileType.adult:
        return [
          _StatData('الزيارة القادمة', 'لم تُحدَّد', Icons.calendar_today_rounded, AppColors.teal),
          _StatData('السجلات', 'وثيقتان', Icons.folder_rounded, AppColors.teal),
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
        title: const Text('إرسال تنبيه طارئ؟',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        content: Text(
          'سيتم بث موقع $memberName الجغرافي لجميع أفراد العائلة.\n\nاستخدم هذا في حالات الطوارئ الحقيقية فقط.',
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
                child: const Text('إلغاء', style: TextStyle(color: AppColors.grey900)),
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
                      Expanded(child: Text('تم إرسال تنبيه الطوارئ لجميع أفراد العائلة',
                          style: TextStyle(color: Colors.white))),
                    ]),
                  ));
                },
                child: const Text('نعم، أرسل SOS',
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
                Text('زر الطوارئ',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                        color: AppColors.red)),
                SizedBox(height: 2),
                Text('يبث الموقع الجغرافي لجميع أفراد العائلة',
                    style: TextStyle(fontSize: 13, color: AppColors.grey600)),
              ]),
            ),
            const Icon(Icons.chevron_left_rounded, color: AppColors.red),
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
                        alignment: Alignment.topLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: (module.badgeColor ?? module.color).withValues(alpha: 0.12),
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
                  style: const TextStyle(fontSize: 10,color: AppColors.grey600, height: 1.4),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}