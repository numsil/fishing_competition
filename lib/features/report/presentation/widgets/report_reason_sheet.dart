import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/extensions/theme_extensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/utils/banned_error_handler.dart';
import '../../data/report_repository.dart';

const _reasons = <String>[
  '음란물·선정성',
  '욕설·혐오 표현',
  '스팸·광고',
  '저작권 침해',
  '기타',
];

class ReportReasonSheet extends ConsumerStatefulWidget {
  const ReportReasonSheet({super.key, required this.postId});
  final String postId;

  static Future<void> show(BuildContext context, String postId) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReportReasonSheet(postId: postId),
    );
  }

  @override
  ConsumerState<ReportReasonSheet> createState() => _ReportReasonSheetState();
}

class _ReportReasonSheetState extends ConsumerState<ReportReasonSheet> {
  String? _selected;
  bool _submitting = false;

  Future<void> _submit() async {
    final reason = _selected;
    if (reason == null) return;
    setState(() => _submitting = true);
    try {
      await ref.read(reportRepositoryProvider).reportPost(
            postId: widget.postId,
            reason: reason,
          );
      if (!mounted) return;
      Navigator.pop(context);
      AppSnackBar.success(context, '신고가 접수되었습니다');
    } on AlreadyReportedException {
      if (!mounted) return;
      Navigator.pop(context);
      AppSnackBar.warning(context, '이미 신고한 게시물입니다');
    } on NotAuthenticatedException {
      if (!mounted) return;
      AppSnackBar.error(context, '로그인이 필요합니다');
      setState(() => _submitting = false);
    } catch (e) {
      if (await handleIfBanned(e)) return;
      if (!mounted) return;
      AppSnackBar.error(context, '신고 접수 실패: $e');
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final bg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subColor =
        isDark ? const Color(0xFF8E8E8E) : const Color(0xFF737373);
    final divColor =
        isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF444444)
                        : const Color(0xFFCCCCCC),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '신고 사유 선택',
                style: AppTextStyles.heading2.copyWith(color: textColor),
              ),
              const SizedBox(height: 4),
              Text(
                '신고 내용은 운영팀이 검토 후 처리합니다.',
                style: AppTextStyles.bodySmall.copyWith(color: subColor),
              ),
              const SizedBox(height: 16),
              for (final r in _reasons) ...[
                _ReasonTile(
                  label: r,
                  selected: _selected == r,
                  textColor: textColor,
                  onTap: _submitting
                      ? null
                      : () => setState(() => _selected = r),
                ),
                Divider(height: 1, color: divColor),
              ],
              const SizedBox(height: 16),
              AppButton(
                label: '신고 제출',
                variant: AppButtonVariant.destructive,
                onPressed:
                    (_selected == null || _submitting) ? null : _submit,
                loading: _submitting,
              ),
              const SizedBox(height: 8),
              AppButton(
                label: '취소',
                variant: AppButtonVariant.ghost,
                onPressed:
                    _submitting ? null : () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReasonTile extends StatelessWidget {
  const _ReasonTile({
    required this.label,
    required this.selected,
    required this.textColor,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final Color textColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = context.accentColor;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? accent : textColor.withValues(alpha: 0.4),
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.body.copyWith(
                  color: textColor,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
