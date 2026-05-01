import 'package:flutter/material.dart';
import '../services/remote_auth_service.dart';
import '../utils/auth_helpers.dart';
import '../main.dart';

/// PinCheckScreen: Periodic PIN verification screen
/// Shows when a member logs back in and PIN has been set
/// Forces PIN entry before accessing dashboard
class PinCheckScreen extends StatefulWidget {
  final String phone;
  final String familyId;

  const PinCheckScreen({
    required this.phone,
    required this.familyId,
    super.key,
  });

  @override
  State<PinCheckScreen> createState() => _PinCheckScreenState();
}

class _PinCheckScreenState extends State<PinCheckScreen> {
  final _pinController = TextEditingController();
  final _authService = RemoteAuthService();

  bool _isLoading = false;
  String? _errorMessage;
  int _failedAttempts = 0;
  bool _isLocked = false;
  int _lockoutMinutesRemaining = 0;
  late DateTime _lockoutExpiry;

  @override
  void dispose() {
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

  void _clearPin() {
    setState(() => _pinController.clear());
    _clearError();
  }

  void _clearError() => setState(() => _errorMessage = null);

  Future<void> _handlePinSubmit() async {
    if (_isLocked) {
      _showError('Account is locked. Please try again later.');
      return;
    }

    final pin = _pinController.text;
    if (pin.isEmpty || pin.length != 4) {
      _showError('Please enter your 4-digit PIN');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final familyId = await _authService.signInWithPin(
        phone: widget.phone,
        pin: pin,
      );

      // Mark PIN as verified for this session
      await markPinVerifiedThisSession(widget.phone);

      if (mounted) {
        Navigator.of(context).pushReplacementNamed(
          '/persistent_dashboard',
          arguments: {'familyId': familyId, 'memberPhone': widget.phone},
        );
      }
    } catch (e) {
      final errorMsg = e.toString().replaceFirst('Exception: ', '');
      if (errorMsg.contains('locked')) {
        setState(() {
          _isLocked = true;
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
          _isLocked = false;
          _failedAttempts = 0;
          _pinController.clear();
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
              color: _isLocked ? Colors.grey : backgroundColor,
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
    final isMobile = screenWidth < 600;
    final padding = isMobile ? 16.0 : 32.0;

    return WillPopScope(
      onWillPop: () async => false,  // Prevent back button
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Verify PIN'),
          backgroundColor: Colors.teal,
          automaticallyImplyLeading: false,
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
                  'Enter your PIN to continue',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 28,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'For your security, enter your 4-digit PIN',
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

                // ── PIN Display ────────────────────────────────────────────────
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

                // ── Keypad ─────────────────────────────────────────────────────
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

                // ── Verify button ──────────────────────────────────────────────
                _buildActionButton(
                  label: _isLoading ? 'Verifying...' : 'Verify',
                  onPressed: _isLoading ? () {} : _handlePinSubmit,
                  backgroundColor: Colors.teal,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

double _min(double a, double b) => a < b ? a : b;
