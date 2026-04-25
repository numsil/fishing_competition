import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

// ── 슬라이드 확인 위젯 ────────────────────────────────────
class SlideToConfirm extends StatefulWidget {
  const SlideToConfirm({
    super.key,
    this.label = '밀어서 확인',
    required this.onConfirmed,
    this.color,
    this.height = 58.0,
  });

  final String label;
  final VoidCallback onConfirmed;
  final Color? color;
  final double height;

  @override
  State<SlideToConfirm> createState() => _SlideToConfirmState();
}

class _SlideToConfirmState extends State<SlideToConfirm>
    with SingleTickerProviderStateMixin {
  double _progress = 0;
  bool _confirmed = false;
  double _progressBeforeReset = 0;

  late AnimationController _resetCtrl;
  late Animation<double> _resetAnim;

  static const double _thumbSize = 50.0;
  static const double _threshold = 0.88;

  @override
  void initState() {
    super.initState();
    _resetCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _resetAnim = CurvedAnimation(parent: _resetCtrl, curve: Curves.elasticOut);
    _resetAnim.addListener(() {
      if (mounted) {
        setState(() => _progress = _progressBeforeReset * (1 - _resetAnim.value));
      }
    });
  }

  @override
  void dispose() {
    _resetCtrl.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details, double maxDrag) {
    if (_confirmed) return;
    setState(() {
      _progress = ((_progress * maxDrag + details.delta.dx) / maxDrag)
          .clamp(0.0, 1.0);
    });
  }

  void _onDragEnd(double maxDrag) {
    if (_confirmed) return;
    if (_progress >= _threshold) {
      setState(() => _confirmed = true);
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 380), widget.onConfirmed);
    } else {
      _progressBeforeReset = _progress;
      _resetCtrl.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.error;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth;
        final maxDrag = trackWidth - _thumbSize - 8;
        final thumbLeft = _progress * maxDrag + 4;

        return GestureDetector(
          onHorizontalDragUpdate: (d) => _onDragUpdate(d, maxDrag),
          onHorizontalDragEnd: (_) => _onDragEnd(maxDrag),
          child: Container(
            height: widget.height,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.12 : 0.07),
              borderRadius: BorderRadius.circular(widget.height / 2),
              border: Border.all(
                color: color.withValues(alpha: isDark ? 0.35 : 0.25),
              ),
            ),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                // 진행 채우기
                Positioned(
                  left: 0, top: 0, bottom: 0,
                  width: thumbLeft + _thumbSize,
                  child: Container(
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: _progress * 0.25),
                      borderRadius:
                          BorderRadius.circular(widget.height / 2),
                    ),
                  ),
                ),
                // 중앙 라벨
                Center(
                  child: Opacity(
                    opacity: _confirmed
                        ? 0
                        : (1 - _progress * 2.0).clamp(0.0, 1.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chevron_right,
                            color: color.withValues(alpha: 0.5), size: 18),
                        const SizedBox(width: 2),
                        Text(
                          widget.label,
                          style: TextStyle(
                            color: color.withValues(alpha: 0.75),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(Icons.chevron_right,
                            color: color.withValues(alpha: 0.5), size: 18),
                      ],
                    ),
                  ),
                ),
                // 완료 체크
                if (_confirmed)
                  Center(
                    child: Icon(Icons.check_rounded, color: color, size: 22),
                  ),
                // 썸
                Positioned(
                  left: thumbLeft,
                  top: 4,
                  bottom: 4,
                  width: _thumbSize,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius:
                          BorderRadius.circular(_thumbSize / 2),
                    ),
                    child: Icon(
                      _confirmed
                          ? Icons.check_rounded
                          : Icons.chevron_right,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── 삭제 확인 바텀시트 ────────────────────────────────────
Future<void> showDeleteConfirmSheet(
  BuildContext context, {
  required String title,
  required String content,
  String slideLabel = '밀어서 삭제',
  required VoidCallback onConfirmed,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return showModalBottomSheet(
    context: context,
    backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _DeleteConfirmSheet(
      title: title,
      content: content,
      slideLabel: slideLabel,
      isDark: isDark,
      onConfirmed: () {
        Navigator.pop(ctx);
        onConfirmed();
      },
    ),
  );
}

class _DeleteConfirmSheet extends StatelessWidget {
  const _DeleteConfirmSheet({
    required this.title,
    required this.content,
    required this.slideLabel,
    required this.isDark,
    required this.onConfirmed,
  });

  final String title;
  final String content;
  final String slideLabel;
  final bool isDark;
  final VoidCallback onConfirmed;

  @override
  Widget build(BuildContext context) {
    final sub = isDark ? AppColors.darkTextSub : AppColors.lightTextSub;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 핸들
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF444444)
                    : const Color(0xFFCCCCCC),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            // 경고 아이콘
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.error, size: 26),
            ),
            const SizedBox(height: 14),
            // 제목
            Text(
              title,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            // 내용
            Text(
              content,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: sub, height: 1.5),
            ),
            const SizedBox(height: 24),
            // 슬라이드 바
            SlideToConfirm(
              label: slideLabel,
              color: AppColors.error,
              onConfirmed: onConfirmed,
            ),
            const SizedBox(height: 12),
            // 취소 텍스트
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('취소', style: TextStyle(color: sub, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }
}
