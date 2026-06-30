import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../extensions/theme_extensions.dart';

/// 카드 변형.
enum AppCardVariant {
  /// 기본 카드 (surface + 옵션 border)
  surface,

  /// 강조 카드 (accent 색상 4~10% 틴트 배경)
  tinted,

  /// 외곽선만 (배경 transparent)
  outlined,
}

/// 디자인 시스템 표준 카드 컨테이너.
/// `Container + BoxDecoration` 반복을 대체한다.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.variant = AppCardVariant.surface,
    this.padding = AppSpacing.card,
    this.margin,
    this.radius,
    this.borderColor,
    this.borderWidth = 1.0,
    this.tintColor,
    this.tintAlpha,
    this.boxShadow,
    this.onTap,
  });

  final Widget child;
  final AppCardVariant variant;
  final EdgeInsetsGeometry padding;

  /// 카드 바깥 여백. AppCard는 탭 영역 밖에 margin을 적용한다.
  final EdgeInsetsGeometry? margin;
  final double? radius;
  final Color? borderColor;

  /// 테두리 두께 (기본 1.0). `tinted`에서도 borderColor가 있으면 적용된다.
  final double borderWidth;

  /// `tinted` 변형에서만 의미. accent 색.
  final Color? tintColor;

  /// `tinted` 배경 틴트 투명도 오버라이드 (기본 dark 0.10 / light 0.06).
  final double? tintAlpha;

  /// 카드 그림자 (옵션).
  final List<BoxShadow>? boxShadow;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius ?? AppRadius.lg);

    final bg = switch (variant) {
      AppCardVariant.surface =>
        context.isDark ? AppColors.darkSurface : AppColors.lightSurface,
      AppCardVariant.tinted => (tintColor ??
              (context.isDark ? AppColors.neonGreen : AppColors.navy))
          .withValues(alpha: tintAlpha ?? (context.isDark ? 0.10 : 0.06)),
      AppCardVariant.outlined => Colors.transparent,
    };

    final border = switch (variant) {
      AppCardVariant.surface => borderColor != null
          ? Border.all(color: borderColor!, width: borderWidth)
          : (context.isDark
              ? null
              : Border.all(color: AppColors.lightDivider, width: borderWidth)),
      AppCardVariant.outlined => Border.all(
          color: borderColor ??
              (context.isDark ? AppColors.darkDivider : AppColors.lightDivider),
          width: borderWidth,
        ),
      AppCardVariant.tinted => borderColor != null
          ? Border.all(color: borderColor!, width: borderWidth)
          : null,
    };

    Widget result = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: br,
        border: border,
        boxShadow: boxShadow,
      ),
      child: child,
    );

    if (onTap != null) {
      result = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: br,
          child: result,
        ),
      );
    }

    if (margin != null) {
      result = Padding(padding: margin!, child: result);
    }

    return result;
  }
}
