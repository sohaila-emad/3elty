import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/remote_auth_service.dart';
import 'package:flutter_application_1/services/firestore_service.dart';
import '../main.dart';

/// Screen for family signup/signin.
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

  // ── FIX: debounce timer prevents Firestore call on every keystroke ──────────
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

  /// Called on every keystroke — debounces 600ms before hitting Firestore.
  void _onUsernameChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _checkFamilyExists);
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
      if (!mounted) return;
      setState(() {
        _familyExists      = exists;
        _isSignUp          = !exists;
        _showPasswordField = true;
        _errorMessage      = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage      = 'Error checking family: $e';
        _showPasswordField = false;
      });
    }
  }

  /// Handle signup for new family.
  Future<void> _handleSignUp() async {
    final username      = _familyUsernameController.text.trim();
    final displayName   = _displayNameController.text.trim();
    final familyPwd     = _familyPasswordController.text;
    final adminPwd      = _adminPasswordController.text;

    if (username.isEmpty || familyPwd.isEmpty ||
        adminPwd.isEmpty  || displayName.isEmpty) {
      setState(() => _errorMessage = 'Please fill all fields');
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

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/persistent_dashboard');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading    = false;
        });
      }
    }
  }

  /// Handle signin for existing family.
  Future<void> _handleSignIn() async {
    final username = _familyUsernameController.text.trim();
    final password = _familyPasswordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please fill all fields');
      return;
    }

    setState(() { _isLoading = true; _errorMessage = null; });

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
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading    = false;
        });
      }
    }
  }

  /// Admin password verification dialog.
  Future<bool> _showAdminVerificationDialog() async {
    final adminPasswordCtrl = TextEditingController();
    bool obscurePassword = true;
    bool? result;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Admin Verification',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter your admin password to enable admin features.',
                style: TextStyle(fontSize: 14, color: AppColors.grey600, height: 1.5),
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
                        setDialogState(() => obscurePassword = !obscurePassword),
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
                'Skip to use member access only.',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.grey500,
                    fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                result = false;
                Navigator.pop(ctx);
              },
              child: const Text('Skip (Member Mode)'),
            ),
            ElevatedButton(
              onPressed: () async {
                final adminPassword = adminPasswordCtrl.text;
                if (adminPassword.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter admin password')),
                  );
                  return;
                }
                try {
                  await _authService.verifyAdminPassword(adminPassword);
                  result = true;
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Invalid password: $e'),
                      backgroundColor: AppColors.red,
                    ),
                  );
                }
              },
              child: const Text('Verify'),
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
        title: const Text('Family Authentication'),
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
                color: AppColors.teal,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Family Health Management',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.grey600),
            ),
            const SizedBox(height: 40),

            // Family Username Field
            TextField(
              controller: _familyUsernameController,
              enabled: !_isLoading,
              decoration: InputDecoration(
                labelText: 'Family Username',
                hintText: 'Enter your family identifier',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.people),
              ),
              // ── FIX: was _checkFamilyExists() directly — now debounced ──────
              onChanged: _onUsernameChanged,
            ),
            const SizedBox(height: 16),

            // Family found / new family indicator
            if (_showPasswordField)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _familyExists
                        ? Colors.blue.shade50
                        : Colors.green.shade50,
                    border: Border.all(
                        color: _familyExists ? Colors.blue : Colors.green),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _familyExists
                        ? 'Family found! Please sign in.'
                        : 'New family! Proceeding with setup.',
                    style: TextStyle(
                      color: _familyExists ? Colors.blue : Colors.green,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),

            // Display Name (sign-up only)
            if (_showPasswordField && _isSignUp)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: TextField(
                  controller: _displayNameController,
                  enabled: !_isLoading,
                  decoration: InputDecoration(
                    labelText: 'Family Display Name',
                    hintText: 'e.g., "Smith Family"',
                    border:
                        OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.home),
                  ),
                ),
              ),

            // Family Password
            if (_showPasswordField)
              TextField(
                controller: _familyPasswordController,
                enabled: !_isLoading,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: _isSignUp
                      ? 'Set Family Password'
                      : 'Enter Family Password',
                  border:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.lock),
                ),
              ),
            const SizedBox(height: 16),

            // Admin Password (sign-up only)
            if (_showPasswordField && _isSignUp)
              TextField(
                controller: _adminPasswordController,
                enabled: !_isLoading,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Set Admin Password',
                  border:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.admin_panel_settings),
                  helperText: 'Only you (the admin) will know this password',
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
                label: Text(_isSignUp ? 'SIGN UP' : 'SIGN IN'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: _isSignUp ? Colors.green : AppColors.teal,
                ),
              ),

            const SizedBox(height: 16),

            // Toggle sign-up / sign-in
            if (_showPasswordField)
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () => setState(() {
                          _isSignUp = !_isSignUp;
                          _errorMessage = null;
                          _familyPasswordController.clear();
                          _adminPasswordController.clear();
                          _displayNameController.clear();
                        }),
                child: Text(
                  _isSignUp
                      ? 'Already have a family? Sign In'
                      : 'New family? Sign Up',
                  style: const TextStyle(color: AppColors.teal),
                ),
              ),

            const SizedBox(height: 40),

            // How it works
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.grey100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('How it works:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  SizedBox(height: 8),
                  Text(
                    '1. Enter your family username\n'
                    '2. Set up family name & admin password\n'
                    '3. Add family members\n'
                    '4. Track health records together',
                    style: TextStyle(fontSize: 12, color: AppColors.grey600),
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