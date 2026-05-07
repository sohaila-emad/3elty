import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// ─── نتيجة اختيار الملف ────────────────────────────────────────────────────────
class PickedFileResult {
  /// المسار الدائم داخل مجلد Documents التطبيق (بعد النسخ)
  final String permanentPath;

  /// الاسم الأصلي للملف (للعرض في الـ UI)
  final String displayName;

  /// نوع المحتوى: 'image' أو 'pdf' أو 'file'
  final String contentType;

  const PickedFileResult({
    required this.permanentPath,
    required this.displayName,
    required this.contentType,
  });

  bool get isImage => contentType == 'image';
  bool get isPdf   => contentType == 'pdf';
}

// ─── مساعد رفع الملفات ─────────────────────────────────────────────────────────
//
// يوفّر ثلاث طرق لاختيار الملف:
//   1. pickPdfOrFile()  — PDF أو أي وثيقة من مدير الملفات
//   2. pickImageFile()  — صورة من المعرض
//   3. capturePhoto()   — تصوير مباشر بالكاميرا
//
// في جميع الحالات: يُنسخ الملف المختار إلى مجلد الـ App Documents Directory
// حتى لا يُفقد إذا مسح المستخدم مجلد التحميلات.
// ──────────────────────────────────────────────────────────────────────────────
class DocumentFileHelper {
  DocumentFileHelper._();
  static final DocumentFileHelper instance = DocumentFileHelper._();
  factory DocumentFileHelper() => instance;

  final _imagePicker = ImagePicker();

  // ── 1. اختيار PDF أو وثيقة ────────────────────────────────────────────────
  Future<PickedFileResult?> pickPdfOrFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return null;

      final picked = result.files.single;
      if (picked.path == null) return null;

      final permanent = await _copyToPermanentStorage(
        sourcePath: picked.path!,
        originalName: picked.name,
      );

      return PickedFileResult(
        permanentPath: permanent,
        displayName: picked.name,
        contentType: picked.extension?.toLowerCase() == 'pdf' ? 'pdf' : 'file',
      );
    } catch (e) {
      debugPrint('[DocumentFileHelper] خطأ في اختيار الملف: $e');
      return null;
    }
  }

  // ── 2. اختيار صورة من المعرض ──────────────────────────────────────────────
  Future<PickedFileResult?> pickImageFile() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85, // ضغط خفيف للتوفير في المساحة
      );
      if (picked == null) return null;

      final fileName = p.basename(picked.path);
      final permanent = await _copyToPermanentStorage(
        sourcePath: picked.path,
        originalName: fileName,
      );

      return PickedFileResult(
        permanentPath: permanent,
        displayName: fileName,
        contentType: 'image',
      );
    } catch (e) {
      debugPrint('[DocumentFileHelper] خطأ في اختيار الصورة: $e');
      return null;
    }
  }

  // ── 3. تصوير مباشر بالكاميرا ──────────────────────────────────────────────
  Future<PickedFileResult?> capturePhoto() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (picked == null) return null;

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'photo_$timestamp.jpg';
      final permanent = await _copyToPermanentStorage(
        sourcePath: picked.path,
        originalName: fileName,
      );

      return PickedFileResult(
        permanentPath: permanent,
        displayName: fileName,
        contentType: 'image',
      );
    } catch (e) {
      debugPrint('[DocumentFileHelper] خطأ في التقاط الصورة: $e');
      return null;
    }
  }

  // ── نسخ الملف إلى التخزين الدائم ──────────────────────────────────────────
  //
  // ينسخ الملف إلى:  <App Documents Dir>/medical_docs/<timestamp>_<name>
  // مما يضمن بقاءه حتى بعد مسح مجلد التحميلات.
  Future<String> _copyToPermanentStorage({
    required String sourcePath,
    required String originalName,
  }) async {
    final appDir = await getApplicationDocumentsDirectory();
    final docsDir = Directory(p.join(appDir.path, 'medical_docs'));

    // إنشاء المجلد لو لم يكن موجوداً
    if (!await docsDir.exists()) {
      await docsDir.create(recursive: true);
    }

    // إضافة timestamp للاسم لتجنب التعارض بين الملفات المتشابهة
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeFileName = '${timestamp}_$originalName';
    final destPath = p.join(docsDir.path, safeFileName);

    await File(sourcePath).copy(destPath);

    debugPrint('[DocumentFileHelper] تم النسخ إلى: $destPath');
    return destPath;
  }

  // ── حذف ملف من التخزين الدائم ─────────────────────────────────────────────
  Future<void> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('[DocumentFileHelper] تم حذف: $filePath');
      }
    } catch (e) {
      debugPrint('[DocumentFileHelper] خطأ في حذف الملف: $e');
    }
  }

  // ── التحقق من وجود الملف ──────────────────────────────────────────────────
  Future<bool> fileExists(String filePath) async {
    try {
      return await File(filePath).exists();
    } catch (_) {
      return false;
    }
  }

  // ── تحديد نوع الملف من المسار ─────────────────────────────────────────────
  static String contentTypeFromPath(String path) {
    final ext = p.extension(path).toLowerCase();
    if (['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'].contains(ext)) {
      return 'image';
    }
    if (ext == '.pdf') return 'pdf';
    return 'file';
  }
}