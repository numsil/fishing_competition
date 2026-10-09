import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/extensions/theme_extensions.dart';
import '../../../../core/theme/app_colors.dart';

/// 리그 조과 수치 수정 다이얼로그.
///
/// 참가자가 올린 원래 값을 보여주고, 바꿀 값을 입력받는다.
/// 입력하는 동안 "49.0cm → 53.0cm" 로 변화를 미리 보여줘서
/// 숫자를 잘못 넣는 실수를 줄인다.
///
/// 반환값: 수정할 값(double). 취소하면 null.
class MeasureEditDialog extends StatefulWidget {
  const MeasureEditDialog({
    super.key,
    required this.currentValue,
    required this.isWeight,
  });

  /// 현재 저장된 값 (길이 cm 또는 무게 g).
  final double? currentValue;

  /// 무게 규칙 리그 여부. true면 단위 g, false면 cm.
  final bool isWeight;

  @override
  State<MeasureEditDialog> createState() => _MeasureEditDialogState();
}

class _MeasureEditDialogState extends State<MeasureEditDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.currentValue == null ? '' : _format(widget.currentValue!),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String get _unit => widget.isWeight ? 'g' : 'cm';

  String _format(double v) =>
      widget.isWeight ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  double? get _parsed {
    final v = double.tryParse(_ctrl.text.trim());
    if (v == null || v <= 0) return null;
    return v;
  }

  bool get _changed =>
      _parsed != null && _parsed != widget.currentValue;

  /// ±버튼. 길이는 0.5cm, 무게는 50g 단위로 조정한다.
  void _adjust(double delta) {
    final base = _parsed ?? widget.currentValue ?? 0;
    final next = (base + delta).clamp(0.0, widget.isWeight ? 50000.0 : 200.0);
    _ctrl.text = _format(next.toDouble());
    _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final accent = context.accentColor;
    final bg = isDark ? AppColors.darkSurface : Colors.white;
    final sub = isDark ? AppColors.darkTextSub : AppColors.lightTextSub;
    final divider = isDark ? AppColors.darkDivider : AppColors.lightDivider;
    final fieldBg = isDark ? AppColors.darkSurface2 : const Color(0xFFF4F4F5);

    final step = widget.isWeight ? 50.0 : 0.5;

    return Dialog(
      backgroundColor: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.isWeight ? LucideIcons.scale : LucideIcons.ruler,
                color: accent,
                size: 26,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.isWeight ? '무게 수정' : '길이 수정',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              widget.currentValue == null
                  ? '참가자가 값을 입력하지 않았습니다'
                  : '참가자가 올린 값 ${_format(widget.currentValue!)}$_unit',
              style: TextStyle(fontSize: 13, color: sub),
            ),
            const SizedBox(height: 20),

            // ── 큰 숫자 입력 ───────────────────────────
            Container(
              decoration: BoxDecoration(
                color: fieldBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _changed
                      ? accent.withValues(alpha: 0.5)
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  IntrinsicWidth(
                    child: TextField(
                      controller: _ctrl,
                      autofocus: true,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: !widget.isWeight,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        hintText: '0',
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _unit,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: sub,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── 빠른 조정 ──────────────────────────────
            Row(
              children: [
                _StepButton(label: '-${_format(step)}', onTap: () => _adjust(-step)),
                const SizedBox(width: 8),
                _StepButton(label: '+${_format(step)}', onTap: () => _adjust(step)),
                const SizedBox(width: 8),
                _StepButton(
                    label: '-${_format(step * 2)}', onTap: () => _adjust(-step * 2)),
                const SizedBox(width: 8),
                _StepButton(
                    label: '+${_format(step * 2)}', onTap: () => _adjust(step * 2)),
              ],
            ),
            const SizedBox(height: 16),

            // ── 변경 미리보기 ──────────────────────────
            if (_changed && widget.currentValue != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${_format(widget.currentValue!)}$_unit',
                    style: TextStyle(
                      fontSize: 14,
                      color: sub,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(LucideIcons.arrowRight, size: 14, color: sub),
                  const SizedBox(width: 8),
                  Text(
                    '${_format(_parsed!)}$_unit',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                ],
              )
            else
              Text(
                '수정하면 작성자에게 알림이 전송됩니다',
                style: TextStyle(fontSize: 12, color: sub),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 20),

            Divider(color: divider, height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      '취소',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: sub,
                      ),
                    ),
                  ),
                ),
                Container(width: 1, height: 24, color: divider),
                Expanded(
                  child: TextButton(
                    onPressed:
                        _changed ? () => Navigator.pop(context, _parsed) : null,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      '수정하기',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _changed ? accent : sub.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final sub = isDark ? AppColors.darkTextSub : AppColors.lightTextSub;
    final border = isDark ? AppColors.darkDivider : AppColors.lightDivider;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: sub,
            ),
          ),
        ),
      ),
    );
  }
}
