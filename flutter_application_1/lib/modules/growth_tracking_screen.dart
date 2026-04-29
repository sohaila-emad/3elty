import 'package:flutter/material.dart';
import '../main.dart';
import '../data/app_repository.dart';
import '../services/remote_auth_service.dart';

class GrowthTrackingScreen extends StatefulWidget {
  final FamilyMember member;
  const GrowthTrackingScreen({super.key, required this.member});

  @override
  State<GrowthTrackingScreen> createState() => _GrowthTrackingScreenState();
}

class _GrowthTrackingScreenState extends State<GrowthTrackingScreen> {
  final _repo = AppRepository.instance;
  final _authService = RemoteAuthService();
  List<dynamic> _vitals = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadVitals();
  }

  // --- SMART ANALYZER ---
  // Returns health status and color based on age-specific growth standards
  Map<String, dynamic> getSmartFeedback(String type, double value, int ageInYears) {
    if (type == 'weight') {
      if (ageInYears < 1) { // Infants (0-1 year)
        if (value < 2.5) return {'msg': 'Severely Underweight', 'color': Colors.red};
        if (value > 12.0) return {'msg': 'Overweight for Age', 'color': Colors.orange};
      } else if (ageInYears <= 5) { // Toddlers (1-5 years)
        if (value < 9.0) return {'msg': 'Underweight', 'color': Colors.orange};
        if (value > 25.0) return {'msg': 'Overweight', 'color': Colors.orange};
      } else { // Older children
        if (value < 20.0) return {'msg': 'Underweight', 'color': Colors.orange};
        if (value > 60.0) return {'msg': 'Overweight', 'color': Colors.orange};
      }
      return {'msg': 'Healthy Weight', 'color': Colors.green};
    } else { // Height
      if (ageInYears < 1) { // Infant length
        if (value < 40) return {'msg': 'Very Short Stature', 'color': Colors.red};
        if (value > 85) return {'msg': 'Unusually Tall', 'color': Colors.blue};
      } else if (ageInYears <= 5) { // Toddlers
        if (value < 75) return {'msg': 'Below Average Height', 'color': Colors.orange};
        if (value > 125) return {'msg': 'Above Average Height', 'color': Colors.blue};
      }
      return {'msg': 'Normal Height', 'color': Colors.green};
    }
  }

  // --- LOGICAL VALIDATION ---
  // Blocks impossible data entry based on age to ensure data integrity
  String? validateEntry(String type, double value, int ageInYears) {
    if (type == 'height') {
      // Logic: A 3-month-old (age < 1) cannot be 120cm
      if (ageInYears < 1 && value > 90) return "Height exceeds infant limits (< 90cm)";
      if (ageInYears < 3 && value > 120) return "Height exceeds toddler limits (< 120cm)";
      if (value < 20 || value > 250) return "Invalid height range (20-250cm)";
    } else if (type == 'weight') {
      if (ageInYears < 1 && value > 15) return "Weight exceeds infant limits (< 15kg)";
      if (value < 0.5 || value > 200) return "Invalid weight range (0.5-200kg)";
    }
    return null; // Passes validation
  }

  Future<void> _loadVitals() async {
    if (widget.member.id == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      if (mounted) setState(() => _loading = true);
      final vitals = await _repo.getVitalsForMember(widget.member.id!);
      if (!mounted) return;
      final filtered = vitals.where((v) => v.type == 'height' || v.type == 'weight').toList();
      setState(() {
        _vitals = filtered;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      _showError('Error loading data: $e');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: AppColors.red, behavior: SnackBarBehavior.floating, content: Text(msg)),
    );
  }

  void _showAddHeightWeightDialog() {
    final hCtrl = TextEditingController();
    final wCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تسجيل بيانات النمو', textAlign: TextAlign.right),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: hCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'الطول (سم)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.straighten, color: AppColors.teal),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: wCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'الوزن (كجم)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.scale, color: AppColors.teal),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final hVal = double.tryParse(hCtrl.text.trim());
              final wVal = double.tryParse(wCtrl.text.trim());

              if (hVal == null && wVal == null) {
                _showError('Please enter valid numbers');
                return;
              }

              // Apply Logic Validation based on age before saving
              if (hVal != null) {
                final err = validateEntry('height', hVal, widget.member.age);
                if (err != null) { _showError(err); return; }
              }
              if (wVal != null) {
                final err = validateEntry('weight', wVal, widget.member.age);
                if (err != null) { _showError(err); return; }
              }

              final nav = Navigator.of(ctx);
              try {
                final familyId = await _authService.familyId;
                if (familyId == null) return;

                if (hVal != null) {
                  await _repo.insertVital(VitalRecord(
                    familyId: familyId, memberId: widget.member.id!,
                    type: 'height', value: hVal, unit: 'cm',
                  ));
                }
                if (wVal != null) {
                  await _repo.insertVital(VitalRecord(
                    familyId: familyId, memberId: widget.member.id!,
                    type: 'weight', value: wVal, unit: 'kg',
                  ));
                }
                nav.pop();
                _loadVitals();
              } catch (e) {
                _showError('Save failed: $e');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal),
            child: const Text('حفظ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.member.profileType;
    
    return Scaffold(
      backgroundColor: AppColors.grey50,
      appBar: AppBar(title: const Text('تتبع النمو')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
          : CustomScrollView(
              slivers: [
                // Profile Header (Retained UI)
                SliverToBoxAdapter(
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(color: t.bgColor, borderRadius: BorderRadius.circular(12)),
                          child: Icon(t.icon, color: t.color),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.member.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            Text('${widget.member.age} Years Old', style: const TextStyle(color: AppColors.grey600)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: Divider(height: 1)),
                
                // History List with Feedback (Retained UI with Smart Color Logic)
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList.separated(
                    itemCount: _vitals.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final vital = _vitals[index];
                      final isHeight = vital.type == 'height';
                      final feedback = getSmartFeedback(vital.type, vital.value, widget.member.age);

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: feedback['color'].withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(isHeight ? Icons.straighten : Icons.scale, color: feedback['color'], size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(isHeight ? 'الطول' : 'الوزن', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  Text(feedback['msg'], style: TextStyle(color: feedback['color'], fontSize: 12, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('${vital.value} ${vital.unit}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.grey900)),
                                Text(vital.recordedAt?.toString().split(' ').first ?? '', style: const TextStyle(fontSize: 11, color: AppColors.grey500)),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddHeightWeightDialog,
        backgroundColor: AppColors.teal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}