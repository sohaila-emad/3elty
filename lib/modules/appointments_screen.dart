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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    if (widget.member.id == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      setState(() => _loading = true);
      final appts = await _repo.getAppointmentsForMember(widget.member.id!);
      appts.sort((a, b) => _parseScheduledAt(a.scheduledAt).compareTo(_parseScheduledAt(b.scheduledAt)));
      if (!mounted) return;
      setState(() {
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
    return DateTime.tryParse(value) ?? DateTime.tryParse('${value}T00:00:00') ?? DateTime.now();
  }

  String _formatAppointmentDateTime(String value) {
    final date = _parseScheduledAt(value);
    return DateFormat('EEE, MMM d, yyyy • h:mm a').format(date);
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<void> _showAddAppointmentDialog() async {
    final titleCtrl = TextEditingController();
    final doctorCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    DateTime? selectedDate;
    TimeOfDay? selectedTime;
    bool showOnFamilyCalendar = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.grey200, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                const Text('جدولة موعد', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),
                TextField(controller: titleCtrl, decoration: _buildInputDecoration('عنوان الموعد', 'مثال: كشف دوري')),
                const SizedBox(height: 14),
                TextField(controller: doctorCtrl, decoration: _buildInputDecoration('اسم الطبيب', 'اختياري')),
                const SizedBox(height: 14),
                TextField(controller: locationCtrl, decoration: _buildInputDecoration('المكان', 'اختياري')),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _PickerTile(
                        icon: Icons.calendar_today_rounded,
                        label: 'التاريخ',
                        value: selectedDate == null ? 'اختاري التاريخ' : DateFormat('yyyy-MM-dd').format(selectedDate!),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: ctx,
                            initialDate: selectedDate ?? DateTime.now(),
                            firstDate: DateTime.now().subtract(const Duration(days: 1)),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) {
                            setSheetState(() => selectedDate = DateTime(date.year, date.month, date.day));
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PickerTile(
                        icon: Icons.access_time_rounded,
                        label: 'الوقت',
                        value: selectedTime == null ? 'اختاري الوقت' : _formatTimeOfDay(selectedTime!),
                        onTap: () async {
                          final time = await showTimePicker(
                            context: ctx,
                            initialTime: selectedTime ?? TimeOfDay.now(),
                          );
                          if (time != null) {
                            setSheetState(() => selectedTime = time);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  activeColor: widget.member.profileType.color,
                  title: const Text('Show on Family Calendar / إظهار في تقويم العائلة'),
                  subtitle: const Text('This only controls calendar visibility. Notifications stay unchanged.'),
                  value: showOnFamilyCalendar,
                  onChanged: (value) => setSheetState(() => showOnFamilyCalendar = value),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: widget.member.profileType.color, foregroundColor: Colors.white),
                    onPressed: () async {
                      if (titleCtrl.text.trim().isEmpty || selectedDate == null || selectedTime == null || widget.member.id == null) {
                        _showError('يرجى ملء عنوان الموعد واختيار التاريخ والوقت');
                        return;
                      }
                      final scheduledAt = DateTime(
                        selectedDate!.year,
                        selectedDate!.month,
                        selectedDate!.day,
                        selectedTime!.hour,
                        selectedTime!.minute,
                      );
                      final navigator = Navigator.of(ctx);
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        final familyId = await _authService.familyId;
                        if (!mounted) return;
                        if (familyId == null) {
                          _showError('لم يتم العثور على العائلة. يرجى تسجيل الدخول مجدداً.');
                          return;
                        }
                        final hasConflict = _appointments.any((appt) {
                          final existing = _parseScheduledAt(appt.scheduledAt);
                          return existing.year == scheduledAt.year &&
                              existing.month == scheduledAt.month &&
                              existing.day == scheduledAt.day &&
                              existing.hour == scheduledAt.hour &&
                              existing.minute == scheduledAt.minute;
                        });
                        if (hasConflict) {
                          _showError('لديكِ موعد آخر بالفعل في نفس التاريخ والوقت!');
                          return;
                        }
                        await _repo.insertAppointment(AppointmentRecord(
                          familyId: familyId,
                          memberId: widget.member.id!,
                          title: titleCtrl.text.trim(),
                          doctor: doctorCtrl.text.trim().isEmpty ? null : doctorCtrl.text.trim(),
                          location: locationCtrl.text.trim().isEmpty ? null : locationCtrl.text.trim(),
                          scheduledAt: scheduledAt.toIso8601String(),
                          showOnFamilyCalendar: showOnFamilyCalendar,
                        ));
                        if (!mounted) return;
                        navigator.pop();
                        _loadAppointments();
                        messenger.showSnackBar(SnackBar(
                          backgroundColor: AppColors.green,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          content: const Text('تمت جدولة الموعد', style: TextStyle(color: Colors.white)),
                        ));
                      } catch (e) {
                        if (!mounted) return;
                        _showError('فشل: $e');
                      }
                    },
                    child: const Text('جدولة الموعد'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label, String hint) => InputDecoration(
    labelText: label,
    hintText: hint,
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.grey200)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.grey200)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: widget.member.profileType.color, width: 2)),
  );

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: AppColors.red, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), content: Text(msg, style: const TextStyle(color: Colors.white))));

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
                Container(color: Colors.white, padding: const EdgeInsets.all(16), child: Row(children: [
                  Container(width: 48, height: 48, decoration: BoxDecoration(color: t.bgColor, borderRadius: BorderRadius.circular(12)), child: Icon(t.icon, color: t.color, size: 24)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.member.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.grey900)), Text(t.label, style: TextStyle(fontSize: 13, color: t.color, fontWeight: FontWeight.w500))])),
                ])),
                const Divider(height: 1),
                Expanded(
                  child: _appointments.isEmpty
                      ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.calendar_today_rounded, size: 64, color: AppColors.grey200), const SizedBox(height: 16), const Text('لا توجد مواعيد مجدولة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.grey600))]))
                      : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _appointments.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final appt = _appointments[i];
                      return Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border(left: BorderSide(color: t.color, width: 5)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(
                                children: [
                                  Expanded(child: Text(appt.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.grey900))),
                                  if (appt.showOnFamilyCalendar)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: t.bgColor, borderRadius: BorderRadius.circular(99)),
                                      child: Text('Calendar', style: TextStyle(fontSize: 11, color: t.color, fontWeight: FontWeight.w800)),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (appt.doctor != null) Text('الطبيب: ${appt.doctor}', style: const TextStyle(fontSize: 13, color: AppColors.grey600)),
                              if (appt.location != null) Text('المكان: ${appt.location}', style: const TextStyle(fontSize: 13, color: AppColors.grey600)),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.access_time_rounded, size: 16, color: t.color),
                                  const SizedBox(width: 6),
                                  Expanded(child: Text('الموعد: ${_formatAppointmentDateTime(appt.scheduledAt)}', style: TextStyle(fontSize: 13, color: t.color, fontWeight: FontWeight.w600))),
                                ],
                              ),
                            ]),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(onPressed: _showAddAppointmentDialog, backgroundColor: t.color, foregroundColor: Colors.white, icon: const Icon(Icons.add_rounded), label: const Text('جدولة موعد')),
    );
  }
}

class _PickerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _PickerTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
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
              Icon(icon, size: 18, color: AppColors.teal),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 11, color: AppColors.grey600)),
                    const SizedBox(height: 4),
                    Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.grey900)),
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
