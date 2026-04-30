import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../services/remote_auth_service.dart';

// ─── Constants ────────────────────────────────────────────────────────────────
const String _kPinPrefix        = 'member_pin_';       // secure storage
const String _kLoginCountPrefix = 'login_count_';     // shared prefs
const int    _kPinPromptEvery   = 10;                 // ask PIN every N logins

// ─── Helper: check if this phone is already set up on this device ─────────────
Future<bool> isPhoneSetupOnDevice(String phone) async {
  final storage = const FlutterSecureStorage();
  final pin = await storage.read(key: '$_kPinPrefix$phone');
  return pin != null;
}

// ─── Helper: get + increment login count, return whether PIN is needed ────────
Future<bool> shouldAskPinThisLogin(String phone) async {
  final prefs = await SharedPreferences.getInstance();
  final key   = '$_kLoginCountPrefix$phone';
  final count = (prefs.getInt(key) ?? 0) + 1;
  await prefs.setInt(key, count);
  // Ask PIN on the 1st login (always) and every _kPinPromptEvery after that
  return count == 1 || count % _kPinPromptEvery == 0;
}

// ─── Helper: read stored PIN ──────────────────────────────────────────────────
Future<String?> getStoredPin(String phone) async {
  final storage = const FlutterSecureStorage();
  return storage.read(key: '$_kPinPrefix$phone');
}

// ─── Helper: save PIN ─────────────────────────────────────────────────────────
Future<void> savePin(String phone, String pin) async {
  final storage = const FlutterSecureStorage();
  await storage.write(key: '$_kPinPrefix$phone', value: pin);
}

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
    final formatted = phone.startsWith('+') ? phone : '+20$phone';

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
      final phone = _normalizePhone(_phoneCtrl.text.trim());

      // Save PIN locally on device
      await savePin(phone, pin1);

      // Also store PIN hash in Firestore via RemoteAuthService
      await _remoteAuth.setupMemberPinByPhone(
        phone: phone,
        pin: pin1,
      );

      // Sign in to app session
      final familyId = await _remoteAuth.signInWithPin(
        phone: phone,
        pin: pin1,
      );

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

  String _normalizePhone(String phone) =>
      phone.startsWith('+') ? phone : '+20$phone';

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
          hintText: '01XXXXXXXXX',
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

// ═══════════════════════════════════════════════════════════════════════════════
// SCREEN: PIN Check  (shown every 10 logins)
// ═══════════════════════════════════════════════════════════════════════════════
class PinCheckScreen extends StatefulWidget {
  final String phone;
  final String familyId;
  const PinCheckScreen({
    super.key,
    required this.phone,
    required this.familyId,
  });

  @override
  State<PinCheckScreen> createState() => _PinCheckScreenState();
}

class _PinCheckScreenState extends State<PinCheckScreen> {
  final _pinCtrl     = TextEditingController();
  bool  _isLoading   = false;
  String? _error;
  int   _attempts    = 0;

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkPin() async {
    final entered = _pinCtrl.text;
    if (entered.length != 4) {
      setState(() => _error = 'Please enter your 4-digit PIN');
      return;
    }

    setState(() { _isLoading = true; _error = null; });

    final stored = await getStoredPin(widget.phone);
    if (stored == entered) {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(
        '/persistent_dashboard',
        arguments: {
          'familyId': widget.familyId,
          'memberPhone': widget.phone,
        },
      );
    } else {
      _attempts++;
      setState(() {
        _isLoading = false;
        _error = _attempts >= 3
            ? 'Too many wrong attempts. Please try again later.'
            : 'Incorrect PIN. ${3 - _attempts} attempt(s) remaining.';
      });
      _pinCtrl.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey50,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: AppColors.tealLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  size: 48,
                  color: AppColors.teal,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Security Check',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.grey900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please enter your PIN to continue',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: AppColors.grey600),
              ),
              const SizedBox(height: 40),
              _PinInputField(controller: _pinCtrl, label: 'Enter PIN'),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading || _attempts >= 3 ? null : _checkPin,
                child: _isLoading
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                    : const Text('Continue'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.redLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
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