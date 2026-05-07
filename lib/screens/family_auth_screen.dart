import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/remote_auth_service.dart';
import 'package:flutter_application_1/services/firestore_service.dart';
import '../main.dart';

class FamilyAuthScreen extends StatefulWidget {
  const FamilyAuthScreen({super.key});

  @override
  State<FamilyAuthScreen> createState() => _FamilyAuthScreenState();
}

class _FamilyAuthScreenState extends State<FamilyAuthScreen> {
  final _familyUsernameController = TextEditingController();
  final _familyPasswordController = TextEditingController();
  final _adminPasswordController  = TextEditingController();
  final _displayNameController    = TextEditingController();

  final _authService      = RemoteAuthService();
  final _firestoreService = FirestoreService();

  Timer? _debounce;

  bool _isSignUp          = false;
  bool _showPasswordField = false;
  bool _isLoading         = false;
  bool _familyExists      = false;
  String? _errorMessage;

  @override
  void dispose() {
    _debounce?.cancel();
    _familyUsernameController.dispose();
    _familyPasswordController.dispose();
    _adminPasswordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  // debounce 600ms — مش بيعمل call على كل حرف
  void _onUsernameChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _checkFamilyExists);
  }

  Future<void> _checkFamilyExists() async {
    final username = _familyUsernameController.text.trim();
    if (username.isEmpty || username.length < 3) {
      setState(() { _showPasswordField = false; _errorMessage = null; });
      return;
    }
    try {
      final exists = await _authService.familyExists(username);
      if (!mounted) return;
      setState(() {
        _familyExists      = exists;
        _isSignUp          = !exists;
        _showPasswordField  = true;
        _errorMessage      = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _errorMessage = 'خطأ في التحقق: $e'; _showPasswordField = false; });
    }
  }

  Future<void> _handleSignUp() async {
    final username    = _familyUsernameController.text.trim();
    final displayName = _displayNameController.text.trim();
    final familyPwd   = _familyPasswordController.text;
    final adminPwd    = _adminPasswordController.text;

    if (username.isEmpty || familyPwd.isEmpty || adminPwd.isEmpty || displayName.isEmpty) {
      setState(() => _errorMessage = 'يرجى ملء جميع الحقول');
      return;
    }
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      await _authService.signUpFamily(
        familyUsername: username,
        displayName:    displayName,
        familyPassword: familyPwd,
        adminPassword:  adminPwd,
      );
      await _firestoreService.syncFamilyData();
      if (mounted) Navigator.of(context).pushReplacementNamed('/persistent_dashboard');
    } catch (e) {
      if (mounted) setState(() { _errorMessage = e.toString().replaceAll('Exception: ', ''); _isLoading = false; });
    }
  }

  Future<void> _handleSignIn() async {
    final username = _familyUsernameController.text.trim();
    final password = _familyPasswordController.text;
    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'يرجى ملء جميع الحقول');
      return;
    }
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      await _authService.signInFamily(familyUsername: username, familyPassword: password);
      final userRole = await _authService.userRole;
      if (userRole == 'admin' && mounted) {
        final verified = await _showAdminVerificationDialog();
        if (!verified) await _authService.downgradeToMemberMode();
      }
      await _firestoreService.syncFamilyData();
      if (mounted) Navigator.of(context).pushReplacementNamed('/persistent_dashboard');
    } catch (e) {
      if (mounted) setState(() { _errorMessage = e.toString().replaceAll('Exception: ', ''); _isLoading = false; });
    }
  }

  Future<bool> _showAdminVerificationDialog() async {
    final ctrl = TextEditingController();
    bool obscure = true;
    bool? result;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setS) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('التحقق من المسؤول',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('أدخل كلمة مرور المسؤول لتفعيل صلاحيات الإدارة.',
                    style: TextStyle(fontSize: 14, color: AppColors.grey600, height: 1.5)),
                const SizedBox(height: 20),
                TextFormField(
                  controller: ctrl,
                  obscureText: obscure,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: 'كلمة مرور المسؤول',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setS(() => obscure = !obscure),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.grey200)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.teal, width: 2)),
                  ),
                ),
                const SizedBox(height: 8),
                const Text('تخطَّ للدخول كعضو فقط.',
                    style: TextStyle(fontSize: 12, color: AppColors.grey500, fontStyle: FontStyle.italic)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () { result = false; Navigator.pop(ctx); },
                child: const Text('تخطي (وضع العضو)'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal),
                onPressed: () async {
                  if (ctrl.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('يرجى إدخال كلمة المرور')));
                    return;
                  }
                  try {
                    await _authService.verifyAdminPassword(ctrl.text);
                    result = true;
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (_) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: const Text('كلمة مرور خاطئة'),
                        backgroundColor: AppColors.red));
                  }
                },
                child: const Text('تحقق', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('تسجيل الدخول للعائلة'),
          centerTitle: true,
          backgroundColor: AppColors.teal,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),

              // ── شعار التطبيق ──────────────────────────────────────────────
              const Text('عيلتي',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold,
                      color: AppColors.teal)),
              const SizedBox(height: 8),
              const Text('إدارة صحة الأسرة',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: AppColors.grey600)),
              const SizedBox(height: 40),

              // ── حقل اسم مستخدم العائلة ────────────────────────────────────
              TextField(
                controller: _familyUsernameController,
                enabled: !_isLoading,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: 'اسم مستخدم العائلة',
                  hintText: 'أدخل معرّف عائلتك',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.teal, width: 2)),
                  prefixIcon: const Icon(Icons.people, color: AppColors.teal),
                ),
                onChanged: _onUsernameChanged,
              ),
              const SizedBox(height: 16),

              // ── مؤشر وجود العائلة ─────────────────────────────────────────
              if (_showPasswordField)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _familyExists ? Colors.blue.shade50 : Colors.green.shade50,
                    border: Border.all(color: _familyExists ? Colors.blue : Colors.green),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(_familyExists ? Icons.check_circle : Icons.fiber_new,
                          color: _familyExists ? Colors.blue : Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        _familyExists ? 'تم العثور على العائلة! سجّل دخولك.' : 'عائلة جديدة! سنكمل إعداد الحساب.',
                        style: TextStyle(color: _familyExists ? Colors.blue : Colors.green, fontSize: 13),
                      ),
                    ],
                  ),
                ),

              // ── اسم العائلة (إنشاء حساب فقط) ─────────────────────────────
              if (_showPasswordField && _isSignUp) ...[
                TextField(
                  controller: _displayNameController,
                  enabled: !_isLoading,
                  decoration: InputDecoration(
                    labelText: 'اسم العائلة المعروض',
                    hintText: 'مثال: عائلة الأحمدي',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.teal, width: 2)),
                    prefixIcon: const Icon(Icons.home, color: AppColors.teal),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── كلمة مرور العائلة ─────────────────────────────────────────
              if (_showPasswordField) ...[
                TextField(
                  controller: _familyPasswordController,
                  enabled: !_isLoading,
                  obscureText: true,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: _isSignUp ? 'أنشئ كلمة مرور العائلة' : 'أدخل كلمة مرور العائلة',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.teal, width: 2)),
                    prefixIcon: const Icon(Icons.lock, color: AppColors.teal),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── كلمة مرور المسؤول (إنشاء حساب فقط) ──────────────────────
              if (_showPasswordField && _isSignUp) ...[
                TextField(
                  controller: _adminPasswordController,
                  enabled: !_isLoading,
                  obscureText: true,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: 'أنشئ كلمة مرور المسؤول',
                    helperText: 'هذه الكلمة فقط للمسؤول — احتفظ بها',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.teal, width: 2)),
                    prefixIcon: const Icon(Icons.admin_panel_settings, color: AppColors.teal),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── رسالة الخطأ ───────────────────────────────────────────────
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_errorMessage!,
                          style: const TextStyle(color: Colors.red, fontSize: 13))),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── زر الإجراء الرئيسي ────────────────────────────────────────
              if (_showPasswordField) ...[
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : (_isSignUp ? _handleSignUp : _handleSignIn),
                    icon: _isLoading
                        ? const SizedBox(height: 20, width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Icon(_isSignUp ? Icons.app_registration : Icons.login),
                    label: Text(_isSignUp ? 'إنشاء حساب' : 'تسجيل الدخول',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isSignUp ? Colors.green.shade600 : AppColors.teal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ── التبديل بين إنشاء وتسجيل ──────────────────────────────
                TextButton(
                  onPressed: _isLoading ? null : () => setState(() {
                    _isSignUp = !_isSignUp;
                    _errorMessage = null;
                    _familyPasswordController.clear();
                    _adminPasswordController.clear();
                    _displayNameController.clear();
                  }),
                  child: Text(
                    _isSignUp ? 'لديك حساب بالفعل؟ سجّل دخولك' : 'عائلة جديدة؟ أنشئ حساباً',
                    style: const TextStyle(color: AppColors.teal, fontSize: 14),
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // ── شرح طريقة الاستخدام ───────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.grey100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.grey200),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.info_outline, size: 16, color: AppColors.grey600),
                      SizedBox(width: 6),
                      Text('كيف يعمل التطبيق؟',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ]),
                    SizedBox(height: 10),
                    Text(
                      '١. أدخل اسم مستخدم العائلة\n'
                      '٢. أنشئ اسم العائلة وكلمة مرور المسؤول\n'
                      '٣. أضف أفراد العائلة\n'
                      '٤. تابع السجلات الصحية معاً',
                      style: TextStyle(fontSize: 13, color: AppColors.grey600, height: 1.7),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
