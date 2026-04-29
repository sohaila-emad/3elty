import 'package:flutter/material.dart';
import '../main.dart';
import '../data/app_repository.dart';
import '../services/remote_auth_service.dart';

class MedicationsScreen extends StatefulWidget {
  final FamilyMember member;

  const MedicationsScreen({super.key, required this.member});

  @override
  State<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends State<MedicationsScreen> {
  final _repo = AppRepository.instance;
  final _authService = RemoteAuthService();
  List<dynamic> _medications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMedications();
  }

  Future<void> _loadMedications() async {
    if (widget.member.id == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      setState(() => _loading = true);
      final meds = await _repo.getMedicationsForMember(widget.member.id!);
      if (!mounted) return;
      setState(() {
        _medications = meds;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('Failed to load medications: $e');
    }
  }

  Future<void> _showAddMedicationDialog() async {
    final nameCtrl = TextEditingController();
    final doseCtrl = TextEditingController();
    final freqCtrl = TextEditingController();
    String selectedTime = 'Morning';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          20,
          24,
          MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.grey200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Add medication',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            TextField(
              controller: nameCtrl,
              decoration: _buildInputDecoration('Medication name', 'e.g. Aspirin'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: doseCtrl,
              decoration: _buildInputDecoration('Dose', 'e.g. 500mg'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: freqCtrl,
              decoration: _buildInputDecoration('Frequency', 'e.g. Twice daily'),
            ),
            const SizedBox(height: 14),
            const Text('Time of day',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.grey600)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: ['Morning', 'Afternoon', 'Evening', 'Night'].map((time) {
                return FilterChip(
                  label: Text(time),
                  selected: selectedTime == time,
                  onSelected: (_) {
                    setState(() => selectedTime = time);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.isEmpty || doseCtrl.text.isEmpty || freqCtrl.text.isEmpty) {
                    _showError('Please fill all fields');
                    return;
                  }
                  if (widget.member.id == null) {
                    _showError('Member not saved yet');
                    return;
                  }
                  try {
                    final familyId = await _authService.familyId;
                    if (familyId == null) {
                      _showError('Family not found. Please sign in again.');
                      return;
                    }
                    await _repo.insertMedication(MedicationRecord(
                      familyId: familyId,
                      memberId: widget.member.id!,
                      name: nameCtrl.text.trim(),
                      dose: doseCtrl.text.trim(),
                      frequency: freqCtrl.text.trim(),
                      timeOfDay: selectedTime,
                    ));
                    if (!mounted) return;
                    Navigator.pop(ctx);
                    _loadMedications();
                    _showSuccess('${nameCtrl.text} added');
                  } catch (e) {
                    _showError('Failed to add medication: $e');
                  }
                },
                child: const Text('Add medication'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label, String hint) => InputDecoration(
    labelText: label,
    hintText: hint,
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
  );

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: Text(msg, style: const TextStyle(color: Colors.white)),
    ));
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: Text(msg, style: const TextStyle(color: Colors.white)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.member.profileType;
    return Scaffold(
      backgroundColor: AppColors.grey50,
      appBar: AppBar(
        title: const Text('Medications'),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
          : Column(
              children: [
                // Member info banner
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: t.bgColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(t.icon, color: t.color, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.member.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.grey900,
                              ),
                            ),
                            Text(
                              t.label,
                              style: TextStyle(
                                fontSize: 13,
                                color: t.color,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Medications list
                Expanded(
                  child: _medications.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.medication_rounded,
                                size: 64,
                                color: AppColors.grey200,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No medications yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.grey600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Add a medication to get started',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.grey600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _medications.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final med = _medications[i];
                            return Material(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onLongPress: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Delete medication?'),
                                      content: Text('Remove ${med.name}?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx, false),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.red,
                                          ),
                                          onPressed: () => Navigator.pop(ctx, true),
                                          child: const Text(
                                            'Delete',
                                            style: TextStyle(color: Colors.white),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true && med.id != null) {
                                    try {
                                      await _repo.deleteMedication(med.id);
                                      _loadMedications();
                                      _showSuccess('Medication deleted');
                                    } catch (e) {
                                      _showError('Failed to delete: $e');
                                    }
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  med.name,
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.grey900,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  med.dose,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    color: AppColors.grey600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.tealLight,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              med.timeOfDay,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.teal,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Every ${med.frequency}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.grey600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddMedicationDialog,
        backgroundColor: AppColors.teal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add medication'),
      ),
    );
  }
}
