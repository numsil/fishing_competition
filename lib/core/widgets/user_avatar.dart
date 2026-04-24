import 'package:flutter/material.dart';

/// 어디서든 재사용 가능한 유저 아바타 위젯.
/// avatarUrl 이 있으면 네트워크 이미지, 없으면 이니셜 텍스트를 표시합니다.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.username,
    this.avatarUrl,
    required this.radius,
    this.isDark = true,
  });

  final String username;
  final String? avatarUrl;
  final double radius;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final url = (avatarUrl?.isNotEmpty == true) ? avatarUrl! : null;
    final bg = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0);
    final size = radius * 2;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius * 0.32),
      child: Container(
        width: size,
        height: size,
        color: bg,
        child: url != null
            ? Image.network(url, fit: BoxFit.cover, width: size, height: size)
            : Center(
                child: Text(
                  username.isNotEmpty ? username[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: radius * 0.72,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ),
      ),
    );
  }
}
