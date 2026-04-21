import 'package:flutter/material.dart';
import '../main.dart';
import '../data/app_repository.dart';

class VitalThresholdDialog extends StatefulWidget {
  final String memberId;
  final String familyId;
  final String vitalType;
  final String displayName;
  final String unit;
  final VoidCallback onSaved;

  const VitalThresholdDialog({
    super.key,
    required this.memberId,
    required this.familyId,
    required this.vitalType,
    required this.displayName,
    required this.unit,
    required this.onSaved,
  });

  @override
  State<VitalThresholdDialog> createState() => _VitalThresholdDialogState();
}

class _VitalThresholdDialogState extends State<VitalThresholdDialog> {
  final _repo = AppRepository.instance;
  
  late TextEditingController _dangerMinCtrl;
  late TextEditingController _dangerMaxCtrl;
  late TextEditingController _warningMinCtrl;
  late TextEditingController _warningMaxCtrl;
  
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _dangerMinCtrl = TextEditingController();
    _dangerMaxCtrl = TextEditingController();
    _warningMinCtrl = TextEditingController();
    _warningMaxCtrl = TextEditingController();
    _loadThresholds();
  }

  Future<void> _loadThresholds() async {
    try {
      final threshold = await _repo.getVitalThreshold(
        widget.memberId,
        widget.vitalType,
      );

      if (mounted) {
        setState(() {
          if (threshold != null) {
            _dangerMinCtrl.text = (threshold['danger_min'] ?? '').toString();
            _dangerMaxCtrl.text = (threshold['danger_max'] ?? '').toString();
            _warningMinCtrl.text = (threshold['warning_min'] ?? '').toString();
            _warningMaxCtrl.text = (threshold['warning_max'] ?? '').toString();
          }
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveThresholds() async {
    // Validate inputs
    final dangerMin = _dangerMinCtrl.text.isEmpty ? null : double.tryParse(_dangerMinCtrl.text);
    final dangerMax = _dangerMaxCtrl.text.isEmpty ? null : double.tryParse(_dangerMaxCtrl.text);
    final warningMin = _warningMinCtrl.text.isEmpty ? null : double.tryParse(_warningMinCtrl.text);
    final warningMax = _warningMaxCtrl.text.isEmpty ? null : double.tryParse(_warningMaxCtrl.text);

    if (dangerMin == null && dangerMax == null) {
      _showError('Please set at least one danger threshold');
      return;
    }

    try {
      setState(() => _saving = true);
      
      await _repo.setVitalThreshold(
        memberId: widget.memberId,
        familyId: widget.familyId,
        vitalType: widget.vitalType,
        dangerMin: dangerMin,
        dangerMax: dangerMax,
        warningMin: warningMin,
        warningMax: warningMax,
      );

      if (mounted) {
        setState(() => _saving = false);
        widget.onSaved();
        Navigator.pop(context);
        _showSuccess('Thresholds saved for ${widget.displayName}');
      }
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      _showError('Failed to save thresholds: $e');
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: AppColors.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: Text(msg, style: const TextStyle(color: Colors.white)),
    ),
  );

  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: AppColors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: Text(msg, style: const TextStyle(color: Colors.white)),
    ),
  );

  @override
  void dispose() {
    _dangerMinCtrl.dispose();
    _dangerMaxCtrl.dispose();
    _warningMinCtrl.dispose();
    _warningMaxCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: _loading
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.tealLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.warning_rounded,
                            color: AppColors.teal,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Set Safety Limits',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'for ${widget.displayName} (${widget.unit})',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Info text
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.greenLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'When your reading exceeds these limits, you\'ll receive an alert.',
                        style: TextStyle(
                          color: AppColors.green,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // DANGER thresholds (highlighted in red)
                    _buildThresholdSection(
                      title: '🔴 DANGER Zone',
                      color: AppColors.red,
                      minCtrl: _dangerMinCtrl,
                      maxCtrl: _dangerMaxCtrl,
                      minLabel: 'Dangerously LOW',
                      maxLabel: 'Dangerously HIGH',
                    ),
                    const SizedBox(height: 20),

                    // WARNING thresholds (highlighted in orange)
                    _buildThresholdSection(
                      title: '🟡 WARNING Zone',
                      color: AppColors.orange,
                      minCtrl: _warningMinCtrl,
                      maxCtrl: _warningMaxCtrl,
                      minLabel: 'Below ideal',
                      maxLabel: 'Above ideal',
                    ),
                    const SizedBox(height: 24),

                    // Example guidance
                    _buildGuidance(),
                    const SizedBox(height: 24),

                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _saving ? null : () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.teal,
                            minimumSize: const Size(100, 44),
                          ),
                          onPressed: _saving ? null : _saveThresholds,
                          child: _saving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Save',
                                  style: TextStyle(color: Colors.white),
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildThresholdSection({
    required String title,
    required Color color,
    required TextEditingController minCtrl,
    required TextEditingController maxCtrl,
    required String minLabel,
    required String maxLabel,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: minCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: minLabel,
                    hintText: 'Min',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.all(8),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: maxCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: maxLabel,
                    hintText: 'Max',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.all(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGuidance() {
    String guidance = '';
    
    switch (widget.vitalType) {
      case 'blood_pressure_systolic':
        guidance = '📊 Normal: < 120 | Elevated: 120-129\nDanger: ≥ 140 (Hypertensive Crisis)';
        break;
      case 'blood_pressure_diastolic':
        guidance = '📊 Normal: < 80 | Elevated: 80-89\nDanger: ≥ 90 (Hypertensive Crisis)';
        break;
      case 'blood_sugar':
        guidance = '📊 Fasting Normal: 70-100 | Prediabetes: 100-125\nDanger: < 70 (Low) or > 200 (High)';
        break;
      default:
        guidance = 'Set limits based on medical advice from your doctor.';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.grey100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Medical Guidelines:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            guidance,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.grey600,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
