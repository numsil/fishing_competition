import 'package:flutter/material.dart';

/// 빈 목록/화면 공통 위젯
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.subMessage,
    required this.subColor,
  });

  final IconData icon;
  final String message;
  final String? subMessage;
  final Color subColor;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: subColor.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: subColor),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600, color: subColor),
          ),
          if (subMessage != null) ...[
            const SizedBox(height: 6),
            Text(
              subMessage!,
              style: TextStyle(fontSize: 13, color: subColor),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
