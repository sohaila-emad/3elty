import 'package:flutter/material.dart';
import '../main.dart';
import '../data/app_repository.dart';
import '../services/remote_auth_service.dart';

class DocumentsScreen extends StatefulWidget {
  final FamilyMember member;
  const DocumentsScreen({super.key, required this.member});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final _repo = AppRepository.instance;
  final _authService = RemoteAuthService();
  List<DocumentRecord> _documents = [];
  bool _loading = true;

  static const List<String> _docTypes = [
    'وصفة طبية',
    'نتيجة تحليل',
    'تقرير طبي',
    'أشعة',
    'وثيقة أخرى',
  ];

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
      _showError('تعذّر تحميل السجلات: $e');
    }
  }

  Future<void> _showAddDocumentDialog() async {
    final titleCtrl = TextEditingController();
    final pathCtrl = TextEditingController();
    String selectedType = _docTypes[0];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
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
              const Text('إضافة وثيقة طبية',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              TextField(
                controller: titleCtrl,
                decoration: _inputDecoration('عنوان الوثيقة', 'مثال: نتيجة تحليل الدم'),
              ),
              const SizedBox(height: 14),
              const Text('نوع الوثيقة',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.grey600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _docTypes.map((type) {
                  return FilterChip(
                    label: Text(type),
                    selected: selectedType == type,
                    onSelected: (_) =>
                        setModalState(() => selectedType = type),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: pathCtrl,
                decoration: _inputDecoration('ملاحظات / مسار الملف', 'اختياري'),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (titleCtrl.text.isEmpty || widget.member.id == null) {
                      _showError('يرجى إدخال عنوان الوثيقة');
                      return;
                    }
                    final navigator = Navigator.of(ctx);
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      final familyId = await _authService.familyId;
                      if (!mounted) return;
                      if (familyId == null) {
                        _showError(
                            'لم يتم العثور على العائلة. يرجى تسجيل الدخول مجدداً.');
                        return;
                      }
                      await _repo.insertDocument(DocumentRecord(
                        familyId: familyId,
                        memberId: widget.member.id!,
                        title: titleCtrl.text.trim(),
                        filePath: pathCtrl.text.trim().isEmpty
                            ? 'غير محدد'
                            : pathCtrl.text.trim(),
                        docType: selectedType,
                      ));
                      if (!mounted) return;
                      navigator.pop();
                      _loadDocuments();
                      messenger.showSnackBar(SnackBar(
                        backgroundColor: AppColors.green,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        content: const Text('تمت إضافة الوثيقة', style: TextStyle(color: Colors.white)),
                      ));
                    } catch (e) {
                      _showError('تعذّر إضافة الوثيقة: $e');
                    }
                  },
                  child: const Text('إضافة الوثيقة'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, String hint) => InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.grey200)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.grey200)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.teal, width: 2)),
      );

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text(msg, style: const TextStyle(color: Colors.white)),
        ),
      );

  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.green,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text(msg, style: const TextStyle(color: Colors.white)),
        ),
      );

  IconData _iconForType(String type) {
    switch (type) {
      case 'وصفة طبية':
        return Icons.medication_rounded;
      case 'نتيجة تحليل':
        return Icons.science_rounded;
      case 'تقرير طبي':
        return Icons.description_rounded;
      case 'أشعة':
        return Icons.image_rounded;
      default:
        return Icons.folder_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.member.profileType;
    return Scaffold(
      backgroundColor: AppColors.grey50,
      appBar: AppBar(title: const Text('السجلات الطبية')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
          : Column(
              children: [
                // Member header
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
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
                            Text(widget.member.name,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.grey900)),
                            Text(t.label,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: t.color,
                                    fontWeight: FontWeight.w500)),
                          ]),
                    ),
                    Text('${_documents.length} وثائق',
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.grey600)),
                  ]),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _documents.isEmpty
                      ? Center(
                          child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.folder_open_rounded,
                                size: 64, color: AppColors.grey200),
                            const SizedBox(height: 16),
                            const Text('لا توجد وثائق طبية بعد',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.grey600)),
                            const SizedBox(height: 8),
                            const Text('أضف وثيقة للبدء',
                                style: TextStyle(
                                    fontSize: 14, color: AppColors.grey600)),
                          ],
                        ))
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _documents.length,
                          separatorBuilder: (_, x) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final doc = _documents[i];
                            return Material(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onLongPress: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('حذف الوثيقة؟'),
                                      content:
                                          Text('هل تريد حذف "${doc.title}"؟'),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text('إلغاء'),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.red),
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: const Text('حذف',
                                              style: TextStyle(
                                                  color: Colors.white)),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true && doc.id != null) {
                                    try {
                                      await _repo.deleteDocument(doc.id!);
                                      if (!mounted) return;
                                      _loadDocuments();
                                      _showSuccess('تم حذف الوثيقة');
                                    } catch (e) {
                                      _showError('تعذّر الحذف: $e');
                                    }
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: t.bgColor,
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      child: Icon(_iconForType(doc.docType),
                                          color: t.color, size: 22),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(doc.title,
                                              style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.grey900)),
                                          const SizedBox(height: 4),
                                          Row(children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: t.bgColor,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(doc.docType,
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: t.color)),
                                            ),
                                          ]),
                                          if (doc.createdAt.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(doc.createdAt,
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    color: AppColors.grey500)),
                                          ]
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.chevron_left_rounded,
                                        color: AppColors.grey400),
                                  ]),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDocumentDialog,
        backgroundColor: AppColors.teal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('إضافة وثيقة'),
      ),
    );
  }
}
