import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../data/app_repository.dart';
import '../services/remote_auth_service.dart';

class AppointmentsScreen extends StatefulWidget {
  final FamilyMember member;

  const AppointmentsScreen({super.key, required this.member});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  final _repo = AppRepository.instance;
  final _authService = RemoteAuthService();

  List<AppointmentRecord> _appointments = [];
  List<MemberRecord> _familyMembers = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    if (widget.member.id == null) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }

    try {
      if (mounted) setState(() => _loading = true);

      final familyId = await _authService.familyId;
      final members = familyId == null
          ? <MemberRecord>[]
          : await _repo.getMembersForFamily(familyId);
      final appts = await _repo.getAppointmentsForMember(widget.member.id!);
      appts.sort((a, b) => _parseScheduledAt(a.scheduledAt)
          .compareTo(_parseScheduledAt(b.scheduledAt)));

      if (!mounted) return;
      setState(() {
        _familyMembers = members;
        _appointments = appts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('تعذّر تحميل المواعيد: $e');
    }
  }

  DateTime _parseScheduledAt(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return DateTime.now();

    return DateTime.tryParse(trimmed) ??
        DateTime.tryParse('${trimmed}T00:00:00') ??
        DateTime.now();
  }

  String _formatAppointmentDateTime(String value) {
    final date = _parseScheduledAt(value);
    return DateFormat('EEE, MMM d, yyyy • h:mm a').format(date);
  }

  ProfileType _profileTypeFromName(String profileType) {
    return ProfileType.values.firstWhere(
      (type) => type.name == profileType,
      orElse: () => ProfileType.adult,
    );
  }

  MemberRecord? _memberRecordById(String memberId) {
    for (final member in _familyMembers) {
      if (member.id == memberId) return member;
    }
    return null;
  }

  String _memberName(String memberId) {
    final member = _memberRecordById(memberId);
    if (member != null) return member.name;
    if (memberId == widget.member.id) return widget.member.name;
    return 'فرد من العائلة';
  }

  Color _memberColor(String memberId) {
    final member = _memberRecordById(memberId);
    if (member != null) return _profileTypeFromName(member.profileType).color;
    if (memberId == widget.member.id) return widget.member.profileType.color;
    return AppColors.teal;
  }

  Color _memberBgColor(String memberId) {
    final member = _memberRecordById(memberId);
    if (member != null) return _profileTypeFromName(member.profileType).bgColor;
    if (memberId == widget.member.id) return widget.member.profileType.bgColor;
    return AppColors.tealLight;
  }

  List<_MemberOption> _memberOptions({String? selectedMemberId}) {
    final options = <_MemberOption>[];
    final seen = <String>{};

    for (final member in _familyMembers) {
      final id = member.id;
      if (id == null || id.isEmpty || seen.contains(id)) continue;
      final type = _profileTypeFromName(member.profileType);
      options.add(_MemberOption(
        id: id,
        name: member.name,
        profileType: type,
      ));
      seen.add(id);
    }

    final currentId = widget.member.id;
    if (currentId != null && currentId.isNotEmpty && !seen.contains(currentId)) {
      options.add(_MemberOption(
        id: currentId,
        name: widget.member.name,
        profileType: widget.member.profileType,
      ));
      seen.add(currentId);
    }

    if (selectedMemberId != null &&
        selectedMemberId.isNotEmpty &&
        !seen.contains(selectedMemberId)) {
      options.add(_MemberOption(
        id: selectedMemberId,
        name: 'فرد من العائلة',
        profileType: ProfileType.adult,
      ));
    }

    return options;
  }

  Future<void> _showAddAppointmentDialog() async {
    await _openAppointmentForm();
  }

  Future<void> _showEditAppointmentDialog(AppointmentRecord appointment) async {
    await _openAppointmentForm(appointment: appointment);
  }

  Future<void> _openAppointmentForm({AppointmentRecord? appointment}) async {
    if (_saving) return;

    final selectedMemberId = appointment?.memberId ?? widget.member.id;
    final options = _memberOptions(selectedMemberId: selectedMemberId);
    if (options.isEmpty) {
      _showError('لم يتم العثور على فرد عائلة صالح لهذا الموعد.');
      return;
    }

    final result = await showModalBottomSheet<_AppointmentFormResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => _AppointmentFormSheet(
        appointment: appointment,
        memberOptions: options,
        fallbackMemberId: widget.member.id,
      ),
    );

    if (!mounted || result == null) return;
    await _saveAppointmentResult(result, existing: appointment);
  }

  Future<void> _saveAppointmentResult(
    _AppointmentFormResult result, {
    AppointmentRecord? existing,
  }) async {
    final isEditing = existing != null;
    if (_saving) return;

    try {
      setState(() => _saving = true);

      final familyId = existing?.familyId ?? await _authService.familyId;
      if (!mounted) return;
      if (familyId == null || familyId.isEmpty) {
        _showError('لم يتم العثور على العائلة. يرجى تسجيل الدخول مجدداً.');
        return;
      }

      final hasConflict = _appointments.any((appt) {
        if (isEditing && appt.id == existing.id) return false;
        if (appt.memberId != result.memberId) return false;
        final existingDateTime = _parseScheduledAt(appt.scheduledAt);
        return existingDateTime.year == result.scheduledAt.year &&
            existingDateTime.month == result.scheduledAt.month &&
            existingDateTime.day == result.scheduledAt.day &&
            existingDateTime.hour == result.scheduledAt.hour &&
            existingDateTime.minute == result.scheduledAt.minute;
      });

      if (hasConflict) {
        _showError('يوجد موعد آخر لنفس فرد العائلة في نفس التاريخ والوقت!');
        return;
      }

      final record = AppointmentRecord(
        id: existing?.id,
        familyId: familyId,
        memberId: result.memberId,
        title: result.title,
        doctor: result.doctor,
        location: result.location,
        scheduledAt: result.scheduledAt.toIso8601String(),
        notes: result.notes,
        showOnFamilyCalendar: result.showOnFamilyCalendar,
        createdAt: existing?.createdAt ?? '',
        updatedAt: existing?.updatedAt ?? '',
      );

      if (isEditing) {
        await _repo.updateAppointmentRecord(record);
      } else {
        await _repo.insertAppointment(record);
      }

      if (!mounted) return;
      await _loadAppointments();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(
          isEditing ? 'تم حفظ تعديلات الموعد' : 'تمت جدولة الموعد',
          style: const TextStyle(color: Colors.white),
        ),
      ));
    } catch (e) {
      if (!mounted) return;
      _showError('فشل حفظ الموعد: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDeleteAppointment(AppointmentRecord appointment) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف الموعد؟'),
        content: Text('سيتم حذف "${appointment.title}" نهائياً. سيختفي أيضاً من تقويم العائلة.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('حذف'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;
    final id = appointment.id;
    if (id == null || id.isEmpty) {
      _showError('لا يمكن حذف هذا الموعد لأن معرفه غير صالح.');
      return;
    }

    try {
      await _repo.deleteAppointment(id);
      if (!mounted) return;
      await _loadAppointments();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: const Text('تم حذف الموعد', style: TextStyle(color: Colors.white)),
      ));
    } catch (e) {
      if (!mounted) return;
      _showError('تعذّر حذف الموعد: $e');
    }
  }

  void _openAction(String action, AppointmentRecord appointment) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (action == 'edit') {
        _showEditAppointmentDialog(appointment);
      } else if (action == 'delete') {
        _confirmDeleteAppointment(appointment);
      }
    });
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.red,
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
      appBar: AppBar(title: const Text('المواعيد')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
          : Column(
              children: [
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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                      if (_saving)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _appointments.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.calendar_today_rounded,
                                  size: 64, color: AppColors.grey200),
                              const SizedBox(height: 16),
                              const Text(
                                'لا توجد مواعيد مجدولة',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.grey600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadAppointments,
                          color: t.color,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _appointments.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              final appt = _appointments[i];
                              final color = _memberColor(appt.memberId);
                              final bgColor = _memberBgColor(appt.memberId);
                              final memberName = _memberName(appt.memberId);

                              return _AppointmentListCard(
                                appointment: appt,
                                color: color,
                                bgColor: bgColor,
                                memberName: memberName,
                                dateTimeText: _formatAppointmentDateTime(appt.scheduledAt),
                                onEdit: () => _showEditAppointmentDialog(appt),
                                onDelete: () => _confirmDeleteAppointment(appt),
                                onMenuSelected: (action) => _openAction(action, appt),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : _showAddAppointmentDialog,
        backgroundColor: t.color,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('جدولة موعد'),
      ),
    );
  }
}

class _AppointmentListCard extends StatelessWidget {
  final AppointmentRecord appointment;
  final Color color;
  final Color bgColor;
  final String memberName;
  final String dateTimeText;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<String> onMenuSelected;

  const _AppointmentListCard({
    required this.appointment,
    required this.color,
    required this.bgColor,
    required this.memberName,
    required this.dateTimeText,
    required this.onEdit,
    required this.onDelete,
    required this.onMenuSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: color, width: 5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appointment.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.grey900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          memberName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    tooltip: 'خيارات الموعد',
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    onSelected: onMenuSelected,
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_rounded, size: 18),
                            SizedBox(width: 8),
                            Text('تعديل الموعد'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded,
                                size: 18, color: AppColors.red),
                            SizedBox(width: 8),
                            Text('حذف الموعد', style: TextStyle(color: AppColors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (appointment.showOnFamilyCalendar)
                    _InfoChip(
                      label: 'Calendar',
                      icon: Icons.event_available_rounded,
                      color: color,
                      bgColor: bgColor,
                    ),
                  _InfoChip(
                    label: dateTimeText,
                    icon: Icons.access_time_rounded,
                    color: color,
                    bgColor: bgColor,
                  ),
                ],
              ),
              if (appointment.doctor != null || appointment.location != null) ...[
                const SizedBox(height: 10),
                if (appointment.doctor != null)
                  Text(
                    'الطبيب: ${appointment.doctor}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: AppColors.grey600),
                  ),
                if (appointment.location != null)
                  Text(
                    'المكان: ${appointment.location}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: AppColors.grey600),
                  ),
              ],
              if (appointment.notes != null && appointment.notes!.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'ملاحظات: ${appointment.notes}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: AppColors.grey600),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: color,
                        side: BorderSide(color: color.withOpacity(0.4)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: const Text('تعديل'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.red,
                        side: BorderSide(color: AppColors.red.withOpacity(0.35)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('حذف'),
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
}

class _AppointmentFormSheet extends StatefulWidget {
  final AppointmentRecord? appointment;
  final List<_MemberOption> memberOptions;
  final String? fallbackMemberId;

  const _AppointmentFormSheet({
    required this.appointment,
    required this.memberOptions,
    required this.fallbackMemberId,
  });

  @override
  State<_AppointmentFormSheet> createState() => _AppointmentFormSheetState();
}

class _AppointmentFormSheetState extends State<_AppointmentFormSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _doctorCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _notesCtrl;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  late String _selectedMemberId;
  late bool _showOnFamilyCalendar;
  bool _submitting = false;

  bool get _isEditing => widget.appointment != null;

  @override
  void initState() {
    super.initState();

    final appointment = widget.appointment;
    final parsedDateTime = _safeParseScheduledAt(appointment?.scheduledAt);

    _titleCtrl = TextEditingController(text: appointment?.title ?? '');
    _doctorCtrl = TextEditingController(text: appointment?.doctor ?? '');
    _locationCtrl = TextEditingController(text: appointment?.location ?? '');
    _notesCtrl = TextEditingController(text: appointment?.notes ?? '');

    if (parsedDateTime != null) {
      _selectedDate = DateTime(
        parsedDateTime.year,
        parsedDateTime.month,
        parsedDateTime.day,
      );
      _selectedTime = TimeOfDay(
        hour: parsedDateTime.hour,
        minute: parsedDateTime.minute,
      );
    }

    final preferredMemberId = appointment?.memberId ?? widget.fallbackMemberId;
    final hasPreferred = preferredMemberId != null &&
        widget.memberOptions.any((option) => option.id == preferredMemberId);
    _selectedMemberId = hasPreferred
        ? preferredMemberId
        : widget.memberOptions.first.id;
    _showOnFamilyCalendar = appointment?.showOnFamilyCalendar ?? false;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _doctorCtrl.dispose();
    _locationCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  DateTime? _safeParseScheduledAt(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw) ?? DateTime.tryParse('${raw}T00:00:00');
  }

  _MemberOption get _selectedMemberOption {
    return widget.memberOptions.firstWhere(
      (option) => option.id == _selectedMemberId,
      orElse: () => widget.memberOptions.first,
    );
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  InputDecoration _buildInputDecoration(String label, String hint, Color focusedColor) {
    return InputDecoration(
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
        borderSide: BorderSide(color: focusedColor, width: 2),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (!mounted || date == null) return;
    setState(() {
      _selectedDate = DateTime(date.year, date.month, date.day);
    });
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (!mounted || time == null) return;
    setState(() => _selectedTime = time);
  }

  void _submit() {
    if (_submitting) return;

    final title = _titleCtrl.text.trim();
    if (title.isEmpty || _selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: const Text(
          'يرجى ملء عنوان الموعد واختيار التاريخ والوقت',
          style: TextStyle(color: Colors.white),
        ),
      ));
      return;
    }

    setState(() => _submitting = true);

    final scheduledAt = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    final result = _AppointmentFormResult(
      title: title,
      doctor: _doctorCtrl.text.trim().isEmpty ? null : _doctorCtrl.text.trim(),
      location: _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      memberId: _selectedMemberId,
      scheduledAt: scheduledAt,
      showOnFamilyCalendar: _showOnFamilyCalendar,
    );

    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final selectedMember = _selectedMemberOption;
    final selectedColor = selectedMember.profileType.color;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: selectedColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _isEditing ? Icons.edit_calendar_rounded : Icons.add_rounded,
                    color: selectedColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _isEditing ? 'تعديل الموعد' : 'جدولة موعد',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.grey900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _titleCtrl,
              textInputAction: TextInputAction.next,
              decoration: _buildInputDecoration(
                'عنوان الموعد',
                'مثال: كشف دوري',
                selectedColor,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _doctorCtrl,
              textInputAction: TextInputAction.next,
              decoration: _buildInputDecoration(
                'اسم الطبيب',
                'اختياري',
                selectedColor,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _locationCtrl,
              textInputAction: TextInputAction.next,
              decoration: _buildInputDecoration(
                'المكان',
                'اختياري',
                selectedColor,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _notesCtrl,
              minLines: 2,
              maxLines: 4,
              textInputAction: TextInputAction.done,
              decoration: _buildInputDecoration(
                'ملاحظات',
                'اختياري',
                selectedColor,
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _selectedMemberId,
              isExpanded: true,
              decoration: _buildInputDecoration(
                'فرد العائلة',
                'اختاري فرد العائلة',
                selectedColor,
              ),
              items: widget.memberOptions.map((member) {
                return DropdownMenuItem<String>(
                  value: member.id,
                  child: Row(
                    children: [
                      Icon(member.profileType.icon, size: 18, color: member.profileType.color),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          member.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: _submitting
                  ? null
                  : (value) {
                      if (value == null || value == _selectedMemberId) return;
                      setState(() => _selectedMemberId = value);
                    },
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 360;
                final dateTile = _PickerTile(
                  icon: Icons.calendar_today_rounded,
                  label: 'التاريخ',
                  value: _selectedDate == null
                      ? 'اختاري التاريخ'
                      : DateFormat('yyyy-MM-dd').format(_selectedDate!),
                  color: selectedColor,
                  onTap: _submitting ? () {} : _pickDate,
                );
                final timeTile = _PickerTile(
                  icon: Icons.access_time_rounded,
                  label: 'الوقت',
                  value: _selectedTime == null
                      ? 'اختاري الوقت'
                      : _formatTimeOfDay(_selectedTime!),
                  color: selectedColor,
                  onTap: _submitting ? () {} : _pickTime,
                );

                if (isNarrow) {
                  return Column(
                    children: [
                      dateTile,
                      const SizedBox(height: 12),
                      timeTile,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: dateTile),
                    const SizedBox(width: 12),
                    Expanded(child: timeTile),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              activeColor: selectedColor,
              title: const Text(
                'Show on Family Calendar / إظهار في تقويم العائلة',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'This only controls calendar visibility. Notifications stay unchanged.',
              ),
              value: _showOnFamilyCalendar,
              onChanged: _submitting
                  ? null
                  : (value) => setState(() => _showOnFamilyCalendar = value),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _submitting ? null : () => Navigator.of(context).pop(),
                    child: const Text('إلغاء'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selectedColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(_isEditing ? Icons.save_rounded : Icons.add_rounded),
                    label: Text(_isEditing ? 'حفظ' : 'إضافة'),
                    onPressed: _submitting ? null : _submit,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AppointmentFormResult {
  final String title;
  final String? doctor;
  final String? location;
  final String? notes;
  final String memberId;
  final DateTime scheduledAt;
  final bool showOnFamilyCalendar;

  const _AppointmentFormResult({
    required this.title,
    required this.doctor,
    required this.location,
    required this.notes,
    required this.memberId,
    required this.scheduledAt,
    required this.showOnFamilyCalendar,
  });
}

class _MemberOption {
  final String id;
  final String name;
  final ProfileType profileType;

  const _MemberOption({
    required this.id,
    required this.name,
    required this.profileType,
  });
}

class _InfoChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color bgColor;

  const _InfoChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final Color color;

  const _PickerTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.grey50,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.grey200),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.grey600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.grey900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
