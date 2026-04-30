import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import '../main.dart';
import '../data/app_repository.dart';
import '../services/remote_auth_service.dart';
import '../services/document_file_helper.dart';

class DocumentsScreen extends StatefulWidget {
  final FamilyMember member;
  const DocumentsScreen({super.key, required this.member});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final _repo        = AppRepository.instance;
  final _authService = RemoteAuthService();
  final _fileHelper  = DocumentFileHelper.instance;

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
      setState(() { _documents = docs; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('تعذّر تحميل السجلات: $e');
    }
  }

  // ── فتح الملف عند النقر ────────────────────────────────────────────────────
  Future<void> _openDocument(DocumentRecord doc) async {
    final path = doc.filePath;

    // ملاحظات قديمة أو مسارات غير صالحة
    if (path == 'غير محدد' || path.isEmpty) {
      _showError('لا يوجد ملف مرتبط بهذه الوثيقة');
      return;
    }

    final exists = await _fileHelper.fileExists(path);
    if (!exists) {
      _showError('الملف غير موجود — ربما تم حذفه من الجهاز');
      return;
    }

    final result = await OpenFilex.open(path);
    if (result.type != ResultType.done) {
      if (!mounted) return;
      _showError('لا يوجد تطبيق يدعم فتح هذا النوع من الملفات');
    }
  }

  // ── عرض خيارات رفع الملف (Bottom Sheet) ──────────────────────────────────
  void _showUploadOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.grey200,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('اختر طريقة الرفع',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              _UploadOptionTile(
                icon: Icons.picture_as_pdf_rounded,
                color: const Color(0xFFD32F2F),
                label: 'رفع ملف PDF أو وثيقة',
                subtitle: 'من مدير الملفات',
                onTap: () { Navigator.pop(ctx); _pickAndSave('pdf'); },
              ),
              const SizedBox(height: 10),
              _UploadOptionTile(
                icon: Icons.photo_library_rounded,
                color: const Color(0xFF1565C0),
                label: 'اختيار صورة',
                subtitle: 'من معرض الصور',
                onTap: () { Navigator.pop(ctx); _pickAndSave('gallery'); },
              ),
              const SizedBox(height: 10),
              _UploadOptionTile(
                icon: Icons.camera_alt_rounded,
                color: const Color(0xFF00796B),
                label: 'تصوير التقرير',
                subtitle: 'التقاط صورة بالكاميرا الآن',
                onTap: () { Navigator.pop(ctx); _pickAndSave('camera'); },
              ),
              const SizedBox(height: 10),
              _UploadOptionTile(
                icon: Icons.note_add_rounded,
                color: const Color(0xFF6A1B9A),
                label: 'إضافة ملاحظة فقط',
                subtitle: 'بدون ملف مرفق',
                onTap: () { Navigator.pop(ctx); _showAddDocumentDialog(noFile: true); },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── اختيار الملف وحفظه ────────────────────────────────────────────────────
  Future<void> _pickAndSave(String source) async {
    PickedFileResult? picked;

    // 1. اختر الملف
    switch (source) {
      case 'pdf':
        picked = await _fileHelper.pickPdfOrFile();
        break;
      case 'gallery':
        picked = await _fileHelper.pickImageFile();
        break;
      case 'camera':
        picked = await _fileHelper.capturePhoto();
        break;
    }

    if (picked == null || !mounted) return;

    // 2. اعرض Sheet لإدخال العنوان ونوع الوثيقة
    _showAddDocumentDialog(pickedFile: picked);
  }

  // ── Dialog إضافة وثيقة (مع أو بدون ملف) ─────────────────────────────────
  Future<void> _showAddDocumentDialog({
    PickedFileResult? pickedFile,
    bool noFile = false,
  }) async {
    final titleCtrl = TextEditingController();
    // اقترح عنواناً من اسم الملف
    if (pickedFile != null) {
      final ext = pickedFile.displayName.contains('.')
          ? pickedFile.displayName.split('.').last
          : '';
      titleCtrl.text = ext.isNotEmpty
          ? pickedFile.displayName.replaceAll('.$ext', '')
          : pickedFile.displayName;
    }
    String selectedType = _docTypes[0];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (_, setModal) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.grey200,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('تفاصيل الوثيقة',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),

                // ── معاينة الملف المختار ──────────────────────────────────
                if (pickedFile != null)
                  _FilePreviewTile(file: pickedFile),
                if (pickedFile != null) const SizedBox(height: 14),

                // ── حقل العنوان ───────────────────────────────────────────
                TextField(
                  controller: titleCtrl,
                  decoration: _inputDecoration('عنوان الوثيقة', 'مثال: نتيجة تحليل الدم'),
                ),
                const SizedBox(height: 14),

                // ── نوع الوثيقة ───────────────────────────────────────────
                const Text('نوع الوثيقة',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.grey600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _docTypes.map((type) => FilterChip(
                    label: Text(type),
                    selected: selectedType == type,
                    onSelected: (_) => setModal(() => selectedType = type),
                  )).toList(),
                ),
                const SizedBox(height: 24),

                // ── زر الحفظ ─────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('حفظ الوثيقة'),
                    onPressed: () async {
                      if (titleCtrl.text.trim().isEmpty ||
                          widget.member.id == null) {
                        _showError('يرجى إدخال عنوان الوثيقة');
                        return;
                      }
                      final navigator = Navigator.of(ctx);
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        final familyId = await _authService.familyId;
                        if (!mounted) return;
                        if (familyId == null) {
                          _showError('لم يتم العثور على العائلة');
                          return;
                        }

                        // المسار: الملف الدائم إذا رُفع، وإلا 'غير محدد'
                        final filePath = pickedFile?.permanentPath ?? 'غير محدد';

                        await _repo.insertDocument(DocumentRecord(
                          familyId: familyId,
                          memberId: widget.member.id!,
                          title: titleCtrl.text.trim(),
                          filePath: filePath,
                          docType: selectedType,
                        ));
                        if (!mounted) return;
                        navigator.pop();
                        _loadDocuments();
                        messenger.showSnackBar(SnackBar(
                          backgroundColor: AppColors.green,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          content: const Row(children: [
                            Icon(Icons.check_circle_rounded,
                                color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text('تم حفظ الوثيقة بنجاح ✓',
                                style: TextStyle(color: Colors.white)),
                          ]),
                        ));
                      } catch (e) {
                        _showError('تعذّر الحفظ: $e');
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── حذف الوثيقة مع حذف الملف الفعلي ─────────────────────────────────────
  Future<void> _deleteDocument(DocumentRecord doc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('حذف الوثيقة؟',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        content: Text(
          'هل تريد حذف "${doc.title}" نهائياً؟\nسيتم حذف الملف من الجهاز أيضاً.',
          style: const TextStyle(fontSize: 14, color: AppColors.grey600, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true || doc.id == null) return;

    try {
      // احذف الملف الفعلي أولاً (إن وُجد)
      if (doc.filePath != 'غير محدد') {
        await _fileHelper.deleteFile(doc.filePath);
      }
      await _repo.deleteDocument(doc.id!);
      if (!mounted) return;
      _loadDocuments();
      _showSuccess('تم حذف الوثيقة');
    } catch (e) {
      _showError('تعذّر الحذف: $e');
    }
  }

  // ── الدوال المساعدة ────────────────────────────────────────────────────────
  InputDecoration _inputDecoration(String label, String hint) =>
      InputDecoration(
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

  // ── بناء الـ UI ───────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final t = widget.member.profileType;
    return Scaffold(
      backgroundColor: AppColors.grey50,
      appBar: AppBar(
        title: const Text('السجلات الطبية'),
        actions: [
          // زر رفع مباشر في الـ AppBar
          IconButton(
            icon: const Icon(Icons.upload_file_rounded),
            tooltip: 'رفع وثيقة',
            onPressed: _showUploadOptions,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
          : Column(
              children: [
                // ── Header الفرد ─────────────────────────────────────────
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Container(
                      width: 48, height: 48,
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
                        ],
                      ),
                    ),
                    Text('${_documents.length} وثيقة',
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.grey600)),
                  ]),
                ),
                const Divider(height: 1),

                // ── قائمة الوثائق ─────────────────────────────────────────
                Expanded(
                  child: _documents.isEmpty
                      ? _emptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _documents.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) =>
                              _DocumentCard(
                                doc: _documents[i],
                                profileType: t,
                                onTap: () => _openDocument(_documents[i]),
                                onDelete: () => _deleteDocument(_documents[i]),
                              ),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showUploadOptions,
        backgroundColor: AppColors.teal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.upload_rounded),
        label: const Text('رفع وثيقة'),
      ),
    );
  }

  Widget _emptyState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.tealLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.folder_open_rounded,
                    size: 48, color: AppColors.teal),
              ),
              const SizedBox(height: 20),
              const Text('لا توجد وثائق طبية بعد',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.grey900)),
              const SizedBox(height: 8),
              const Text(
                'ارفع PDF، صورة تقرير، أو وصفة طبية\nللاحتفاظ بها بأمان',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14, color: AppColors.grey600, height: 1.5),
              ),
            ],
          ),
        ),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// Widgets مساعدة
// ══════════════════════════════════════════════════════════════════════════════

// ── بطاقة الوثيقة في القائمة ─────────────────────────────────────────────────
class _DocumentCard extends StatelessWidget {
  final DocumentRecord doc;
  final ProfileType profileType;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _DocumentCard({
    required this.doc,
    required this.profileType,
    required this.onTap,
    required this.onDelete,
  });

  // تحديد نوع المحتوى من المسار المحفوظ
  String get _contentType =>
      DocumentFileHelper.contentTypeFromPath(doc.filePath);
  bool get _hasFile => doc.filePath != 'غير محدد' && doc.filePath.isNotEmpty;
  bool get _isImage => _contentType == 'image';
  bool get _isPdf   => _contentType == 'pdf';

  @override
  Widget build(BuildContext context) {
    final t = profileType;
    return Dismissible(
      key: Key(doc.id ?? doc.title),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(top: 0),
        decoration: BoxDecoration(
          color: AppColors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_rounded, color: Colors.white, size: 24),
            SizedBox(height: 4),
            Text('حذف',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false; // نتحكم بالحذف داخلياً
      },
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: _hasFile ? onTap : null,
          onLongPress: onDelete,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              // ── الـ Thumbnail أو الأيقونة ─────────────────────────────
              _buildThumbnail(t),
              const SizedBox(width: 12),

              // ── معلومات الوثيقة ──────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(doc.title,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.grey900),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: t.bgColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(doc.docType,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: t.color)),
                      ),
                      if (_hasFile) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.tealLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(children: [
                            const Icon(Icons.attach_file_rounded,
                                size: 11, color: AppColors.teal),
                            const SizedBox(width: 3),
                            Text(
                              _isPdf ? 'PDF' : _isImage ? 'صورة' : 'ملف',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.teal,
                                  fontWeight: FontWeight.w500),
                            ),
                          ]),
                        ),
                      ],
                    ]),
                    if (doc.createdAt.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        doc.createdAt.length > 10
                            ? doc.createdAt.substring(0, 10)
                            : doc.createdAt,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.grey500),
                      ),
                    ],
                  ],
                ),
              ),

              // ── أيقونة الفتح أو القفل ─────────────────────────────────
              Icon(
                _hasFile
                    ? Icons.open_in_new_rounded
                    : Icons.lock_outline_rounded,
                color: _hasFile ? t.color : AppColors.grey400,
                size: 18,
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(ProfileType t) {
    // صورة حقيقية للملفات من نوع image
    if (_isImage && _hasFile) {
      final file = File(doc.filePath);
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 52,
          height: 52,
          child: Image.file(
            file,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _iconBox(
              Icons.broken_image_rounded,
              AppColors.grey400,
              AppColors.grey100,
            ),
          ),
        ),
      );
    }

    // أيقونة PDF
    if (_isPdf) {
      return _iconBox(
        Icons.picture_as_pdf_rounded,
        const Color(0xFFD32F2F),
        const Color(0xFFFFEBEE),
      );
    }

    // أيقونة حسب النوع
    return _iconBox(_iconForType(doc.docType), t.color, t.bgColor);
  }

  Widget _iconBox(IconData icon, Color color, Color bg) => Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 24),
      );

  IconData _iconForType(String type) {
    switch (type) {
      case 'وصفة طبية':   return Icons.medication_rounded;
      case 'نتيجة تحليل': return Icons.science_rounded;
      case 'تقرير طبي':   return Icons.description_rounded;
      case 'أشعة':         return Icons.image_rounded;
      default:             return Icons.folder_rounded;
    }
  }
}

// ── معاينة الملف المختار قبل الحفظ ──────────────────────────────────────────
class _FilePreviewTile extends StatelessWidget {
  final PickedFileResult file;
  const _FilePreviewTile({required this.file});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.tealLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        // معاينة مصغرة للصورة أو أيقونة الملف
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 48,
            height: 48,
            child: file.isImage
                ? Image.file(File(file.permanentPath), fit: BoxFit.cover)
                : Container(
                    color: file.isPdf
                        ? const Color(0xFFFFEBEE)
                        : AppColors.grey100,
                    child: Icon(
                      file.isPdf
                          ? Icons.picture_as_pdf_rounded
                          : Icons.insert_drive_file_rounded,
                      color: file.isPdf
                          ? const Color(0xFFD32F2F)
                          : AppColors.grey600,
                      size: 28,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('الملف المختار',
                  style: TextStyle(
                      fontSize: 11,
                      color: AppColors.teal,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                file.displayName,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.grey900),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const Icon(Icons.check_circle_rounded,
            color: AppColors.teal, size: 20),
      ]),
    );
  }
}

// ── خيار رفع (في الـ BottomSheet) ────────────────────────────────────────────
class _UploadOptionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _UploadOptionTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.grey900)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.grey600)),
                ],
              ),
            ),
            Icon(Icons.chevron_left_rounded, color: color, size: 20),
          ]),
        ),
      ),
    );
  }
}