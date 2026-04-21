import 'package:flutter/material.dart';
import '../services/remote_auth_service.dart';
import '../main.dart'; // To access AppColors

class MemberAccessValidationDialog extends StatefulWidget {
  final String memberName;
  final String memberId;
  final String familyId;

  const MemberAccessValidationDialog({
    super.key,
    required this.memberName,
    required this.memberId,
    required this.familyId,
  });

  static Future<bool> show(
    BuildContext context, {
    required String memberName,
    required String memberId,
    required String familyId,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => MemberAccessValidationDialog(
        memberName: memberName,
        memberId: memberId,
        familyId: familyId,
      ),
    );
    return result ?? false;
  }

  @override
  State<MemberAccessValidationDialog> createState() => _MemberAccessValidationDialogState();
}

class _MemberAccessValidationDialogState extends State<MemberAccessValidationDialog> {
  final _authService = RemoteAuthService.instance;
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  bool _loading = false;
  String? _errorMessage;

Future<void> _validateAccess() async {
  print("--- DEBUG ACCESS ---");
  print("Looking for Document ID: ${widget.memberId}");
  
  final userDoc = await _authService.getUserDocument(widget.memberId);
  
  if (userDoc == null) {
    print("RESULT: Document NOT found in Firestore.");
  } else {
    print("RESULT: Document found! Phone in DB is: ${userDoc['phone']}");
  }

  setState(() {
    _loading = true;
    _errorMessage = null;
  });

  try {
    // 1. Get the member document
    final userDoc = await _authService.getUserDocument(widget.memberId);
    
    if (userDoc == null) {
      // DEBUG TIP: If you see this, the ID passed to this dialog 
      // doesn't match any Document ID in the 'users' collection.
      throw Exception('Member ID not found in system.');
    }

    // 2. Fix: Cast phone to String to prevent comparison errors
    final String? storedPhone = userDoc['phone']?.toString();
    
    if (storedPhone == null) {
      throw Exception('No phone number assigned to this member.');
    }

    final String enteredPhone = _phoneController.text.trim();
    final String enteredPin = _pinController.text.trim();

    // 3. Verify Phone number
    if (enteredPhone != storedPhone) {
      throw Exception('Invalid phone number.');
    }

    // 4. Check if this is the FIRST time setup or a regular login
    // Using your Firestore field 'pin_hash'
    final dynamic rawPinHash = userDoc['pin_hash'];
    bool isFirstTimeSetup = (rawPinHash == null || rawPinHash.toString().isEmpty);

    if (isFirstTimeSetup) {
      if (enteredPin.length < 4) throw Exception('PIN must be at least 4 digits');
      
      await _authService.setupMemberPin(
        userId: widget.memberId,
        phoneNumber: enteredPhone,
        newPin: enteredPin,
      );
    } else {
      final isPinValid = await _authService.verifyPin(widget.memberId, enteredPin);
      
      if (!isPinValid) {
        await _authService.recordFailedAttempt(widget.memberId, widget.familyId, 'pin');
        throw Exception('Invalid PIN');
      }
    }

    // 5. Audit Log
    final currentAdminId = await _authService.userId;
    await _authService.recordAccessSession(
      accessorId: currentAdminId ?? 'unknown',
      targetMemberId: widget.memberId,
      familyId: widget.familyId,
      accessType: isFirstTimeSetup ? 'pin_setup' : 'vault_access',
    );

    if (!mounted) return;
    Navigator.pop(context, true); 
    
  } catch (e) {
    if (!mounted) return;
    setState(() {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _loading = false;
    });
  }
}

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Access ${widget.memberName}\'s Vault'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _phoneController,
            decoration: const InputDecoration(labelText: 'Phone Number'),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pinController,
            decoration: const InputDecoration(labelText: '4-Digit PIN'),
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 4,
          ),
          if (_errorMessage != null)
            Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12)),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        ElevatedButton(onPressed: _loading ? null : _validateAccess, child: const Text('Verify')),
      ],
    );
  }
}