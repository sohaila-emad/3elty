import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/remote_auth_service.dart';
import 'package:flutter_application_1/services/firestore_service.dart';
import '../main.dart';

/// Screen for family signup/signin.
/// First step of app authentication flow.
class FamilyAuthScreen extends StatefulWidget {
  const FamilyAuthScreen({Key? key}) : super(key: key);

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
  bool _obscurePassword = true;
  bool _obscureAdminPassword = true;
  String? _errorMessage;

  // ── Input border helpers ───────────────────────────────────────────────────
  OutlineInputBorder _border(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );

  InputDecoration _inputDecor({
    required String label,
    required IconData icon,
    Widget? suffix,
    String? helper,
  }) =>
      InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.grey600, fontSize: 14),
        prefixIcon: Icon(icon, color: AppColors.grey500, size: 20),
        suffixIcon: suffix,
        helperText: helper,
        helperStyle: const TextStyle(fontSize: 11, color: AppColors.grey500),
        filled: true,
        fillColor: AppColors.grey50,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: _border(AppColors.grey200),
        enabledBorder: _border(AppColors.grey200),
        focusedBorder: _border(AppColors.teal, width: 2),
        errorBorder: _border(AppColors.red),
        focusedErrorBorder: _border(AppColors.red, width: 2),
      );

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
        _isSignUp = !exists;
        _showPasswordField = true;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error checking family: $e';
        _showPasswordField = false;
      });
    }
  }

  Future<void> _handleSignUp() async {
    final username = _familyUsernameController.text.trim();
    final displayName = _displayNameController.text.trim();
    final familyPassword = _familyPasswordController.text;
    final adminPassword = _adminPasswordController.text;

    if (username.isEmpty ||
        familyPassword.isEmpty ||
        adminPassword.isEmpty ||
        displayName.isEmpty) {
      setState(() => _errorMessage = 'Please fill all fields');
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
      await _firestoreService.syncFamilyData();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/persistent_dashboard');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSignIn() async {
    final username = _familyUsernameController.text.trim();
    final password = _familyPasswordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please fill all fields');
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

      final userRole = await _authService.userRole;
      if (userRole == 'admin' && mounted) {
        final isAdminVerified = await _showAdminVerificationDialog();
        if (!isAdminVerified) {
          await _authService.downgradeToMemberMode();
        }
      }

      await _firestoreService.syncFamilyData();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/persistent_dashboard');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<bool> _showAdminVerificationDialog() async {
    final adminPasswordCtrl = TextEditingController();
    bool obscurePassword = true;
    bool? result;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Admin Verification',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'You are the admin. Enter your admin password to enable admin features.',
                style: TextStyle(
                    fontSize: 14, color: AppColors.grey600, height: 1.5),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: adminPasswordCtrl,
                obscureText: obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Admin Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () =>
                        setState(() => obscurePassword = !obscurePassword),
                  ),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.grey200)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.grey200)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.teal, width: 2)),
                ),
              ),
              const SizedBox(height: 8),
              const Text('If you skip, you will use member access only.',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.grey500,
                      fontStyle: FontStyle.italic)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                result = false;
                Navigator.pop(ctx);
              },
              child: const Text('Skip (Member Mode)',
                  style: TextStyle(color: AppColors.grey600)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.teal,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                result = true;
                Navigator.pop(ctx);
              },
              child: const Text('Verify',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    return result ?? false;
  }

  // ── UI ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey50,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),

              // ── Logo + title ──────────────────────────────────────────────
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.teal,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(Icons.people_alt_rounded,
                      color: Colors.white, size: 40),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '3elty - Your Family Health Companion',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.grey900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Family Health Management',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.grey500),
              ),
              const SizedBox(height: 48),

              // ── Family Username ───────────────────────────────────────────
              TextField(
                controller: _familyUsernameController,
                enabled: !_isLoading,
                style: const TextStyle(fontSize: 15),
                decoration: _inputDecor(
                  label: 'Family Username',
                  icon: Icons.people_rounded,
                ),
                onChanged: (_) => _checkFamilyExists(),
              ),
              const SizedBox(height: 14),

              // ── Status banner ─────────────────────────────────────────────
              if (_showPasswordField)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _familyExists
                        ? AppColors.tealLight
                        : AppColors.greenLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    Icon(
                      _familyExists
                          ? Icons.check_circle_rounded
                          : Icons.info_rounded,
                      size: 16,
                      color: _familyExists
                          ? AppColors.teal
                          : AppColors.green,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _familyExists
                          ? 'Family found! Please sign in.'
                          : 'New family! Proceeding with setup.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _familyExists
                            ? AppColors.teal
                            : AppColors.green,
                      ),
                    ),
                  ]),
                ),

              // ── Display Name (signup only) ────────────────────────────────
              if (_showPasswordField && _isSignUp) ...[
                TextField(
                  controller: _displayNameController,
                  enabled: !_isLoading,
                  style: const TextStyle(fontSize: 15),
                  decoration: _inputDecor(
                    label: 'Family Display Name',
                    icon: Icons.home_rounded,
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // ── Family Password ───────────────────────────────────────────
              if (_showPasswordField) ...[
                TextField(
                  controller: _familyPasswordController,
                  enabled: !_isLoading,
                  obscureText: _obscurePassword,
                  style: const TextStyle(fontSize: 15),
                  decoration: _inputDecor(
                    label: _isSignUp
                        ? 'Set Family Password'
                        : 'Family Password',
                    icon: Icons.lock_rounded,
                    suffix: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.grey500,
                        size: 20,
                      ),
                      onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // ── Admin Password (signup only) ──────────────────────────────
              if (_showPasswordField && _isSignUp) ...[
                TextField(
                  controller: _adminPasswordController,
                  enabled: !_isLoading,
                  obscureText: _obscureAdminPassword,
                  style: const TextStyle(fontSize: 15),
                  decoration: _inputDecor(
                    label: 'Set Admin Password',
                    icon: Icons.admin_panel_settings_rounded,
                    helper: 'Only you (the admin) will know this password',
                    suffix: IconButton(
                      icon: Icon(
                        _obscureAdminPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.grey500,
                        size: 20,
                      ),
                      onPressed: () => setState(() =>
                          _obscureAdminPassword = !_obscureAdminPassword),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // ── Error message ─────────────────────────────────────────────
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.redLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_rounded,
                        color: AppColors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                            color: AppColors.red, fontSize: 13),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 14),
              ],

              // ── Main action button ────────────────────────────────────────
              if (_showPasswordField) ...[
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : (_isSignUp ? _handleSignUp : _handleSignIn),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.teal,
                      disabledBackgroundColor:
                          AppColors.teal.withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _isSignUp
                                    ? Icons.person_add_rounded
                                    : Icons.login_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _isSignUp ? 'Sign Up' : 'Sign In',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Toggle sign in / sign up ──────────────────────────────
                Center(
                  child: TextButton(
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
                          ? 'Already have a family? Sign In'
                          : 'New family? Sign Up',
                      style: const TextStyle(
                        color: AppColors.teal,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // ── How it works ──────────────────────────────────────────────
              if (!_showPasswordField)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.tealLight,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.info_outline_rounded,
                            color: AppColors.teal, size: 18),
                        const SizedBox(width: 8),
                        const Text('How it works',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: AppColors.teal)),
                      ]),
                      const SizedBox(height: 10),
                      for (final step in [
                        '1. Enter your family username',
                        '2. Set up family name & admin password',
                        '3. Add family members',
                        '4. Track health records together',
                      ])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(step,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.grey600,
                                  height: 1.5)),
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