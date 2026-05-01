import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../services/remote_auth_service.dart';
import '../utils/auth_helpers.dart';


// ═══════════════════════════════════════════════════════════════════════════════
// SCREEN: First-Time Setup  (phone → OTP → set PIN)
// ═══════════════════════════════════════════════════════════════════════════════
class FirstTimeSetupScreen extends StatefulWidget {
  const FirstTimeSetupScreen({super.key});

  @override
  State<FirstTimeSetupScreen> createState() => _FirstTimeSetupScreenState();
}

class _FirstTimeSetupScreenState extends State<FirstTimeSetupScreen> {
  final _phoneCtrl = TextEditingController();
  final _otpCtrl   = TextEditingController();
  final _pin1Ctrl  = TextEditingController();
  final _pin2Ctrl  = TextEditingController();
  final _auth      = FirebaseAuth.instance;
  final _remoteAuth = RemoteAuthService();

  // Steps: 0 = enter phone, 1 = enter OTP, 2 = set PIN
  int    _step        = 0;
  bool   _isLoading   = false;
  String? _error;
  String? _verificationId;
  int?   _resendToken;
  int    _resendCountdown = 0;
  Timer? _resendTimer;
  String? _userId;  // ← Store userId from OTP verification for PIN setup

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _pin1Ctrl.dispose();
    _pin2Ctrl.dispose();
    super.dispose();
  }

  // ── Step 0: Send OTP ────────────────────────────────────────────────────────
  Future<void> _sendOtp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length < 10) {
      _setError('Please enter a valid phone number');
      return;
    }

    // Format to E.164 if not already (assume Egypt +20)
    final formatted = normalizePhoneNumber(phone);

    setState(() { _isLoading = true; _error = null; });

    try {
      // 1. Verify this phone is registered by admin in Firestore
      final isRegistered = await _remoteAuth.isPhoneRegisteredByAdmin(formatted);
      if (!isRegistered) {
        _setError('This phone number is not registered in any family.\nAsk your admin to add you first.');
        setState(() => _isLoading = false);
        return;
      }

      // 2. Send Firebase OTP
      await _auth.verifyPhoneNumber(
        phoneNumber: formatted,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verified on Android (SMS auto-read)
          await _signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          _setError('OTP failed: ${e.message}');
          setState(() => _isLoading = false);
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _resendToken    = resendToken;
            _step           = 1;
            _isLoading      = false;
          });
          _startResendCountdown();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
        forceResendingToken: _resendToken,
      );
    } catch (e) {
      _setError('Error: $e');
      setState(() => _isLoading = false);
    }
  }

  // ── Step 1: Verify OTP ──────────────────────────────────────────────────────
  Future<void> _verifyOtp() async {
    final code = _otpCtrl.text.trim();
    if (code.length != 6) {
      _setError('Please enter the 6-digit code');
      return;
    }
    if (_verificationId == null) {
      _setError('Verification session expired. Please resend.');
      return;
    }

    setState(() { _isLoading = true; _error = null; });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: code,
      );
      await _signInWithCredential(credential);
    } catch (e) {
      _setError('Invalid code. Please try again.');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    try {
      await _auth.signInWithCredential(credential);
      
      // Create Firestore user document for this member
      // (links phone to family_id for subsequent PIN setup)
      final phone = normalizePhoneNumber(_phoneCtrl.text.trim());
      _userId = await _remoteAuth.createMemberUserByPhone(phone: phone);
      
      // OTP verified — move to PIN setup
      if (mounted) setState(() { _step = 2; _isLoading = false; });
    } catch (e) {
      _setError('Verification failed: $e');
      setState(() => _isLoading = false);
    }
  }

  // ── Step 2: Set PIN ─────────────────────────────────────────────────────────
  Future<void> _savePin() async {
    final pin1 = _pin1Ctrl.text;
    final pin2 = _pin2Ctrl.text;

    if (pin1.length != 4) {
      _setError('PIN must be exactly 4 digits');
      return;
    }
    if (pin1 != pin2) {
      _setError('PINs do not match');
      return;
    }

    setState(() { _isLoading = true; _error = null; });

    try {
      final phone = normalizePhoneNumber(_phoneCtrl.text.trim());

      // Save PIN locally on device
      await savePin(phone, pin1);

      // Store PIN hash in Firestore using userId (avoids Firestore consistency issues)
      await _remoteAuth.setupMemberPinByPhone(
        userId: _userId,
        pin: pin1,
      );

      // Sign in to app session
      final familyId = await _remoteAuth.signInWithPin(
        phone: phone,
        pin: pin1,
      );

      // Mark PIN as verified for this session
      await markPinVerifiedThisSession(phone);

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(
        '/persistent_dashboard',
        arguments: {'familyId': familyId, 'memberPhone': phone},
      );
    } catch (e) {
      _setError('Failed to save PIN: $e');
      setState(() => _isLoading = false);
    }
  }

  // ── Resend countdown ─────────────────────────────────────────────────────────
  void _startResendCountdown() {
    setState(() => _resendCountdown = 60);
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _resendCountdown--;
        if (_resendCountdown <= 0) t.cancel();
      });
    });
  }

  void _setError(String msg) => setState(() => _error = msg);

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey50,
      appBar: AppBar(
        title: const Text('First Time Setup'),
        leading: _step > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => setState(() {
                  _step--;
                  _error = null;
                }),
              )
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Progress indicator
            _StepIndicator(currentStep: _step),
            const SizedBox(height: 32),

            // Step content
            if (_step == 0) _buildPhoneStep(),
            if (_step == 1) _buildOtpStep(),
            if (_step == 2) _buildPinStep(),

            // Error
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.redLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.red),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: AppColors.red,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _StepHeader(
        icon: Icons.phone_rounded,
        title: 'Enter your phone number',
        subtitle: 'We\'ll send a verification code to confirm your identity',
      ),
      const SizedBox(height: 28),
      TextField(
        controller: _phoneCtrl,
        keyboardType: TextInputType.phone,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          labelText: 'Phone Number',
          hintText: '1XXXXXXXXX',
          prefixIcon: const Icon(Icons.phone_rounded),
          prefixText: '+20  ',
          prefixStyle: const TextStyle(
            color: AppColors.teal,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      const SizedBox(height: 24),
      ElevatedButton(
        onPressed: _isLoading ? null : _sendOtp,
        child: _isLoading
            ? const SizedBox(
                height: 20, width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
            : const Text('Send Verification Code'),
      ),
    ],
  );

  Widget _buildOtpStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _StepHeader(
        icon: Icons.sms_rounded,
        title: 'Enter verification code',
        subtitle: 'Sent to ${_phoneCtrl.text.trim()}',
      ),
      const SizedBox(height: 28),
      TextField(
        controller: _otpCtrl,
        keyboardType: TextInputType.number,
        maxLength: 6,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: 8,
        ),
        decoration: InputDecoration(
          hintText: '------',
          counterText: '',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      const SizedBox(height: 24),
      ElevatedButton(
        onPressed: _isLoading ? null : _verifyOtp,
        child: _isLoading
            ? const SizedBox(
                height: 20, width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
            : const Text('Verify Code'),
      ),
      const SizedBox(height: 16),
      TextButton(
        onPressed: _resendCountdown > 0 ? null : _sendOtp,
        child: Text(
          _resendCountdown > 0
              ? 'Resend code in ${_resendCountdown}s'
              : 'Resend code',
          style: TextStyle(
            color: _resendCountdown > 0 ? AppColors.grey400 : AppColors.teal,
          ),
        ),
      ),
    ],
  );

  Widget _buildPinStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _StepHeader(
        icon: Icons.lock_rounded,
        title: 'Set your 4-digit PIN',
        subtitle: 'You\'ll use this PIN every 10 logins as a security check',
      ),
      const SizedBox(height: 28),
      _PinInputField(controller: _pin1Ctrl, label: 'Enter PIN'),
      const SizedBox(height: 16),
      _PinInputField(controller: _pin2Ctrl, label: 'Confirm PIN'),
      const SizedBox(height: 24),
      ElevatedButton(
        onPressed: _isLoading ? null : _savePin,
        child: _isLoading
            ? const SizedBox(
                height: 20, width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
            : const Text('Save PIN & Enter App'),
      ),
    ],
  );
}

// ─── Shared small widgets ──────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int currentStep;
  const _StepIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (i) {
        final isActive   = i == currentStep;
        final isDone     = i < currentStep;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < 2 ? 8 : 0),
            child: Column(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 4,
                decoration: BoxDecoration(
                  color: isDone || isActive ? AppColors.teal : AppColors.grey200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                ['Phone', 'Verify', 'PIN'][i],
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
                  color: isActive ? AppColors.teal : AppColors.grey500,
                ),
              ),
            ]),
          ),
        );
      }),
    );
  }
}

class _StepHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _StepHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: AppColors.tealLight,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.teal, size: 36),
      ),
      const SizedBox(height: 16),
      Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.grey900,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        subtitle,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.grey600,
          height: 1.5,
        ),
      ),
    ]);
  }
}

class _PinInputField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  const _PinInputField({required this.controller, required this.label});

  @override
  State<_PinInputField> createState() => _PinInputFieldState();
}

class _PinInputFieldState extends State<_PinInputField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      keyboardType: TextInputType.number,
      maxLength: 4,
      obscureText: _obscure,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: 12,
      ),
      decoration: InputDecoration(
        labelText: widget.label,
        counterText: '',
        suffixIcon: IconButton(
          icon: Icon(_obscure
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}