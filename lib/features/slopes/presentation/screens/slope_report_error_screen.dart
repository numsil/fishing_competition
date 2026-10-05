import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/extensions/theme_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../data/slope_model.dart';
import '../../data/slope_report_repository.dart';
import '../widgets/slope_picker_sheet.dart';

/// 오류 신고 — 기존 슬로프의 잘못된 정보를 신고하는 폼.
/// [initialSlope]가 주어지면 대상 슬로프가 미리 선택된 상태로 시작.
class SlopeReportErrorScreen extends ConsumerStatefulWidget {
  const SlopeReportErrorScreen({super.key, this.initialSlope});

  final Slope? initialSlope;

  @override
  ConsumerState<SlopeReportErrorScreen> createState() =>
      _SlopeReportErrorScreenState();
}

class _SlopeReportErrorScreenState
    extends ConsumerState<SlopeReportErrorScreen> {
  final _contentController = TextEditingController();
  Slope? _selected;
  bool _submitting = false;
  bool _showSlopeError = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSlope;
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickSlope() async {
    final picked = await showSlopePickerSheet(context);
    if (picked != null) {
      setState(() {
        _selected = picked;
        _showSlopeError = false;
      });
    }
  }

  Future<void> _submit() async {
    final slope = _selected;
    final content = _contentController.text.trim();
    if (slope == null) {
      setState(() => _showSlopeError = true);
      return;
    }
    if (content.isEmpty) return;

    setState(() => _submitting = true);
    try {
      await ref.read(slopeReportRepositoryProvider).submitError(
            slopeId: slope.id,
            content: content,
          );
      if (!mounted) return;
      Navigator.pop(context);
      AppSnackBar.success(context, '신고가 접수되었습니다. 감사합니다!');
    } on NotAuthenticatedException {
      if (!mounted) return;
      AppSnackBar.error(context, '로그인이 필요합니다');
      setState(() => _submitting = false);
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, '신고 접수 실패: $e');
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subColor = isDark ? AppColors.darkTextSub : AppColors.lightTextSub;
    final selected = _selected;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Text('오류 신고',
            style: AppTextStyles.heading3.copyWith(color: textColor)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            Text(
              '잘못된 정보를 알려주세요. 예: 폐쇄됨, 위치 오류, 유료로 바뀜 등',
              style: AppTextStyles.caption.copyWith(color: subColor),
            ),
            const SizedBox(height: AppSpacing.xl),
            // ── 대상 슬로프 선택 ──
            Text('대상 슬로프',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textColor)),
            const SizedBox(height: AppSpacing.md),
            InkWell(
              onTap: _pickSlope,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _showSlopeError
                        ? AppColors.error
                        : (isDark
                            ? AppColors.darkDivider
                            : AppColors.lightDivider),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: selected == null
                          ? Text('슬로프를 선택하세요',
                              style: AppTextStyles.body
                                  .copyWith(color: subColor))
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(selected.displayName,
                                    style: AppTextStyles.body
                                        .copyWith(color: textColor)),
                                const SizedBox(height: 2),
                                Text(selected.address,
                                    style: AppTextStyles.caption
                                        .copyWith(color: subColor)),
                              ],
                            ),
                    ),
                    Icon(LucideIcons.chevronRight, size: 18, color: subColor),
                  ],
                ),
              ),
            ),
            if (_showSlopeError) ...[
              const SizedBox(height: AppSpacing.sm),
              Text('대상 슬로프를 선택해주세요',
                  style: AppTextStyles.captionSmall
                      .copyWith(color: AppColors.error)),
            ],
            const SizedBox(height: AppSpacing.lg),
            // ── 오류 내용 ──
            AppTextField(
              controller: _contentController,
              label: '오류 내용',
              hint: '무엇이 잘못됐는지 알려주세요',
              maxLines: 5,
              minLines: 3,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.xxl),
            AppButton(
              label: '신고하기',
              loading: _submitting,
              tone: AppButtonTone.accent,
              onPressed: (_submitting || _contentController.text.trim().isEmpty)
                  ? null
                  : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
