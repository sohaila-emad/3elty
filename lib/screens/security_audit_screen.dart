import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart';
import '../services/remote_auth_service.dart';

/// Screen showing security audit log - who has accessed this member's data and when.
/// Provides transparency and privacy awareness for data access.
class SecurityAuditScreen extends StatefulWidget {
  final String memberId;
  final String memberName;

  const SecurityAuditScreen({
    super.key,
    required this.memberId,
    required this.memberName,
  });

  @override
  State<SecurityAuditScreen> createState() => _SecurityAuditScreenState();
}

class _SecurityAuditScreenState extends State<SecurityAuditScreen> {
  final _authService = RemoteAuthService();
  List<Map<String, dynamic>> _accessHistory = [];
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAccessHistory();
  }

  Future<void> _loadAccessHistory() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final history = await _authService.getMemberAccessHistory(widget.memberId);
      if (!mounted) return;
      setState(() {
        _accessHistory = history;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not load access history: $e';
        _loading = false;
      });
    }
  }

  String _formatAccessType(String accessType) {
    final map = {
      'view_profile': 'Viewed Profile',
      'view_vitals': 'Viewed Vitals',
      'view_medications': 'Viewed Medications',
      'view_appointments': 'Viewed Appointments',
      'view_documents': 'Viewed Documents',
    };
    return map[accessType] ?? accessType;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey50,
      appBar: AppBar(
        title: const Text('Security & Privacy'),
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.teal),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.tealLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.lock_outline_rounded,
                          color: AppColors.teal,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Your Data is Private',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.teal,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Each access to your health data requires PIN validation. View all access below.',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.teal,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Access history section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Access History',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.grey900,
                        ),
                      ),
                      if (_accessHistory.isNotEmpty)
                        TextButton.icon(
                          onPressed: _loadAccessHistory,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Refresh'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Error message
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.redLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: AppColors.red,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Access list
                  if (_accessHistory.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: const BoxDecoration(
                                color: AppColors.tealLight,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.shield_rounded,
                                size: 40,
                                color: AppColors.teal,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No access yet',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.grey900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Your data access will appear here',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.grey600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _accessHistory.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final access = _accessHistory[i];
                        final accessedAt =
                            (access['accessed_at'] as Timestamp?)?.toDate() ??
                                DateTime.now();
                        final formattedTime =
                            DateFormat('MMM dd, yyyy • h:mm a').format(accessedAt);
                        final accessType =
                            _formatAccessType(access['access_type'] as String? ?? 'Unknown');

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.grey200),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.tealLight,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.visibility_rounded,
                                  color: AppColors.teal,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      accessType,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.grey900,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      formattedTime,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.grey600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.green,
                                size: 20,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 24),
                  // Privacy info section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.grey200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'How Your Privacy is Protected',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.grey900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _PrivacyBullet(
                          icon: Icons.verified_user_rounded,
                          text:
                              'PIN validation required for each access to your data',
                        ),
                        const SizedBox(height: 8),
                        _PrivacyBullet(
                          icon: Icons.history_rounded,
                          text: 'All access is logged and auditable',
                        ),
                        const SizedBox(height: 8),
                        _PrivacyBullet(
                          icon: Icons.block_rounded,
                          text:
                              'Family members cannot bypass your PIN protection',
                        ),
                        const SizedBox(height: 8),
                        _PrivacyBullet(
                          icon: Icons.vpn_lock_rounded,
                          text: 'Encrypted end-to-end in Firestore',
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

class _PrivacyBullet extends StatelessWidget {
  final IconData icon;
  final String text;

  const _PrivacyBullet({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.teal, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.grey600,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
