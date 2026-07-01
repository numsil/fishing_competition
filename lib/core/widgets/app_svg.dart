import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AppSvg extends StatelessWidget {
  const AppSvg(
    this.asset, {
    super.key,
    this.size,
    this.width,
    this.height,
    this.color,
    this.fit = BoxFit.contain,
  });

  final String asset;
  final double? size;
  final double? width;
  final double? height;
  final Color? color;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      asset,
      width: size ?? width,
      height: size ?? height,
      fit: fit,
      colorFilter: color != null
          ? ColorFilter.mode(color!, BlendMode.srcIn)
          : null,
    );
  }
}
