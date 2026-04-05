import 'package:flutter/material.dart';
import '../main.dart';
import '../data/app_repository.dart';

class GrowthTrackingScreen extends StatefulWidget {
  final FamilyMember member;
  const GrowthTrackingScreen({super.key, required this.member});

  @override
  State<GrowthTrackingScreen> createState() => _GrowthTrackingScreenState();
}

class _GrowthTrackingScreenState extends State<GrowthTrackingScreen> {
  final _repo = AppRepository.instance;
  List<dynamic> _vitals = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadVitals();
  }

  Future<void> _loadVitals() async {
    if (widget.member.id == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      setState(() => _loading = true);
      final vitals = await _repo.getVitalsForMember(widget.member.id!);
      if (!mounted) return;
      final filtered = vitals.where((v) => v.type == 'height' || v.type == 'weight').toList();
      setState(() {
        _vitals = filtered;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('Failed to load growth data: $e');
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: AppColors.red, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), content: Text(msg, style: const TextStyle(color: Colors.white))));

  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: AppColors.green, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), content: Text(msg, style: const TextStyle(color: Colors.white))));

  void _showAddHeightWeightDialog() {
    final heightCtrl = TextEditingController();
    final weightCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log Growth Data'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: heightCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Height (cm)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.straighten, color: AppColors.teal),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: weightCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Weight (kg)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.scale, color: AppColors.teal),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final heightStr = heightCtrl.text.trim();
              final weightStr = weightCtrl.text.trim();
              
              if (heightStr.isEmpty && weightStr.isEmpty) {
                _showError('Please enter height or weight');
                return;
              }
              
              try {
                // Save height if provided
                if (heightStr.isNotEmpty) {
                  final height = double.tryParse(heightStr);
                  if (height == null || height <= 0) {
                    _showError('Height must be a valid positive number');
                    return;
                  }
                  await _repo.insertVital(VitalRecord(
                    memberId: widget.member.id!,
                    type: 'height',
                    value: height,
                    unit: 'cm',
                  ));
                }
                
                // Save weight if provided
                if (weightStr.isNotEmpty) {
                  final weight = double.tryParse(weightStr);
                  if (weight == null || weight <= 0) {
                    _showError('Weight must be a valid positive number');
                    return;
                  }
                  await _repo.insertVital(VitalRecord(
                    memberId: widget.member.id!,
                    type: 'weight',
                    value: weight,
                    unit: 'kg',
                  ));
                }
                
                if (!mounted) return;
                Navigator.pop(ctx);
                _showSuccess('Growth data logged successfully');
                heightCtrl.dispose();
                weightCtrl.dispose();
                await _loadVitals();
              } catch (e) {
                _showError('Failed to save growth data: $e');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal),
            child: const Text('Log', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.member.profileType;
    
    // Group vitals by type
    final heights = _vitals.where((v) => v.type == 'height').toList();
    final weights = _vitals.where((v) => v.type == 'weight').toList();
    
    // Get latest values
    final latestHeight = heights.isNotEmpty ? heights.last : null;
    final latestWeight = weights.isNotEmpty ? weights.last : null;
    
    return Scaffold(
      backgroundColor: AppColors.grey50,
      appBar: AppBar(title: const Text('Growth Tracking')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(color: t.bgColor, borderRadius: BorderRadius.circular(12)),
                          child: Icon(t.icon, color: t.color, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.member.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.grey900)),
                              Text('${widget.member.age} years old', style: const TextStyle(fontSize: 13, color: AppColors.grey600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: Divider(height: 1)),
                if (latestHeight != null || latestWeight != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Current Measurements', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.grey900)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              if (latestHeight != null)
                                Expanded(
                                  child: Material(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Height', style: TextStyle(fontSize: 12, color: AppColors.grey600, fontWeight: FontWeight.w500)),
                                          const SizedBox(height: 8),
                                          Text('${latestHeight.value} ${latestHeight.unit}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.teal)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              if (latestHeight != null && latestWeight != null) const SizedBox(width: 12),
                              if (latestWeight != null)
                                Expanded(
                                  child: Material(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Weight', style: TextStyle(fontSize: 12, color: AppColors.grey600, fontWeight: FontWeight.w500)),
                                          const SizedBox(height: 8),
                                          Text('${latestWeight.value} ${latestWeight.unit}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.green)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: const Text('Growth History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.grey900)),
                  ),
                ),
                if (_vitals.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.trending_up_outlined, size: 64, color: AppColors.grey200),
                          const SizedBox(height: 16),
                          const Text('No growth measurements yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.grey600)),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList.separated(
                      itemCount: _vitals.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final vital = _vitals[i];
                        final isHeight = vital.type == 'height';
                        return Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: isHeight ? AppColors.teal.withOpacity(0.1) : AppColors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    isHeight ? Icons.straighten : Icons.scale,
                                    color: isHeight ? AppColors.teal : AppColors.green,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(isHeight ? 'Height' : 'Weight', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.grey900)),
                                      Text('${vital.value} ${vital.unit}', style: const TextStyle(fontSize: 13, color: AppColors.grey600, fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                ),
                                Text(vital.recordedAt?.toString().split(' ').first ?? 'N/A', style: const TextStyle(fontSize: 12, color: AppColors.grey500)),
                              ],
                            ),
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
