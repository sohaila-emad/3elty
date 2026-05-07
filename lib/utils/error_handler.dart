import 'package:flutter/material.dart';

/// Error handling and user feedback utilities
class ErrorHandler {
  /// Show error snackbar with red styling
  static void showError(BuildContext context, String message, {Duration duration = const Duration(seconds: 4)}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFD32F2F),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: duration,
      ),
    );
  }

  /// Show success snackbar with green styling
  static void showSuccess(BuildContext context, String message, {Duration duration = const Duration(seconds: 3)}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: duration,
      ),
    );
  }

  /// Show warning snackbar with orange styling
  static void showWarning(BuildContext context, String message, {Duration duration = const Duration(seconds: 3)}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_outlined, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFE65100),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: duration,
      ),
    );
  }

  /// Show info snackbar with teal styling
  static void showInfo(BuildContext context, String message, {Duration duration = const Duration(seconds: 3)}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF00796B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: duration,
      ),
    );
  }

  /// Show error dialog with retry option
  static void showErrorDialog(
    BuildContext context,
    String title,
    String message, {
    VoidCallback? onRetry,
    String retryLabel = 'إعادة المحاولة',
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFD32F2F), size: 24),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 14, color: Color(0xFF757575))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق'),
          ),
          if (onRetry != null)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                onRetry();
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B)),
              child: Text(
                retryLabel,
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  /// User-friendly error message conversion
  static String friendlyMessage(Object error) {
    final msg = error.toString();
    
    if (msg.contains('database')) {
      return 'خطأ في قاعدة البيانات. يرجى المحاولة مجدداً.';
    }
    if (msg.contains('permission')) {
      return 'تم رفض الإذن. يرجى التحقق من صلاحيات التطبيق.';
    }
    if (msg.contains('not found')) {
      return 'العنصر غير موجود. ربما تم حذفه.';
    }
    if (msg.contains('already exists')) {
      return 'العنصر موجود بالفعل.';
    }
    
    // Generic fallback
    return 'حدث خطأ. يرجى المحاولة مجدداً.';
  }
}
