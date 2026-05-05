import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../extensions/theme_extensions.dart';

class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    super.key,
    required this.title,
    required this.content,
    this.cancelText = '취소',
    required this.confirmText,
    this.confirmColor,
    this.icon,
  });

  final String title;
  final String content;
  final String? cancelText;
  final String confirmText;
  final Color? confirmColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final accent = confirmColor ?? AppColors.error;
    final bg = isDark ? AppColors.darkSurface : Colors.white;
    final sub = isDark ? AppColors.darkTextSub : AppColors.lightTextSub;
    final divider = isDark ? AppColors.darkDivider : AppColors.lightDivider;

    return Dialog(
      backgroundColor: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accent, size: 26),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              content,
              style: TextStyle(fontSize: 14, color: sub, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Divider(color: divider, height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                if (cancelText != null) ...[
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        foregroundColor: sub,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: divider),
                        ),
                      ),
                      child: Text(cancelText!,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: TextButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(confirmText,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
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

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String content,
  String? cancelText = '취소',
  required String confirmText,
  Color? confirmColor,
  IconData? icon,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (_) => ConfirmDialog(
          title: title,
          content: content,
          cancelText: cancelText,
          confirmText: confirmText,
          confirmColor: confirmColor,
          icon: icon,
        ),
      ) ??
      false;
}
