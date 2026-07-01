import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../extensions/theme_extensions.dart';

/// 버튼 변형(variant).
enum AppButtonVariant {
  /// 메인 액션. 다크: neonGreen / 라이트: navy
  primary,

  /// 보조 액션. 배경 surface + border
  secondary,

  /// 텍스트 전용 (배경 없음). tone으로 색 결정.
  ghost,

  /// 파괴적 액션 (삭제 등). 항상 error 색 채움.
  destructive,

  /// 외곽선 + tone 색 텍스트 (배경 transparent). tone으로 색 결정.
  outline,
}

/// 버튼 사이즈.
enum AppButtonSize { sm, md, lg }

/// `ghost` / `outline` 변형의 색조.
enum AppButtonTone { accent, error, neutral }

/// 디자인 시스템 표준 버튼.
/// `ElevatedButton.styleFrom`을 곳곳에서 직접 호출하지 말고 이걸 사용한다.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.lg,
    this.tone = AppButtonTone.accent,
    this.icon,
    this.loading = false,
    this.fullWidth = true,
    this.disabledColor,
    this.disabledLabelColor,
    this.elevation = 0,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;

  /// `ghost` / `outline` 변형의 색조 (기본 accent).
  final AppButtonTone tone;
  final IconData? icon;
  final bool loading;
  final bool fullWidth;

  /// 비활성(onPressed==null) 시 배경색 커스텀. 없으면 0.45 페이드.
  final Color? disabledColor;

  /// 비활성 시 라벨/아이콘 색 (disabledColor와 함께 사용).
  final Color? disabledLabelColor;

  /// Material 그림자 높이 (기본 0).
  final double elevation;

  @override
  Widget build(BuildContext context) {
    final onAccent = context.isDark ? Colors.black : Colors.white;
    final disabled = onPressed == null || loading;

    final colors = _resolveColors(context.isDark, context.accentColor, onAccent);
    final dims = _resolveDims();

    final useDisabledColor = disabled && !loading && disabledColor != null;
    final bg = useDisabledColor ? disabledColor! : colors.bg;
    final fg = useDisabledColor ? (disabledLabelColor ?? colors.fg) : colors.fg;
    final fade = disabled && !loading && disabledColor == null ? 0.45 : 1.0;

    final child = loading
        ? SizedBox(
            width: dims.iconSize,
            height: dims.iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(fg),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: dims.iconSize, color: fg),
                const SizedBox(width: AppSpacing.md),
              ],
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: dims.fontSize,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          );

    final button = Material(
      color: bg,
      elevation: elevation,
      borderRadius: AppRadius.brMd,
      child: InkWell(
        onTap: disabled ? null : onPressed,
        borderRadius: AppRadius.brMd,
        child: Container(
          height: dims.height,
          padding: EdgeInsets.symmetric(horizontal: dims.padX),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: AppRadius.brMd,
            border: colors.border != null
                ? Border.all(color: colors.border!)
                : null,
          ),
          child: Opacity(
            opacity: fade,
            child: child,
          ),
        ),
      ),
    );

    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }

  Color _toneColor(bool isDark, Color accent) {
    switch (tone) {
      case AppButtonTone.accent:
        return accent;
      case AppButtonTone.error:
        return AppColors.error;
      case AppButtonTone.neutral:
        return isDark ? AppColors.darkTextSub : AppColors.lightTextSub;
    }
  }

  _BtnColors _resolveColors(bool isDark, Color accent, Color onAccent) {
    switch (variant) {
      case AppButtonVariant.primary:
        return _BtnColors(bg: accent, fg: onAccent);
      case AppButtonVariant.secondary:
        return _BtnColors(
          bg: isDark ? AppColors.darkSurface2 : Colors.white,
          fg: isDark ? AppColors.darkText : AppColors.lightText,
          border: isDark ? AppColors.darkDivider : AppColors.lightDivider,
        );
      case AppButtonVariant.ghost:
        return _BtnColors(
            bg: Colors.transparent, fg: _toneColor(isDark, accent));
      case AppButtonVariant.destructive:
        return _BtnColors(bg: AppColors.error, fg: Colors.white);
      case AppButtonVariant.outline:
        final c = _toneColor(isDark, accent);
        return _BtnColors(bg: Colors.transparent, fg: c, border: c);
    }
  }

  _BtnDims _resolveDims() {
    switch (size) {
      case AppButtonSize.sm:
        return const _BtnDims(height: 36, padX: AppSpacing.lg, fontSize: 13, iconSize: 16);
      case AppButtonSize.md:
        return const _BtnDims(height: 44, padX: AppSpacing.xl, fontSize: 14, iconSize: 18);
      case AppButtonSize.lg:
        return const _BtnDims(height: 52, padX: AppSpacing.xl, fontSize: 16, iconSize: 20);
    }
  }
}

class _BtnColors {
  const _BtnColors({required this.bg, required this.fg, this.border});
  final Color bg;
  final Color fg;
  final Color? border;
}

class _BtnDims {
  const _BtnDims({
    required this.height,
    required this.padX,
    required this.fontSize,
    required this.iconSize,
  });
  final double height;
  final double padX;
  final double fontSize;
  final double iconSize;
}
