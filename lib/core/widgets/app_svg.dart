import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AppIcons {
  AppIcons._();

  static const String fishingRod = 'assets/icons/fishing_rod.svg';
  static const String fish = 'assets/icons/fish.svg';
  static const String trophy = 'assets/icons/trophy.svg';
  static const String hook = 'assets/icons/hook.svg';
  static const String wave = 'assets/icons/wave.svg';
  static const String crown = 'assets/icons/crown.svg';
  static const String medalGold = 'assets/icons/medal_gold.svg';
  static const String medalSilver = 'assets/icons/medal_silver.svg';
  static const String medalBronze = 'assets/icons/medal_bronze.svg';
}

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
