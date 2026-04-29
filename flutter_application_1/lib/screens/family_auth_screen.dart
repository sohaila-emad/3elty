import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/remote_auth_service.dart';
import 'package:flutter_application_1/services/firestore_service.dart';
import '../main.dart';

/// Screen for family signup/signin.
/// First step of app authentication flow.
class FamilyAuthScreen extends StatefulWidget {
  const FamilyAuthScreen({super.key});

  @override
  State<FamilyAuthScreen> createState() => _FamilyAuthScreenState();
}

class _FamilyAuthScreenState extends State<FamilyAuthScreen> {
  final _familyUsernameController = TextEditingController();
  final _familyPasswordController = TextEditingController();
  final _adminPasswordController = TextEditingController();
  final _displayNameController = TextEditingController();

  final _authService = RemoteAuthService();
  final _firestoreService = FirestoreService();

  bool _isSignUp = false;
  bool _showPasswordField = false;
  bool _isLoading = false;
  bool _familyExists = false;
  String? _errorMessage;

  @override
  void dispose() {
    _familyUsernameController.dispose();
    _familyPasswordController.dispose();
    _adminPasswordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  /// Check if family exists and update UI accordingly.
  Future<void> _checkFamilyExists() async {
    final username = _familyUsernameController.text.trim();
    if (username.isEmpty || username.length < 3) {
      setState(() {
        _showPasswordField = false;
        _errorMessage = null;
      });
      return;
    }

    try {
      final exists = await _authService.familyExists(username);
      setState(() {
        _familyExists = exists;
        _isSignUp = !exists; // Auto-switch to signup if family doesn't exist
        _showPasswordField = true;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'خطأ في التحقق من العائلة: $e';
        _showPasswordField = false;
      });
    }
  }

  /// Handle signup for new family.
  Future<void> _handleSignUp() async {
    final username = _familyUsernameController.text.trim();
    final displayName = _displayNameController.text.trim();
    final familyPassword = _familyPasswordController.text;
    final adminPassword = _adminPasswordController.text;

    if (username.isEmpty || familyPassword.isEmpty || adminPassword.isEmpty || displayName.isEmpty) {
      setState(() => _errorMessage = 'من فضلك أكمل جميع الحقول');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.signUpFamily(
        familyUsername: username,
        displayName: displayName,
        familyPassword: familyPassword,
        adminPassword: adminPassword,
      );

      // Sync empty family data (no members yet)
      await _firestoreService.syncFamilyData();

      if (mounted) {
        // Navigate to dashboard
        Navigator.of(context).pushReplacementNamed('/persistent_dashboard');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  /// Handle signin for existing family.
  Future<void> _handleSignIn() async {
    final username = _familyUsernameController.text.trim();
    final password = _familyPasswordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'من فضلك أكمل جميع الحقول');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.signInFamily(
        familyUsername: username,
        familyPassword: password,
      );

      // Check if user is admin
      final userRole = await _authService.userRole;
      
      // Only show admin verification if user is admin
      if (userRole == 'admin' && mounted) {
        final isAdminVerified = await _showAdminVerificationDialog();
        
        if (!isAdminVerified) {
          // Admin didn't verify password - downgrade to member mode
          await _authService.downgradeToMemberMode();
        }
      }

      // Sync family data from Firestore
      await _firestoreService.syncFamilyData();

      if (mounted) {
        // Navigate to dashboard
        Navigator.of(context).pushReplacementNamed('/persistent_dashboard');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  /// Show admin password verification dialog.
  /// Returns true if password verified, false if skipped/cancelled.
  Future<bool> _showAdminVerificationDialog() async {
    final adminPasswordCtrl = TextEditingController();
    bool obscurePassword = true;
    bool? result;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'التحقق من المسؤول',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'أنت المسؤول. أدخل كلمة مرور المسؤول لتفعيل صلاحيات الإدارة.',
                style: TextStyle(fontSize: 14, color: AppColors.grey600, height: 1.5),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: adminPasswordCtrl,
                obscureText: obscurePassword,
                decoration: InputDecoration(
                  labelText: 'كلمة مرور المسؤول',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => obscurePassword = !obscurePassword),
                  ),
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
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'إذا تخطيت هذه الخطوة، ستستخدم صلاحيات الأعضاء فقط.',
                style: TextStyle(fontSize: 12, color: AppColors.grey500, fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                result = false; // Skip admin verification
                Navigator.pop(ctx);
              },
              child: const Text('تخطي (وضع العضو)'),
            ),
            ElevatedButton(
              onPressed: () async {
                final adminPassword = adminPasswordCtrl.text;
                if (adminPassword.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('من فضلك أدخل كلمة مرور المسؤول')),
                  );
                  return;
                }

                try {
                  // Verify admin password
                  await _authService.verifyAdminPassword(adminPassword);
                  result = true; // Admin verified
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('كلمة المرور غير صحيحة'),
                      backgroundColor: AppColors.red,
                    ),
                  );
                }
              },
              child: const Text('تحقق'),
            ),
          ],
        ),
      ),
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تسجيل الدخول للعائلة'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),
            // Header
            const Text(
              '3elty',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'إدارة الصحة الأسرية',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 40),

            // Family Username Field
            TextField(
              controller: _familyUsernameController,
              enabled: !_isLoading,
              decoration: InputDecoration(
                labelText: 'اسم مستخدم العائلة',
                hintText: 'أدخل معرّف عائلتك',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.people),
              ),
              onChanged: (_) => _checkFamilyExists(),
            ),
            const SizedBox(height: 16),

            // Display helper text
            if (_showPasswordField)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _familyExists ? Colors.blue.shade50 : Colors.green.shade50,
                    border: Border.all(
                      color: _familyExists ? Colors.blue : Colors.green,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _familyExists
                        ? 'تم العثور على العائلة! سجّل دخولك.'
                        : 'عائلة جديدة! سنكمل إعداد الحساب.',
                    style: TextStyle(
                      color: _familyExists ? Colors.blue : Colors.green,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),

            // Display Name Field (Sign Up only)
            if (_showPasswordField && _isSignUp)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: TextField(
                  controller: _displayNameController,
                  enabled: !_isLoading,
                  decoration: InputDecoration(
                    labelText: 'اسم العائلة',
                    hintText: 'مثال: عائلة محمد',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.home),
                  ),
                ),
              ),

            // Family Password Field
            if (_showPasswordField)
              TextField(
                controller: _familyPasswordController,
                enabled: !_isLoading,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: _isSignUp ? 'كلمة مرور العائلة' : 'أدخل كلمة مرور العائلة',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.lock),
                ),
              ),
            const SizedBox(height: 16),

            // Admin Password Field (Sign Up only)
            if (_showPasswordField && _isSignUp)
              TextField(
                controller: _adminPasswordController,
                enabled: !_isLoading,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'كلمة مرور المسؤول',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.admin_panel_settings),
                  helperText: 'فقط المسؤول يعرف هذه الكلمة',
                ),
              ),
            const SizedBox(height: 24),

            // Error Message
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ),
            const SizedBox(height: 24),

            // Main Action Button
            if (_showPasswordField)
              ElevatedButton.icon(
                onPressed: _isLoading
                    ? null
                    : (_isSignUp ? _handleSignUp : _handleSignIn),
                icon: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(_isSignUp ? Icons.app_registration : Icons.login),
                label: Text(_isSignUp ? 'إنشاء حساب' : 'تسجيل الدخول'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor:
                      _isSignUp ? Colors.green : Colors.blue,
                ),
              ),

            const SizedBox(height: 16),

            // Toggle Sign Up / Sign In
            if (_showPasswordField)
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        setState(() {
                          _isSignUp = !_isSignUp;
                          _errorMessage = null;
                          _familyPasswordController.clear();
                          _adminPasswordController.clear();
                          _displayNameController.clear();
                        });
                      },
                child: Text(
                  _isSignUp
                      ? 'لديك حساب بالفعل؟ سجّل دخولك'
                      : 'عائلة جديدة؟ أنشئ حساباً',
                  style: const TextStyle(color: Colors.blue),
                ),
              ),
            const SizedBox(height: 40),

            // Info Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'كيف يعمل التطبيق:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '1. أدخل اسم مستخدم العائلة\n'
                    '2. أنشئ اسم العائلة وكلمة المسؤول\n'
                    '3. أضف أفراد العائلة\n'
                    '4. تابع السجلات الصحية معاً',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
