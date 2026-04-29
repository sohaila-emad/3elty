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

  // ── Input decoration ────────────────────────────────────────────────────────
  InputDecoration _inputDecor(String label, String? hint, IconData icon) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: AppColors.grey600, fontSize: 14),
        prefixIcon: Icon(icon, color: AppColors.grey500, size: 20),
        filled: true,
        fillColor: AppColors.grey50,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.grey200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.grey200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.teal, width: 2),
        ),
      );

  // ── Add member bottom sheet ─────────────────────────────────────────────────
  void _showAddMemberDialog() {
    final nameCtrl = TextEditingController();
    final ageCtrl = TextEditingController();
    ProfileType selectedType = ProfileType.adult;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            left: 24,
            right: 24,
            top: 8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.grey200,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Add Family Member',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700,
                    color: AppColors.grey900),
              ),
              const SizedBox(height: 6),
              const Text(
                'Enter member details to personalize their health experience',
                style: TextStyle(fontSize: 13, color: AppColors.grey600),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(fontSize: 15),
                decoration: _inputDecor('Name', 'e.g. Ahmed', Icons.person_outline_rounded),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: ageCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 15),
                decoration: _inputDecor('Age', 'e.g. 25', Icons.cake_outlined),
              ),
              const SizedBox(height: 20),
              const Text(
                'Profile Type',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                    color: AppColors.grey900),
              ),
              const SizedBox(height: 12),
              // Profile type grid
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 2,
                children: ProfileType.values.map((type) {
                  final selected = selectedType == type;
                  return GestureDetector(
                    onTap: () => setSheetState(() => selectedType = type),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: selected ? type.bgColor : AppColors.grey50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? type.color : AppColors.grey200,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(type.icon,
                              size: 16,
                              color: selected ? type.color : AppColors.grey500),
                          const SizedBox(width: 4),
                          Text(
                            type.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                              color: selected ? type.color : AppColors.grey600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => _addMember(
                    sheetCtx,
                    nameCtrl.text.trim(),
                    ageCtrl.text.trim(),
                    selectedType,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.person_add_rounded,
                      color: Colors.white, size: 20),
                  label: const Text(
                    'Add Member',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
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

  // ── Edit member bottom sheet ────────────────────────────────────────────────
  Future<void> _showEditMemberDialog(FamilyMember member) async {
    final nameCtrl = TextEditingController(text: member.name);
    final ageCtrl = TextEditingController(text: member.age.toString());
    ProfileType selectedType = member.profileType;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            left: 24,
            right: 24,
            top: 8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.grey200,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Edit Member',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700,
                    color: AppColors.grey900),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(fontSize: 15),
                decoration: _inputDecor('Name', null, Icons.person_outline_rounded),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: ageCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 15),
                decoration: _inputDecor('Age', null, Icons.cake_outlined),
              ),
              const SizedBox(height: 20),
              const Text(
                'Profile Type',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                    color: AppColors.grey900),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 2,
                children: ProfileType.values.map((type) {
                  final selected = selectedType == type;
                  return GestureDetector(
                    onTap: () => setSheetState(() => selectedType = type),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: selected ? type.bgColor : AppColors.grey50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? type.color : AppColors.grey200,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(type.icon,
                              size: 16,
                              color: selected ? type.color : AppColors.grey500),
                          const SizedBox(width: 4),
                          Text(
                            type.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                              color: selected ? type.color : AppColors.grey600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => _updateMember(
                    sheetCtx,
                    member.id!,
                    nameCtrl.text.trim(),
                    ageCtrl.text.trim(),
                    selectedType,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.check_rounded,
                      color: Colors.white, size: 20),
                  label: const Text(
                    'Save Changes',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
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

  // ── Delete confirmation ─────────────────────────────────────────────────────
  Future<void> _confirmDeleteMember(FamilyMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
              color: AppColors.redLight, shape: BoxShape.circle),
          child: const Icon(Icons.delete_rounded, color: AppColors.red, size: 28),
        ),
        title: Text('Remove ${member.name}?',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        content: const Text(
          'This will permanently delete all their health data — medications, vitals, appointments and documents.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: AppColors.grey600, height: 1.5),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          Column(children: [
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, kMinTouch),
                  side: const BorderSide(color: AppColors.grey200),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel',
                    style: TextStyle(color: AppColors.grey900)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.red,
                  minimumSize: const Size(double.infinity, kMinTouch),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete',
                    style: TextStyle(color: Colors.white,
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
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

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(children: [
            const Icon(Icons.error_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
                child: Text(msg, style: const TextStyle(color: Colors.white))),
          ]),
        ),
      );

  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.green,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
                child: Text(msg, style: const TextStyle(color: Colors.white))),
          ]),
        ),
      );

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey50,
      appBar: AppBar(
        title: const Text('Manage Family Members',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        centerTitle: false,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.grey900,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.grey200),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.teal))
          : _members.isEmpty
              ? _emptyState()
              : _memberList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddMemberDialog,
        backgroundColor: AppColors.tealLight,
        foregroundColor: AppColors.teal,
        elevation: 0,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add Member',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _emptyState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.tealLight,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.people_outline_rounded,
                    size: 44, color: AppColors.teal),
              ),
              const SizedBox(height: 20),
              const Text('No family members yet',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.grey900)),
              const SizedBox(height: 8),
              const Text('Click + to add your first member',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14,
                      color: AppColors.grey600,
                      height: 1.5)),
            ],
          ),
        ),
      );

  Widget _memberList() => ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _members.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (ctx, i) {
          final member = _members[i];
          final t = member.profileType;
          return GestureDetector(
            onLongPress: () => _confirmDeleteMember(member),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.grey200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: t.bgColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(t.icon, color: t.color, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(member.name,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.grey900)),
                        const SizedBox(height: 4),
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: t.bgColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(t.label,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: t.color)),
                          ),
                          const SizedBox(width: 6),
                          Text('${member.age} years',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.grey500)),
                        ]),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined,
                        color: AppColors.teal, size: 20),
                    onPressed: () => _showEditMemberDialog(member),
                  ),
                  const Text('Long press\nto delete',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 10, color: AppColors.grey400, height: 1.3)),
                ]),
              ),
            ),
          );
        },
      );
}