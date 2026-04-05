import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/remote_auth_service.dart';
import 'package:flutter_application_1/services/firestore_service.dart';

/// Screen for family signup/signin.
/// First step of app authentication flow.
class FamilyAuthScreen extends StatefulWidget {
  const FamilyAuthScreen({Key? key}) : super(key: key);

  @override
  State<FamilyAuthScreen> createState() => _FamilyAuthScreenState();
}

class _FamilyAuthScreenState extends State<FamilyAuthScreen> {
  final _familyUsernameController = TextEditingController();
  final _passwordController = TextEditingController();
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
    _passwordController.dispose();
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
        _errorMessage = 'Error checking family: $e';
        _showPasswordField = false;
      });
    }
  }

  /// Handle signup for new family.
  Future<void> _handleSignUp() async {
    final username = _familyUsernameController.text.trim();
    final displayName = _displayNameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty || displayName.isEmpty) {
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
        adminPassword: password,
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
    final password = _passwordController.text;

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
        adminPassword: password,
      );

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
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Family Health Management',
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
                labelText: 'Family Username',
                hintText: 'Enter your family identifier',
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
                        ? 'Family found! Please sign in.'
                        : 'New family! Proceeding with setup.',
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
                    labelText: 'Family Display Name',
                    hintText: 'e.g., "Smith Family"',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.home),
                  ),
                ),
              ),

            // Password Field
            if (_showPasswordField)
              TextField(
                controller: _passwordController,
                enabled: !_isLoading,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Admin Password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.lock),
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
                          _passwordController.clear();
                          _displayNameController.clear();
                        });
                      },
                child: Text(
                  _isSignUp
                      ? 'Already have a family? Sign In'
                      : 'New family? Sign Up',
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
                    'How it works:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '1. Enter your family username\n'
                    '2. Set up family name & admin password\n'
                    '3. Add family members\n'
                    '4. Track health records together',
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
