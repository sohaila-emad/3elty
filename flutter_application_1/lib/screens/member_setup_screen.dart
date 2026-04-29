import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../services/remote_auth_service.dart';
import '../utils/error_handler.dart';

/// Screen where a designated family member sets up a new member's credentials
/// (phone number and PIN).
/// 
/// Flow:
/// 1. Admin adds new family member (name, age, profile)
/// 2. Admin grants setup permission to one member
/// 3. That member uses this screen to enter phone + create PIN
/// 4. Once complete, member can log in with phone + PIN
/// 5. PIN validation required before accessing that member's data
class MemberSetupScreen extends StatefulWidget {
  final String newMemberId;
  final String newMemberName;
  final int newMemberAge;
  final String familyId;

  const MemberSetupScreen({
    super.key,
    required this.newMemberId,
    required this.newMemberName,
    required this.newMemberAge,
    required this.familyId,
  });

  @override
  State<MemberSetupScreen> createState() => _MemberSetupScreenState();
}

class _MemberSetupScreenState extends State<MemberSetupScreen> {
  final _authService = RemoteAuthService();
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  final _pinConfirmController = TextEditingController();
  
  bool _loading = false;
  String? _errorMessage;
  bool _showPin = false;
  String? _adminStoredPhone;
  bool _phoneVerified = false;

  @override
  void initState() {
    super.initState();
    _loadAdminStoredPhone();
  }

  Future<void> _loadAdminStoredPhone() async {
    try {
      final userDoc = await _authService.getUserDocument(widget.newMemberId);
      final phone = userDoc?['phone'];
      setState(() => _adminStoredPhone = phone);
    } catch (e) {
      setState(() => _errorMessage = 'تعذّر تحميل رقم الهاتف. تواصل مع المسؤول.');
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _pinController.dispose();
    _pinConfirmController.dispose();
    super.dispose();
  }

  Future<void> _verifyPhone() async {
    setState(() => _errorMessage = null);

    if (_phoneController.text.isEmpty) {
      setState(() => _errorMessage = 'رقم الهاتف مطلوب');
      return;
    }

    if (_adminStoredPhone == null || _adminStoredPhone!.isEmpty) {
      setState(() => _errorMessage = 'لم يُسجّل المسؤول رقم هاتف. تواصل مع المسؤول.');
      return;
    }

    // Verify entered phone matches admin-set phone
    if (_phoneController.text.trim() != _adminStoredPhone!.trim()) {
      setState(() => _errorMessage = 'رقم الهاتف لا يتطابق مع سجل المسؤول.');
      return;
    }

    // Phone verified!
    setState(() {
      _phoneVerified = true;
      _errorMessage = null;
    });
  }

  Future<void> _setupMember() async {
    // Clear previous errors
    setState(() => _errorMessage = null);

    // Validate PIN
    if (_pinController.text.isEmpty) {
      setState(() => _errorMessage = 'الـ PIN مطلوب');
      return;
    }
    if (_pinController.text.length != 4) {
      setState(() => _errorMessage = 'يجب أن يكون الـ PIN 4 أرقام بالضبط');
      return;
    }

    // Validate PIN confirmation
    if (_pinConfirmController.text != _pinController.text) {
      setState(() => _errorMessage = 'الـ PIN وتأكيده غير متطابقَين');
      return;
    }

    setState(() => _loading = true);

    try {
      // Save phone and PIN to member's document
      await _authService.setupMemberCredentials(
        memberId: widget.newMemberId,
        phone: _phoneController.text,
        pin: _pinController.text,
      );

      if (!mounted) return;

      // Show success message and navigate back
      ErrorHandler.showSuccess(
        context,
        'تم إعداد ${widget.newMemberName} بنجاح! يمكنه الآن تسجيل الدخول بالهاتف والـ PIN.',
      );

      // Wait a moment for user to see the message, then pop
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      Navigator.pop(context, true); // Return true to indicate success
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'خطأ في إعداد الفرد: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey50,
      appBar: AppBar(
        title: const Text('إعداد بيانات الفرد'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card with member info
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.grey200),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.tealLight,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.person_add_rounded,
                      color: AppColors.teal,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'إعداد بيانات',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.grey600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.newMemberName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.grey900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.newMemberAge} سنة',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.grey600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            // Instructions
            const Text(
              'إنشاء بيانات تسجيل الدخول',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.grey900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'أدخل رقم هاتف ${widget.newMemberName} وأنشئ PIN مكوّن من 4 أرقام للوصول إلى بياناته الصحية.',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.grey600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            // Phone number input
            Text(
              'رقم الهاتف',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.grey900,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneController,
              enabled: !_loading,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 10,
              decoration: InputDecoration(
                hintText: '01012345678',
                filled: true,
                fillColor: Colors.white,
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
                counterText: '',
              ),
            ),
            const SizedBox(height: 20),
            // PIN input
            Text(
              'إنشاء PIN من 4 أرقام',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.grey900,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _pinController,
              enabled: !_loading,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 4,
              obscureText: !_showPin,
              decoration: InputDecoration(
                hintText: '••••',
                filled: true,
                fillColor: Colors.white,
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
                suffixIcon: IconButton(
                  icon: Icon(
                    _showPin ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                    color: AppColors.grey600,
                  ),
                  onPressed: () => setState(() => _showPin = !_showPin),
                ),
                counterText: '',
              ),
            ),
            const SizedBox(height: 20),
            // PIN confirmation input
            Text(
              'تأكيد الـ PIN',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.grey900,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _pinConfirmController,
              enabled: !_loading,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 4,
              obscureText: !_showPin,
              decoration: InputDecoration(
                hintText: '••••',
                filled: true,
                fillColor: Colors.white,
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
                suffixIcon: IconButton(
                  icon: Icon(
                    _showPin ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                    color: AppColors.grey600,
                  ),
                  onPressed: () => setState(() => _showPin = !_showPin),
                ),
                counterText: '',
              ),
            ),
            // Error message
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.redLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 28),
            // Setup button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  disabledBackgroundColor: AppColors.grey200,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _loading ? null : _setupMember,
                child: _loading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Complete Setup',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            // Cancel button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  side: const BorderSide(color: AppColors.grey200),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _loading ? null : () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.grey600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
