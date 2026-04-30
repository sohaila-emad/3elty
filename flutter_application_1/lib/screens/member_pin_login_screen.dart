import 'package:flutter/material.dart';
import '../services/remote_auth_service.dart';
import '../utils/auth_helpers.dart';
import 'first_time_setup_screen.dart';

class MemberPinLoginScreen extends StatefulWidget {
  const MemberPinLoginScreen({super.key});

  @override
  State<MemberPinLoginScreen> createState() => _MemberPinLoginScreenState();
}

class _MemberPinLoginScreenState extends State<MemberPinLoginScreen> {
  final _phoneController = TextEditingController();
  final _pinController   = TextEditingController();
  final _authService     = RemoteAuthService();

  bool    _isLoading               = false;
  String? _errorMessage;
  int     _failedAttempts          = 0;
  bool    _isLocked                = false;
  int     _lockoutMinutesRemaining = 0;
  late DateTime _lockoutExpiry;
  bool    _isReturningUser         = false; // ← NEW: shows PIN after phone check

  @override
  void dispose() {
    _phoneController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _addPinDigit(String digit) {
    if (_pinController.text.length < 4 && !_isLocked) {
      setState(() => _pinController.text += digit);
      _clearError();
    }
  }

  void _removePinDigit() {
    if (_pinController.text.isNotEmpty && !_isLocked) {
      setState(() {
        _pinController.text =
            _pinController.text.substring(0, _pinController.text.length - 1);
      });
      _clearError();
    }
  }

  void _clearPhone() {
    setState(() {
      _phoneController.clear();
      _isReturningUser = false; // ← reset so PIN hides again
      _pinController.clear();
    });
    _clearError();
  }

  void _clearPin() {
    setState(() => _pinController.clear());
    _clearError();
  }

  void _clearError() => setState(() => _errorMessage = null);

  Future<void> _handleLogin() async {
    if (_isLocked) {
      _showError('Account is locked. Please try again later.');
      return;
    }

    final rawPhone = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (rawPhone.length < 9) {
      _showError('Please enter a valid phone number');
      return;
    }

    final phone = normalizePhoneNumber(_phoneController.text);
    setState(() => _isLoading = true);

    try {
      // ── PHASE 1: Phone not yet verified as returning user ────────────────
      if (!_isReturningUser) {
        final isRegistered = await _authService.isPhoneRegisteredByAdmin(phone);
        if (!isRegistered) {
          _showError(
            'This phone number is not registered.\nAsk your admin to add you first.',
          );
          setState(() => _isLoading = false);
          return;
        }

        final isSetUp = await isPhoneSetupOnDevice(phone);
        if (!isSetUp) {
          // First time on this device → go to OTP + PIN setup
          if (mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const FirstTimeSetupScreen(),
              ),
            );
          }
          setState(() => _isLoading = false);
          return;
        }

        // Returning user confirmed — show PIN fields
        setState(() {
          _isReturningUser = true;
          _isLoading = false;
        });
        return;
      }

      // ── PHASE 2: Returning user — validate PIN ───────────────────────────
      final pin = _pinController.text;
      if (pin.isEmpty || pin.length != 4) {
        _showError('Please enter your 4-digit PIN');
        setState(() => _isLoading = false);
        return;
      }

      final familyId = await _authService.signInWithPin(
        phone: phone,
        pin: pin,
      );

      if (mounted) {
        Navigator.of(context).pushReplacementNamed(
          '/persistent_dashboard',
          arguments: {'familyId': familyId, 'memberPhone': phone},
        );
      }
    } catch (e) {
      final errorMsg = e.toString().replaceFirst('Exception: ', '');
      if (errorMsg.contains('locked')) {
        setState(() {
          _isLocked      = true;
          _lockoutExpiry = DateTime.now().add(const Duration(minutes: 30));
          _startLockoutCountdown();
        });
      } else if (errorMsg.contains('Attempts remaining')) {
        final parts = errorMsg.split('Attempts remaining: ');
        if (parts.length > 1) {
          final remaining = int.tryParse(parts[1].split(')').first) ?? 0;
          setState(() => _failedAttempts = remaining);
        }
      }
      _showError(errorMsg);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    setState(() => _errorMessage = message);
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) _clearError();
    });
  }

  void _startLockoutCountdown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      final remaining = _lockoutExpiry.difference(DateTime.now()).inMinutes;
      if (remaining <= 0) {
        setState(() {
          _isLocked        = false;
          _failedAttempts  = 0;
          _isReturningUser = false;
          _clearPhone();
          _clearPin();
        });
        _showError('Account unlocked. You can try again.');
        return false;
      }
      setState(() => _lockoutMinutesRemaining = remaining);
      return true;
    });
  }

  Widget _buildKeypadButton(String digit, {VoidCallback? onPressed}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isLocked ? null : onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: _isLocked ? Colors.grey[300] : Colors.teal.shade50,
            border: Border.all(
              color: _isLocked ? Colors.grey : Colors.teal,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              digit,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: _isLocked ? Colors.grey : Colors.teal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required VoidCallback onPressed,
    required Color backgroundColor,
    Color textColor = Colors.white,
  }) {
    return SizedBox(
      height: 56,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLocked ? null : onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: _isLocked
                  ? Colors.grey
                  : backgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile    = screenWidth < 600;
    final padding     = isMobile ? 16.0 : 32.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Member Login'),
        backgroundColor: Colors.teal,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),

              Text(
                _isReturningUser ? 'Enter your PIN' : 'Member Login',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 28,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                _isReturningUser
                    ? 'Enter your 4-digit PIN to continue'
                    : 'Enter your phone number to continue',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
              ),
              const SizedBox(height: 32),

              // ── Error message ──────────────────────────────────────────────
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _isLocked ? Colors.orange[50] : Colors.red[50],
                    border: Border.all(
                      color: _isLocked ? Colors.orange : Colors.red,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: _isLocked ? Colors.orange[900] : Colors.red[900],
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── Lockout timer ──────────────────────────────────────────────
              if (_isLocked) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.yellow[50],
                    border: Border.all(color: Colors.orange, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(children: [
                    Text(
                      'Account Locked',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[900],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Try again in $_lockoutMinutesRemaining '
                      'minute${_lockoutMinutesRemaining != 1 ? 's' : ''}',
                      style: TextStyle(fontSize: 16, color: Colors.orange[700]),
                    ),
                  ]),
                ),
                const SizedBox(height: 24),
              ],

              // ── Phone field (always visible, locked after phase 1) ─────────
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _isReturningUser ? Colors.teal : Colors.teal,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _phoneController,
                  enabled: !_isLocked && !_isReturningUser, // ← locked after phase 1
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    hintText: '1XXXXXXXXX',
                    border: InputBorder.none,
                    prefixText: '+20  ',
                    prefixStyle: const TextStyle(
                      color: Colors.teal,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    prefixIcon: Icon(Icons.phone, size: 24, color: Colors.teal[700]),
                    suffixIcon: _isReturningUser
                        ? IconButton(
                            icon: const Icon(Icons.edit_rounded,
                                size: 22, color: Colors.teal),
                            tooltip: 'Change number',
                            onPressed: _clearPhone, // ← lets user go back to phase 1
                          )
                        : _phoneController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear,
                                    size: 24, color: Colors.red[700]),
                                onPressed: _clearPhone,
                              )
                            : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    labelStyle: const TextStyle(fontSize: 16),
                  ),
                  onChanged: (value) => setState(() {}),
                ),
              ),
              const SizedBox(height: 24),

              // ── PIN section (only shown for returning users) ───────────────
              if (_isReturningUser) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    border: Border.all(color: Colors.teal, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(children: [
                    Text(
                      'PIN',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        4,
                        (index) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: index < _pinController.text.length
                                ? Colors.teal
                                : Colors.white,
                            border: Border.all(color: Colors.teal, width: 2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: index < _pinController.text.length
                                ? const Text(
                                    '●',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 24),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 24),

                // Failed attempts counter
                if (_failedAttempts > 0 && !_isLocked) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      border: Border.all(color: Colors.orange, width: 1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Failed attempts: $_failedAttempts / 5',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.orange[900],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Keypad
                Container(
                  constraints: BoxConstraints(
                      maxWidth: _min(screenWidth - padding * 2, 320)),
                  child: GridView.count(
                    crossAxisCount: 3,
                    childAspectRatio: 1.2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildKeypadButton('1', onPressed: () => _addPinDigit('1')),
                      _buildKeypadButton('2', onPressed: () => _addPinDigit('2')),
                      _buildKeypadButton('3', onPressed: () => _addPinDigit('3')),
                      _buildKeypadButton('4', onPressed: () => _addPinDigit('4')),
                      _buildKeypadButton('5', onPressed: () => _addPinDigit('5')),
                      _buildKeypadButton('6', onPressed: () => _addPinDigit('6')),
                      _buildKeypadButton('7', onPressed: () => _addPinDigit('7')),
                      _buildKeypadButton('8', onPressed: () => _addPinDigit('8')),
                      _buildKeypadButton('9', onPressed: () => _addPinDigit('9')),
                      _buildKeypadButton('⌫', onPressed: _removePinDigit),
                      _buildKeypadButton('0', onPressed: () => _addPinDigit('0')),
                      _buildKeypadButton('C', onPressed: _clearPin),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // ── Confirm button ─────────────────────────────────────────────
              _buildActionButton(
                label: _isLoading
                    ? 'Checking...'
                    : _isReturningUser
                        ? 'Login'
                        : 'Continue',
                onPressed: _isLoading ? () {} : _handleLogin,
                backgroundColor: Colors.teal,
              ),
              const SizedBox(height: 12),

              _buildActionButton(
                label: 'Back to Family Login',
                onPressed: () => Navigator.of(context).pop(),
                backgroundColor: Colors.grey[400]!,
                textColor: Colors.black87,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

double _min(double a, double b) => a < b ? a : b;