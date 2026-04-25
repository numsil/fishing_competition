import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    super.key,
    required this.title,
    required this.content,
    this.cancelText = '취소',
    required this.confirmText,
    this.confirmColor,
  });

  final String title;
  final String content;
  final String? cancelText;
  final String confirmText;
  final Color? confirmColor;

  @override
  Widget build(BuildContext context) {
    final color = confirmColor ?? AppColors.error;
    return AlertDialog(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      content: Text(content),
      actions: [
        if (cancelText != null)
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelText!),
          ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmText),
        ),
      ],
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
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (_) => ConfirmDialog(
          title: title,
          content: content,
          cancelText: cancelText,
          confirmText: confirmText,
          confirmColor: confirmColor,
        ),
      ) ??
      false;
}
