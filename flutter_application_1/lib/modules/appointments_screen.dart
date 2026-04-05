import 'package:flutter/material.dart';
import '../main.dart';
import '../data/app_repository.dart';

class AppointmentsScreen extends StatefulWidget {
  final FamilyMember member;

  const AppointmentsScreen({super.key, required this.member});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  final _repo = AppRepository.instance;
  List<dynamic> _appointments = [];
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
      if (!mounted) return;
      setState(() {
        _appointments = appts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('Failed to load appointments: $e');
    }
  }

  Future<void> _showAddAppointmentDialog() async {
    final titleCtrl = TextEditingController();
    final doctorCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final dateCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.grey200, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            const Text('Schedule appointment', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            TextField(controller: titleCtrl, decoration: _buildInputDecoration('Appointment title', 'e.g. Check-up')),
            const SizedBox(height: 14),
            TextField(controller: doctorCtrl, decoration: _buildInputDecoration('Doctor name', 'Optional')),
            const SizedBox(height: 14),
            TextField(controller: locationCtrl, decoration: _buildInputDecoration('Location', 'Optional')),
            const SizedBox(height: 14),
            TextField(
              controller: dateCtrl,
              readOnly: true,
              onTap: () async {
                final date = await showDatePicker(context: ctx, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                if (date != null) dateCtrl.text = date.toString().split(' ')[0];
              },
              decoration: _buildInputDecoration('Date', 'YYYY-MM-DD'),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (titleCtrl.text.isEmpty || dateCtrl.text.isEmpty || widget.member.id == null) {
                    _showError('Please fill required fields');
                    return;
                  }
                  try {
                    await _repo.insertAppointment(AppointmentRecord(
                      memberId: widget.member.id!,
                      title: titleCtrl.text.trim(),
                      doctor: doctorCtrl.text.isEmpty ? null : doctorCtrl.text.trim(),
                      location: locationCtrl.text.isEmpty ? null : locationCtrl.text.trim(),
                      scheduledAt: dateCtrl.text,
                    ));
                    if (!mounted) return;
                    Navigator.pop(ctx);
                    _loadAppointments();
                    _showSuccess('Appointment scheduled');
                  } catch (e) {
                    _showError('Failed: $e');
                  }
                },
                child: const Text('Schedule appointment'),
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
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.grey200)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.grey200)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.teal, width: 2)),
  );

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: AppColors.red, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), content: Text(msg, style: const TextStyle(color: Colors.white))));

  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: AppColors.green, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), content: Text(msg, style: const TextStyle(color: Colors.white))));

  @override
  Widget build(BuildContext context) {
    final t = widget.member.profileType;
    return Scaffold(
      backgroundColor: AppColors.grey50,
      appBar: AppBar(title: const Text('Appointments')),
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
                      ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.calendar_today_rounded, size: 64, color: AppColors.grey200), const SizedBox(height: 16), const Text('No appointments scheduled', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.grey600))]))
                      : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _appointments.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final appt = _appointments[i];
                      return Material(color: Colors.white, borderRadius: BorderRadius.circular(12), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(appt.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.grey900)),
                        const SizedBox(height: 8),
                        if (appt.doctor != null) Text('Doctor: ${appt.doctor}', style: const TextStyle(fontSize: 13, color: AppColors.grey600)),
                        if (appt.location != null) Text('Location: ${appt.location}', style: const TextStyle(fontSize: 13, color: AppColors.grey600)),
                        const SizedBox(height: 4),
                        Text('Scheduled: ${appt.scheduledAt}', style: const TextStyle(fontSize: 13, color: AppColors.teal, fontWeight: FontWeight.w500)),
                      ])));
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(onPressed: _showAddAppointmentDialog, backgroundColor: AppColors.teal, foregroundColor: Colors.white, icon: const Icon(Icons.add_rounded), label: const Text('Schedule')),
    );
  }
}
