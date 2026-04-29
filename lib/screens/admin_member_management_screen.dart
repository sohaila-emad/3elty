import 'package:flutter/material.dart';
import '../main.dart';
import '../data/app_repository.dart';
import '../services/firestore_service.dart';
import '../services/remote_auth_service.dart';

class AdminMemberManagementScreen extends StatefulWidget {
  const AdminMemberManagementScreen({super.key});

  @override
  State<AdminMemberManagementScreen> createState() =>
      _AdminMemberManagementScreenState();
}

class _AdminMemberManagementScreenState
    extends State<AdminMemberManagementScreen> {
  final _repo = AppRepository.instance;
  final _firestoreService = FirestoreService();
  final _authService = RemoteAuthService();

  List<FamilyMember> _members = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() => _loading = true);
    try {
      final familyId = await _authService.familyId;
      if (familyId == null) {
        _showError('Family not found');
        return;
      }

      final records = await _repo.getMembersForFamily(familyId);
      if (!mounted) return;
      setState(() {
        _members = records.map(FamilyMember.fromRecord).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('Failed to load members: $e');
    }
  }

  void _showAddMemberDialog() {
    final nameCtrl = TextEditingController();
    final ageCtrl = TextEditingController();
    ProfileType selectedType = ProfileType.adult;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Add Family Member',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Ahmed',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: ageCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Age',
                hintText: 'e.g. 25',
                prefixIcon: Icon(Icons.cake_outlined),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Profile Type',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: ProfileType.values.map((type) {
                final sel = selectedType == type;
                return FilterChip(
                  selected: sel,
                  onSelected: (_) => setState(() => selectedType = type),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(type.icon, size: 18),
                      const SizedBox(width: 5),
                      Text(type.label, style: TextStyle(
                        fontSize: 13,
                        fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                        color: sel ? type.color : AppColors.grey600,
                      )),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _addMember(
                sheetCtx,
                nameCtrl.text.trim(),
                ageCtrl.text.trim(),
                selectedType,
              ),
              child: const Text('Add Member'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addMember(
    BuildContext sheetCtx,
    String name,
    String ageText,
    ProfileType type,
  ) async {
    if (name.isEmpty) {
      _showError('Please enter member name');
      return;
    }
    if (ageText.isEmpty) {
      _showError('Please enter age');
      return;
    }

    final age = int.tryParse(ageText);
    if (age == null || age < 0 || age > 150) {
      _showError('Please enter a valid age');
      return;
    }

    try {
      await _firestoreService.addFamilyMember(
        name: name,
        age: age,
        profileType: type.name,
      );

      if (!mounted) return;
      Navigator.pop(sheetCtx);
      await _loadMembers();
      _showSuccess('$name added to family');
    } catch (e) {
      _showError('Failed to add member: $e');
    }
  }

  Future<void> _showEditMemberDialog(FamilyMember member) async {
    final nameCtrl = TextEditingController(text: member.name);
    final ageCtrl = TextEditingController(text: member.age.toString());
    ProfileType selectedType = member.profileType;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Edit Member',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: ageCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Age',
                prefixIcon: Icon(Icons.cake_outlined),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Profile Type',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: ProfileType.values.map((type) {
                final sel = selectedType == type;
                return FilterChip(
                  selected: sel,
                  onSelected: (_) => setState(() => selectedType = type),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(type.icon, size: 18),
                      const SizedBox(width: 5),
                      Text(type.label, style: TextStyle(
                        fontSize: 13,
                        fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                        color: sel ? type.color : AppColors.grey600,
                      )),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _updateMember(
                sheetCtx,
                member.id!,
                nameCtrl.text.trim(),
                ageCtrl.text.trim(),
                selectedType,
              ),
              child: const Text('Update Member'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateMember(
    BuildContext sheetCtx,
    String memberId,
    String name,
    String ageText,
    ProfileType type,
  ) async {
    if (name.isEmpty || ageText.isEmpty) {
      _showError('Please fill all fields');
      return;
    }

    final age = int.tryParse(ageText);
    if (age == null || age < 0 || age > 150) {
      _showError('Please enter a valid age');
      return;
    }

    try {
      await _firestoreService.updateFamilyMember(
        memberId: memberId,
        name: name,
        age: age,
        profileType: type.name,
      );

      if (!mounted) return;
      Navigator.pop(sheetCtx);
      await _loadMembers();
      _showSuccess('$name updated');
    } catch (e) {
      _showError('Failed to update member: $e');
    }
  }

  Future<void> _confirmDeleteMember(FamilyMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Remove ${member.name}?',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        content: const Text(
          'This will permanently delete all their health data — medications, vitals, appointments and documents.',
          style: TextStyle(fontSize: 14, color: AppColors.grey600, height: 1.5),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firestoreService.deleteFamilyMember(member.id!);
        await _loadMembers();
        _showSuccess('${member.name} removed from family');
      } catch (e) {
        _showError('Failed to delete member: $e');
      }
    }
  }

  void _showError(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text(msg, style: const TextStyle(color: Colors.white)),
        ),
      );

  void _showSuccess(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text(msg, style: const TextStyle(color: Colors.white)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey50,
      appBar: AppBar(
        title: const Text('Manage Family Members'),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.teal),
            )
          : _members.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.tealLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.people_outline_rounded,
                          size: 40,
                          color: AppColors.teal,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No family members yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.grey900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Click + to add your first member',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.grey600,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _members.length,
                  itemBuilder: (ctx, i) {
                    final member = _members[i];
                    final t = member.profileType;
                    return GestureDetector(
                      onLongPress: () => _confirmDeleteMember(member),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.grey200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: t.bgColor,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(t.icon, color: t.color, size: 28),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      member.name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.grey900,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${member.age} years • ${t.label}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.grey600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  color: AppColors.teal,
                                ),
                                onPressed: () =>
                                    _showEditMemberDialog(member),
                              ),
                              Text(
                                'Long press to delete',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.grey500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddMemberDialog,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add Member'),
      ),
    );
  }
}
