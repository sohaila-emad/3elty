import 'package:flutter/material.dart';
import '../main.dart';
import '../data/app_repository.dart';

class DocumentsScreen extends StatefulWidget {
  final FamilyMember member;
  const DocumentsScreen({super.key, required this.member});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final _repo = AppRepository.instance;
  List<dynamic> _documents = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    if (widget.member.id == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      setState(() => _loading = true);
      final docs = await _repo.getDocumentsForMember(widget.member.id!);
      if (!mounted) return;
      setState(() {
        _documents = docs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('Failed to load documents: $e');
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: AppColors.red, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), content: Text(msg, style: const TextStyle(color: Colors.white))));

  @override
  Widget build(BuildContext context) {
    final t = widget.member.profileType;
    return Scaffold(
      backgroundColor: AppColors.grey50,
      appBar: AppBar(title: const Text('Medical Documents')),
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
                  child: _documents.isEmpty
                      ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.folder_outlined, size: 64, color: AppColors.grey200), const SizedBox(height: 16), const Text('No documents yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.grey600))]))
                      : ListView.separated(padding: const EdgeInsets.all(16), itemCount: _documents.length, separatorBuilder: (_, _) => const SizedBox(height: 10), itemBuilder: (_, i) {
                    final doc = _documents[i];
                    return Material(color: Colors.white, borderRadius: BorderRadius.circular(12), child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
                      Icon(Icons.description_rounded, size: 32, color: AppColors.teal),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(doc.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.grey900)), Text(doc.docType ?? 'Document', style: const TextStyle(fontSize: 12, color: AppColors.grey600))])),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.grey600),
                    ])));
                  }),
                ),
              ],
            ),
    );
  }
}
