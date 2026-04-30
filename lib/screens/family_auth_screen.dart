import 'package:flutter/material.dart';
import '../main.dart';
import '../services/remote_auth_service.dart';
import '../services/firestore_service.dart';
import '../persistent_dashboard.dart';
import '../services/notification_helper.dart';

/// Single screen that handles both sign-up and sign-in for a family.
class FamilyAuthScreen extends StatefulWidget {
  const FamilyAuthScreen({super.key});

  @override
  State<FamilyAuthScreen> createState() => _FamilyAuthScreenState();
}

class _FamilyAuthScreenState extends State<FamilyAuthScreen> {
  final _authService = RemoteAuthService.instance;
  final _firestoreService = FirestoreService.instance;

  // ── controllers ────────────────────────────────────────────────────────────
  final _familyUsernameCtrl = TextEditingController();
  final _familyPasswordCtrl = TextEditingController();
  final _displayNameCtrl = TextEditingController(); // sign-up only
  final _adminPasswordCtrl = TextEditingController(); // sign-up only

  bool _isSignUp = false;
  bool _loading = false;
  bool _obscureFamilyPwd = true;
  bool _obscureAdminPwd = true;

  @override
  void dispose() {
    _familyUsernameCtrl.dispose();
    _familyPasswordCtrl.dispose();
    _displayNameCtrl.dispose();
    _adminPasswordCtrl.dispose();
    super.dispose();
  }

  // ── helpers ─────────────────────────────────────────────────────────────────
  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: Text(msg, style: const TextStyle(color: Colors.white)),
    ));
  }

  // Future<void> _submit() async {
  //   final username = _familyUsernameCtrl.text.trim();
  //   final familyPwd = _familyPasswordCtrl.text;

  //   if (username.isEmpty || familyPwd.isEmpty) {
  //     _showError('يرجى تعبئة جميع الحقول المطلوبة');
  //     return;
  //   }

  //   setState(() => _loading = true);

  //   try {
  //     if (_isSignUp) {
  //       // ── sign up ──────────────────────────────────────────────────────────
  //       final displayName = _displayNameCtrl.text.trim();
  //       final adminPwd = _adminPasswordCtrl.text;

  //       if (displayName.isEmpty || adminPwd.isEmpty) {
  //         _showError('يرجى تعبئة جميع الحقول');
  //         setState(() => _loading = false);
  //         return;
  //       }

  //       await _authService.signUpFamily(
  //         familyUsername: username,
  //         displayName: displayName,
  //         familyPassword: familyPwd,
  //         adminPassword: adminPwd,
  //       );
  //     } else {
  //       // ── sign in ──────────────────────────────────────────────────────────
  //       await _authService.signInFamily(
  //         familyUsername: username,
  //         familyPassword: familyPwd,
  //       );

  //       // Sync data from Firestore to local DB
  //       try {
  //         await _firestoreService.syncFamilyData();
  //       } catch (_) {
  //         // Non-fatal – continue even if sync fails
  //       }
  //     }

  //     // if (!mounted) return;
  //     // Navigator.of(context).pushReplacement(
  //     //   MaterialPageRoute(builder: (_) => const FamilyDashboard()),
  //     // );
  //     // ... الكود السابق في دالة _submit

  //   } catch (e) {
  //     if (!mounted) return;
  //     _showError(e.toString().replaceFirst('Exception: ', ''));
  //   } finally {
  //     if (mounted) setState(() => _loading = false);
  //   }
  // }

  Future<void> _submit() async {
    final username = _familyUsernameCtrl.text.trim();
    final familyPwd = _familyPasswordCtrl.text;
    // سحب قيمة اسم العائلة هنا لضمان توفرها في كل الحالات
    final currentDisplayName = _displayNameCtrl.text.trim();

    if (username.isEmpty || familyPwd.isEmpty) {
      _showError('يرجى تعبئة جميع الحقول المطلوبة');
      return;
    }

    setState(() => _loading = true);

    try {
      if (_isSignUp) {
        final adminPwd = _adminPasswordCtrl.text;

        if (currentDisplayName.isEmpty || adminPwd.isEmpty) {
          _showError('يرجى تعبئة جميع الحقول');
          setState(() => _loading = false);
          return;
        }

        await _authService.signUpFamily(
          familyUsername: username,
          displayName: currentDisplayName,
          familyPassword: familyPwd,
          adminPassword: adminPwd,
        );
      } else {
        await _authService.signInFamily(
          familyUsername: username,
          familyPassword: familyPwd,
        );

        try {
          await _firestoreService.syncFamilyData();
        } catch (_) {}
      }

      if (!mounted) return;

      // ── إرسال الإشعار باستخدام المتغير الصحيح ──────────────────────────────
      // نستخدم اسم العائلة إذا وجد، وإلا نستخدم اسم المستخدم
      final nameToShow = currentDisplayName.isNotEmpty ? currentDisplayName : username;

      await NotificationHelper.instance.notifyVaccinationLogged(
        memberName: nameToShow,
        vaccineName: 'تم تفعيل نظام التنبيهات بنجاح 🔔',
      );
      // ────────────────────────────────────────────────────────────────────────

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const FamilyDashboard()),
      );
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey50,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Logo / header ──────────────────────────────────────────────
              Center(
                child: Column(children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.teal,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(Icons.family_restroom_rounded,
                        color: Colors.white, size: 42),
                  ),
                  const SizedBox(height: 16),
                  const Text('عيلتي',
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.grey900)),
                  const SizedBox(height: 6),
                  Text(
                    _isSignUp
                        ? 'أنشئ حساب عائلتك'
                        : 'مرحباً بك مجدداً',
                    style: const TextStyle(
                        fontSize: 15, color: AppColors.grey600),
                  ),
                ]),
              ),
              const SizedBox(height: 40),

              // ── Form ──────────────────────────────────────────────────────
              if (_isSignUp) ...[
                _buildField(
                  controller: _displayNameCtrl,
                  label: 'اسم العائلة',
                  hint: 'مثال: عائلة محمد',
                  icon: Icons.group_rounded,
                ),
                const SizedBox(height: 16),
              ],

              _buildField(
                controller: _familyUsernameCtrl,
                label: 'اسم المستخدم للعائلة',
                hint: 'مثال: family_ali',
                icon: Icons.badge_rounded,
              ),
              const SizedBox(height: 16),

              _buildPasswordField(
                controller: _familyPasswordCtrl,
                label: 'كلمة مرور العائلة',
                obscure: _obscureFamilyPwd,
                onToggle: () =>
                    setState(() => _obscureFamilyPwd = !_obscureFamilyPwd),
              ),

              if (_isSignUp) ...[
                const SizedBox(height: 16),
                _buildPasswordField(
                  controller: _adminPasswordCtrl,
                  label: 'كلمة مرور المسؤول',
                  obscure: _obscureAdminPwd,
                  onToggle: () =>
                      setState(() => _obscureAdminPwd = !_obscureAdminPwd),
                ),
                const SizedBox(height: 8),
                const Text(
                  'كلمة مرور المسؤول تُستخدم لإدارة أفراد العائلة وصلاحياتهم.',
                  style: TextStyle(fontSize: 12, color: AppColors.grey500),
                ),
              ],

              const SizedBox(height: 32),

              // ── Submit button ─────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white),
                        )
                      : Text(_isSignUp ? 'إنشاء الحساب' : 'تسجيل الدخول'),
                ),
              ),

              const SizedBox(height: 20),

              // ── Toggle sign-up / sign-in ──────────────────────────────────
              Center(
                child: TextButton(
                  onPressed: () => setState(() => _isSignUp = !_isSignUp),
                  child: Text(
                    _isSignUp
                        ? 'لديك حساب بالفعل؟ تسجيل الدخول'
                        : 'عائلة جديدة؟ إنشاء حساب',
                    style: const TextStyle(color: AppColors.teal),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.grey500, size: 20),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.grey200)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.grey200)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.teal, width: 2)),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon:
            const Icon(Icons.lock_rounded, color: AppColors.grey500, size: 20),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            color: AppColors.grey500,
            size: 20,
          ),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.grey200)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.grey200)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.teal, width: 2)),
      ),
    );
  }


  
}
