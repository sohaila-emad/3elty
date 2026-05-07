import 'package:flutter/material.dart';
import '../main.dart';
import '../data/app_repository.dart';
import '../services/remote_auth_service.dart';

/// Pregnancy module for pregnant women
/// Includes prenatal tests by trimester, daily medications, and food safety guide
class PregnancyModuleScreen extends StatefulWidget {
  final FamilyMember member;

  const PregnancyModuleScreen({super.key, required this.member});

  @override
  State<PregnancyModuleScreen> createState() => _PregnancyModuleScreenState();
}

class _PregnancyModuleScreenState extends State<PregnancyModuleScreen>
    with SingleTickerProviderStateMixin {
  final _repo = AppRepository.instance;
  final _authService = RemoteAuthService.instance;

  late TabController _tabController;
  Map<int, List<Map<String, dynamic>>> _prenatalTestsByTrimester = {};
  bool _loading = true;

  // Daily medications for pregnancy
  final List<String> _prenatalMeds = ['Folic Acid', 'Iron', 'Calcium'];
  final Map<String, bool> _medConfirmed = {
    'Folic Acid': false,
    'Iron': false,
    'Calcium': false,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadPrenatalTests();
  }

  Future<void> _loadPrenatalTests() async {
    if (widget.member.id == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      setState(() => _loading = true);

      final tests = await _repo.getPrenatalTestsForMember(widget.member.id!);

      // Organize by trimester
      final byTrimester = <int, List<Map<String, dynamic>>>{1: [], 2: [], 3: []};
      for (final test in tests) {
        final trimester = test['trimester'] as int;
        byTrimester[trimester]?.add(test);
      }

      if (!mounted) return;
      setState(() {
        _prenatalTestsByTrimester = byTrimester;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('Failed to load prenatal tests: $e');
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
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.grey50,
        appBar: AppBar(
          title: const Text('Pregnancy Care'),
          backgroundColor: AppColors.teal,
          foregroundColor: Colors.white,
          elevation: 0,
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: const [
              Tab(text: '1st Trimester'),
              Tab(text: '2nd Trimester'),
              Tab(text: '3rd Trimester'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildTrimesterView(1),
                  _buildTrimesterView(2),
                  _buildTrimesterView(3),
                ],
              ),
      ),
    );
  }

  Widget _buildTrimesterView(int trimester) {
    final tests = _prenatalTestsByTrimester[trimester] ?? [];

    return SingleChildScrollView(
      child: Column(
        children: [
          // Tests section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Required Tests',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (tests.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.tealLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        'No tests scheduled for this trimester',
                        style: TextStyle(
                          color: AppColors.teal,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  )
                else
                  ...tests.map((test) => _buildTestCard(test)),
              ],
            ),
          ),
          const Divider(),
          // Daily meds section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Prenatal Medications',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ..._prenatalMeds.map((med) => _buildMedicationTile(med)),
              ],
            ),
          ),
          const Divider(),
          // Food safety guide section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Food Safety Guide',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildFoodGuidePreview(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestCard(Map<String, dynamic> test) {
    final isCompleted = test['is_completed'] == 1;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isCompleted ? AppColors.greenLight : AppColors.orangeLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isCompleted ? Icons.check_circle : Icons.pending_actions,
                color: isCompleted ? AppColors.green : AppColors.orange,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    test['test_name'] as String,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isCompleted ? 'Completed ✓' : 'Pending',
                    style: TextStyle(
                      fontSize: 12,
                      color: isCompleted ? AppColors.green : AppColors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (!isCompleted)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () async {
                  try {
                    await _repo.completePrenatalTest(test['id']);
                    _loadPrenatalTests();
                    _showSuccess('Test marked as completed');
                  } catch (e) {
                    _showError('Failed to update test: $e');
                  }
                },
                child: const Text(
                  'Mark Done',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicationTile(String medication) {
    final isConfirmed = _medConfirmed[medication] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isConfirmed ? AppColors.greenLight : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isConfirmed ? AppColors.green : AppColors.grey200,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isConfirmed ? AppColors.green : AppColors.teal,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isConfirmed ? Icons.check_circle : Icons.healing,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          medication,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          isConfirmed ? 'Taken today ✓' : 'Not yet taken',
          style: TextStyle(
            color: isConfirmed ? AppColors.green : AppColors.grey600,
            fontSize: 12,
          ),
        ),
        trailing: Transform.scale(
          scale: 1.3,
          child: Checkbox(
            value: isConfirmed,
            onChanged: (value) {
              setState(() {
                _medConfirmed[medication] = value ?? false;
              });
            },
            activeColor: AppColors.green,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFoodGuidePreview() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.greenLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.thumb_up,
                  color: AppColors.green,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Safe Egyptian Dishes',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['Koshari', 'Fuul', 'Taamia', 'Molokhia']
                .map(
                  (dish) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.greenLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '🟢 $dish',
                      style: TextStyle(
                        color: AppColors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.redLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.thumb_down,
                  color: AppColors.red,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Unsafe Egyptian Dishes',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['Faseekh', 'Raw fish', 'Undercooked meat']
                .map(
                  (dish) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.redLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '🔴 $dish',
                      style: TextStyle(
                        color: AppColors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () {
                // Open full food guide
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Full food guide coming soon!'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: const Text(
                'View Full Food Safety Guide →',
                style: TextStyle(color: AppColors.teal),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
