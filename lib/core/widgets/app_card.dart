import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

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
    this.radius,
    this.borderColor,
    this.tintColor,
    this.onTap,
  });

  final Widget child;
  final AppCardVariant variant;
  final EdgeInsetsGeometry padding;
  final double? radius;
  final Color? borderColor;

  /// `tinted` 변형에서만 의미. accent 색.
  final Color? tintColor;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final br = BorderRadius.circular(radius ?? AppRadius.lg);

    final bg = switch (variant) {
      AppCardVariant.surface =>
        isDark ? AppColors.darkSurface : AppColors.lightSurface,
      AppCardVariant.tinted => (tintColor ??
              (isDark ? AppColors.neonGreen : AppColors.navy))
          .withValues(alpha: isDark ? 0.10 : 0.06),
      AppCardVariant.outlined => Colors.transparent,
    };

    final border = switch (variant) {
      AppCardVariant.surface => borderColor != null
          ? Border.all(color: borderColor!)
          : (isDark
              ? null
              : Border.all(color: AppColors.lightDivider)),
      AppCardVariant.outlined => Border.all(
          color: borderColor ??
              (isDark ? AppColors.darkDivider : AppColors.lightDivider),
        ),
      AppCardVariant.tinted => null,
    };

    final container = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: br,
        border: border,
      ),
      child: child,
    );

    if (onTap == null) return container;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: br,
        child: container,
      ),
    );
  }
}
