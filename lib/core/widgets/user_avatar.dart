import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.username,
    this.avatarUrl,
    required this.radius,
    this.isDark = true,
    this.borderColor,
    this.borderWidth = 2.5,
  });

  final String username;
  final String? avatarUrl;
  final double radius;
  final bool isDark;
  final Color? borderColor;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final url = (avatarUrl?.isNotEmpty == true) ? avatarUrl! : null;
    final bg = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0);
    final size = radius * 2;
    final borderRadius = BorderRadius.circular(radius * 0.32);

    Widget avatar = ClipRRect(
      borderRadius: borderRadius,
      child: Container(
        width: size,
        height: size,
        color: bg,
        child: url != null
            ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, width: size, height: size)
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

    if (borderColor != null) {
      avatar = Container(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          border: Border.all(color: borderColor!, width: borderWidth),
        ),
        child: avatar,
      );
    }

    return avatar;
  }
}
