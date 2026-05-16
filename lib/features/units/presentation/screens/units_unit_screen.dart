import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/extensions/theme_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';

class UnitsScreen extends StatelessWidget {
  const UnitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final bg = isDark ? AppColors.darkBg : Colors.white;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: textColor),
          title: Text(
            '단위 변환',
            style: AppTextStyles.heading3.copyWith(color: textColor),
          ),
          bottom: TabBar(
            isScrollable: true,
            labelColor: context.accentColor,
            unselectedLabelColor:
                isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
            indicatorColor: context.accentColor,
            labelStyle: AppTextStyles.bodyBold,
            unselectedLabelStyle: AppTextStyles.body,
            tabs: const [
              Tab(text: '낚시줄 호수↔lb'),
              Tab(text: '싱커 호수↔g'),
              Tab(text: '무게 oz↔g'),
              Tab(text: '길이 in/ft↔cm/m'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _LineTab(),
            _SinkerTab(),
            _OzGramTab(),
            _LengthTab(),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// 공통 빌딩 블록
// ─────────────────────────────────────────────────────────
class _ConverterCard extends StatelessWidget {
  const _ConverterCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final textColor =
        context.isDark ? AppColors.darkText : AppColors.lightText;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: AppTextStyles.heading4.copyWith(color: textColor)),
          AppSpacing.gapH12,
          child,
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.label,
    required this.controller,
    required this.onChanged,
    required this.suffix,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subColor =
        isDark ? AppColors.darkTextSub : AppColors.lightTextSub;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTextStyles.captionBold.copyWith(color: subColor)),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: controller,
          onChanged: onChanged,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
          ],
          style: AppTextStyles.bodyBold.copyWith(color: textColor),
          decoration: InputDecoration(
            suffixText: suffix,
            suffixStyle:
                AppTextStyles.bodyBold.copyWith(color: subColor),
            isDense: true,
          ),
        ),
      ],
    );
  }
}

class _ReferenceTable extends StatelessWidget {
  const _ReferenceTable({
    required this.title,
    required this.leftHeader,
    required this.rightHeader,
    required this.rows,
    this.note,
  });

  final String title;
  final String leftHeader;
  final String rightHeader;
  final List<(String, String)> rows;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subColor =
        isDark ? AppColors.darkTextSub : AppColors.lightTextSub;
    final dividerColor =
        isDark ? AppColors.darkDivider : AppColors.lightDivider;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: AppTextStyles.heading4.copyWith(color: textColor)),
          if (note != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(note!,
                style:
                    AppTextStyles.caption.copyWith(color: subColor)),
          ],
          AppSpacing.gapH12,
          Row(
            children: [
              Expanded(
                child: Text(leftHeader,
                    style: AppTextStyles.captionBold
                        .copyWith(color: subColor)),
              ),
              Expanded(
                child: Text(
                  rightHeader,
                  textAlign: TextAlign.right,
                  style:
                      AppTextStyles.captionBold.copyWith(color: subColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(height: 1, color: dividerColor),
          ...rows.map((r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(r.$1,
                          style: AppTextStyles.body
                              .copyWith(color: textColor)),
                    ),
                    Expanded(
                      child: Text(
                        r.$2,
                        textAlign: TextAlign.right,
                        style: AppTextStyles.bodyBold
                            .copyWith(color: textColor),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

String _fmt(double v, {int decimals = 1}) {
  if (v.isNaN || v.isInfinite) return '-';
  final s = v.toStringAsFixed(decimals);
  // trim trailing zeros
  if (s.contains('.')) {
    return s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }
  return s;
}

// ─────────────────────────────────────────────────────────
// 1) 낚시줄 호수 ↔ 파운드(lb)
// ─────────────────────────────────────────────────────────
// 나일론/카본(모노) 기준: lb ≈ 호 × 4
const List<(double ho, double lb)> _monoLineTable = [
  (0.4, 1.7),
  (0.6, 2.5),
  (0.8, 3.0),
  (1.0, 4.0),
  (1.2, 5.0),
  (1.5, 6.0),
  (1.7, 7.0),
  (2.0, 8.0),
  (2.5, 10.0),
  (3.0, 12.0),
  (3.5, 14.0),
  (4.0, 16.0),
  (5.0, 20.0),
  (6.0, 22.0),
  (8.0, 30.0),
  (10.0, 40.0),
  (12.0, 50.0),
];

// 합사(PE) 기준 — 제품별 편차가 크지만 통상적인 환산값
const List<(double ho, double lb)> _peLineTable = [
  (0.3, 6.0),
  (0.4, 8.0),
  (0.6, 12.0),
  (0.8, 16.0),
  (1.0, 20.0),
  (1.2, 25.0),
  (1.5, 30.0),
  (2.0, 35.0),
  (2.5, 40.0),
  (3.0, 50.0),
  (4.0, 60.0),
  (5.0, 75.0),
  (6.0, 90.0),
  (8.0, 100.0),
];

double _monoHoToLb(double ho) => ho * 4.0;
double _monoLbToHo(double lb) => lb / 4.0;

// PE는 비선형이지만 간단 환산은 약 20배 (실제 표 기준 평균)
double _peHoToLb(double ho) => ho * 20.0;
double _peLbToHo(double lb) => lb / 20.0;

class _LineTab extends StatefulWidget {
  const _LineTab();
  @override
  State<_LineTab> createState() => _LineTabState();
}

class _LineTabState extends State<_LineTab> {
  final _monoHo = TextEditingController();
  final _monoLb = TextEditingController();
  final _peHo = TextEditingController();
  final _peLb = TextEditingController();
  int _segment = 0; // 0 = 나일론/카본, 1 = 합사

  @override
  void dispose() {
    _monoHo.dispose();
    _monoLb.dispose();
    _peHo.dispose();
    _peLb.dispose();
    super.dispose();
  }

  void _onMonoHo(String v) {
    final n = double.tryParse(v);
    _monoLb.text = n == null ? '' : _fmt(_monoHoToLb(n));
  }

  void _onMonoLb(String v) {
    final n = double.tryParse(v);
    _monoHo.text = n == null ? '' : _fmt(_monoLbToHo(n));
  }

  void _onPeHo(String v) {
    final n = double.tryParse(v);
    _peLb.text = n == null ? '' : _fmt(_peHoToLb(n));
  }

  void _onPeLb(String v) {
    final n = double.tryParse(v);
    _peHo.text = n == null ? '' : _fmt(_peLbToHo(n));
  }

  Widget _converterRow({
    required TextEditingController hoCtrl,
    required TextEditingController lbCtrl,
    required ValueChanged<String> onHo,
    required ValueChanged<String> onLb,
  }) {
    return Row(
      children: [
        Expanded(
          child: _NumberField(
            label: '호수',
            controller: hoCtrl,
            onChanged: onHo,
            suffix: '호',
          ),
        ),
        AppSpacing.gapW12,
        const Icon(LucideIcons.arrowLeftRight, size: 18),
        AppSpacing.gapW12,
        Expanded(
          child: _NumberField(
            label: '파운드',
            controller: lbCtrl,
            onChanged: onLb,
            suffix: 'lb',
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMono = _segment == 0;
    return SingleChildScrollView(
      padding: AppSpacing.pageAll,
      child: Column(
        children: [
          _SegmentSwitch(
            value: _segment,
            labels: const ['나일론/카본', '합사(PE)'],
            onChanged: (v) => setState(() => _segment = v),
          ),
          AppSpacing.gapH16,
          if (isMono) ...[
            _ConverterCard(
              title: '나일론/카본 (모노) ↔ lb',
              child: _converterRow(
                hoCtrl: _monoHo,
                lbCtrl: _monoLb,
                onHo: _onMonoHo,
                onLb: _onMonoLb,
              ),
            ),
            AppSpacing.gapH16,
            _ReferenceTable(
              title: '나일론/카본 환산표',
              note: '모노 라인 기준 (lb ≈ 호수 × 4). 제품별 차이 있음.',
              leftHeader: '호수',
              rightHeader: '파운드(lb)',
              rows: _monoLineTable
                  .map((e) => ('${_fmt(e.$1)}호', '${_fmt(e.$2)} lb'))
                  .toList(),
            ),
          ] else ...[
            _ConverterCard(
              title: '합사 (PE) ↔ lb',
              child: _converterRow(
                hoCtrl: _peHo,
                lbCtrl: _peLb,
                onHo: _onPeHo,
                onLb: _onPeLb,
              ),
            ),
            AppSpacing.gapH16,
            _ReferenceTable(
              title: '합사(PE) 환산표',
              note: 'PE 라인 기준 일반값 (lb ≈ 호수 × 20). 제조사별 편차 큼.',
              leftHeader: 'PE 호수',
              rightHeader: '파운드(lb)',
              rows: _peLineTable
                  .map((e) => ('${_fmt(e.$1)}호', '${_fmt(e.$2)} lb'))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// 세그먼트 스위치 (상단 토글 버튼)
class _SegmentSwitch extends StatelessWidget {
  const _SegmentSwitch({
    required this.value,
    required this.labels,
    required this.onChanged,
  });

  final int value;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final accent = context.accentColor;
    final bg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border =
        isDark ? AppColors.darkDivider : AppColors.lightDivider;
    final inactive =
        isDark ? AppColors.darkTextSub : AppColors.lightTextSub;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: List.generate(labels.length, (i) {
          final selected = i == value;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                ),
                alignment: Alignment.center,
                child: Text(
                  labels[i],
                  style: AppTextStyles.bodyBold.copyWith(
                    color: selected
                        ? (isDark ? Colors.black : Colors.white)
                        : inactive,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// 2) 싱커(추) 호수 ↔ 그램(g)
// ─────────────────────────────────────────────────────────
// 일본 호수 기준: 1호 = 3.75g (1돈)
const double _sinkerPerHo = 3.75;

double _sinkerHoToG(double ho) => ho * _sinkerPerHo;
double _sinkerGToHo(double g) => g / _sinkerPerHo;

const List<double> _sinkerHos = [
  0.5, 0.8, 1, 1.5, 2, 3, 4, 5, 6, 8, 10, 12, 15, 20, 25, 30, 40, 50
];

class _SinkerTab extends StatefulWidget {
  const _SinkerTab();
  @override
  State<_SinkerTab> createState() => _SinkerTabState();
}

class _SinkerTabState extends State<_SinkerTab> {
  final _ho = TextEditingController();
  final _g = TextEditingController();

  @override
  void dispose() {
    _ho.dispose();
    _g.dispose();
    super.dispose();
  }

  void _onHo(String v) {
    final n = double.tryParse(v);
    if (n == null) {
      _g.text = '';
      return;
    }
    _g.text = _fmt(_sinkerHoToG(n));
  }

  void _onG(String v) {
    final n = double.tryParse(v);
    if (n == null) {
      _ho.text = '';
      return;
    }
    _ho.text = _fmt(_sinkerGToHo(n));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: AppSpacing.pageAll,
      child: Column(
        children: [
          _ConverterCard(
            title: '싱커 호수 ↔ 그램(g)',
            child: Row(
              children: [
                Expanded(
                  child: _NumberField(
                    label: '호수',
                    controller: _ho,
                    onChanged: _onHo,
                    suffix: '호',
                  ),
                ),
                AppSpacing.gapW12,
                const Icon(LucideIcons.arrowLeftRight, size: 18),
                AppSpacing.gapW12,
                Expanded(
                  child: _NumberField(
                    label: '무게',
                    controller: _g,
                    onChanged: _onG,
                    suffix: 'g',
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.gapH16,
          _ReferenceTable(
            title: '싱커 호수 환산표',
            note: '1호 = 3.75g (1돈) 기준',
            leftHeader: '호수',
            rightHeader: '무게(g)',
            rows: _sinkerHos
                .map((h) => ('${_fmt(h)}호', '${_fmt(_sinkerHoToG(h))} g'))
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// 3) 무게 oz ↔ g
// ─────────────────────────────────────────────────────────
const double _gPerOz = 28.3495;

class _OzGramTab extends StatefulWidget {
  const _OzGramTab();
  @override
  State<_OzGramTab> createState() => _OzGramTabState();
}

class _OzGramTabState extends State<_OzGramTab> {
  final _ozWhole = TextEditingController();
  final _ozNum = TextEditingController();
  final _ozDen = TextEditingController();
  final _g = TextEditingController();

  // 무한 루프 방지 (g→oz로 oz 필드 갱신 시 onChanged 다시 안 타도록)
  bool _updatingOz = false;
  bool _updatingG = false;

  @override
  void dispose() {
    _ozWhole.dispose();
    _ozNum.dispose();
    _ozDen.dispose();
    _g.dispose();
    super.dispose();
  }

  double _readOzValue() {
    final w = double.tryParse(_ozWhole.text) ?? 0;
    final num = double.tryParse(_ozNum.text);
    final den = double.tryParse(_ozDen.text);
    if (num != null && den != null && den != 0) {
      return w + num / den;
    }
    return w;
  }

  void _onOzChanged(String _) {
    if (_updatingOz) return;
    final oz = _readOzValue();
    _updatingG = true;
    _g.text = oz == 0 &&
            _ozWhole.text.isEmpty &&
            _ozNum.text.isEmpty &&
            _ozDen.text.isEmpty
        ? ''
        : _fmt(oz * _gPerOz);
    _updatingG = false;
  }

  void _onG(String v) {
    if (_updatingG) return;
    final n = double.tryParse(v);
    _updatingOz = true;
    if (n == null) {
      _ozWhole.text = '';
      _ozNum.text = '';
      _ozDen.text = '';
    } else {
      final snapped = _snapOzToFraction(n / _gPerOz);
      _ozWhole.text = snapped.whole == 0 ? '' : '${snapped.whole}';
      _ozNum.text = snapped.num == 0 ? '' : '${snapped.num}';
      _ozDen.text = snapped.num == 0 ? '' : '${snapped.den}';
    }
    _updatingOz = false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final subColor =
        isDark ? AppColors.darkTextSub : AppColors.lightTextSub;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;

    const List<double> rows = [
      1 / 32, 1 / 16, 1 / 8, 1 / 4, 3 / 8, 1 / 2, 5 / 8, 3 / 4, 1.0, 1.5, 2.0, 3.0
    ];

    return SingleChildScrollView(
      padding: AppSpacing.pageAll,
      child: Column(
        children: [
          _ConverterCard(
            title: '온스(oz) ↔ 그램(g)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('온스',
                    style: AppTextStyles.captionBold
                        .copyWith(color: subColor)),
                const SizedBox(height: AppSpacing.sm),
                _NumberField(
                  label: '정수부',
                  controller: _ozWhole,
                  onChanged: _onOzChanged,
                  suffix: 'oz',
                ),
                AppSpacing.gapH12,
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: _NumberField(
                        label: '분자',
                        controller: _ozNum,
                        onChanged: _onOzChanged,
                        suffix: '',
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 12),
                      child: Text('/',
                          style: AppTextStyles.heading3
                              .copyWith(color: textColor)),
                    ),
                    Expanded(
                      child: _NumberField(
                        label: '분모',
                        controller: _ozDen,
                        onChanged: _onOzChanged,
                        suffix: '',
                      ),
                    ),
                  ],
                ),
                AppSpacing.gapH16,
                const Center(
                    child: Icon(LucideIcons.arrowDownUp, size: 18)),
                AppSpacing.gapH16,
                _NumberField(
                  label: '그램',
                  controller: _g,
                  onChanged: _onG,
                  suffix: 'g',
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(LucideIcons.info, size: 12, color: subColor),
                    AppSpacing.gapW4,
                    Expanded(
                      child: Text(
                        'g → oz는 가장 가까운 분수(1/32 단위)로 자동 환산됩니다. 근사값일 수 있어요.',
                        style: AppTextStyles.captionSmall
                            .copyWith(color: subColor),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          AppSpacing.gapH16,
          _ReferenceTable(
            title: '루어 무게 환산표',
            note: '1 oz = 28.3495 g',
            leftHeader: 'oz',
            rightHeader: 'g',
            rows: rows
                .map((o) => (_ozLabel(o), '${_fmt(o * _gPerOz)} g'))
                .toList(),
          ),
        ],
      ),
    );
  }
}

// oz 값을 1/32 단위로 스냅 후 정수부 + 약분된 분자/분모로 분해
class _OzSnap {
  final int whole;
  final int num;
  final int den;
  const _OzSnap(this.whole, this.num, this.den);
}

int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);

_OzSnap _snapOzToFraction(double oz) {
  if (oz < 0) oz = 0;
  final total32 = (oz * 32).round();
  final whole = total32 ~/ 32;
  final remainder = total32 % 32;
  if (remainder == 0) return _OzSnap(whole, 0, 1);
  final g = _gcd(remainder, 32);
  return _OzSnap(whole, remainder ~/ g, 32 ~/ g);
}

String _ozLabel(double v) {
  const fractions = <(double, String)>[
    (1 / 32, '1/32'),
    (1 / 16, '1/16'),
    (1 / 8, '1/8'),
    (1 / 4, '1/4'),
    (3 / 8, '3/8'),
    (1 / 2, '1/2'),
    (5 / 8, '5/8'),
    (3 / 4, '3/4'),
  ];
  for (final f in fractions) {
    if ((v - f.$1).abs() < 0.0001) return '${f.$2} oz';
  }
  return '${_fmt(v)} oz';
}

// ─────────────────────────────────────────────────────────
// 4) 길이 인치/피트 ↔ cm/m
// ─────────────────────────────────────────────────────────
const double _cmPerInch = 2.54;
const double _cmPerFoot = 30.48;

class _LengthTab extends StatefulWidget {
  const _LengthTab();
  @override
  State<_LengthTab> createState() => _LengthTabState();
}

class _LengthTabState extends State<_LengthTab> {
  final _inch = TextEditingController();
  final _ft = TextEditingController();
  final _cm = TextEditingController();
  final _m = TextEditingController();
  int _exampleSegment = 0; // 0 = 인치, 1 = 피트

  @override
  void dispose() {
    _inch.dispose();
    _ft.dispose();
    _cm.dispose();
    _m.dispose();
    super.dispose();
  }

  void _setFromCm(double cm) {
    _inch.text = _fmt(cm / _cmPerInch);
    _ft.text = _fmt(cm / _cmPerFoot);
    _cm.text = _fmt(cm);
    _m.text = _fmt(cm / 100);
  }

  void _onInch(String v) {
    final n = double.tryParse(v);
    if (n == null) return _clearOthers(_inch);
    _ft.text = _fmt(n / 12);
    _cm.text = _fmt(n * _cmPerInch);
    _m.text = _fmt(n * _cmPerInch / 100);
  }

  void _onFt(String v) {
    final n = double.tryParse(v);
    if (n == null) return _clearOthers(_ft);
    _inch.text = _fmt(n * 12);
    _cm.text = _fmt(n * _cmPerFoot);
    _m.text = _fmt(n * _cmPerFoot / 100);
  }

  void _onCm(String v) {
    final n = double.tryParse(v);
    if (n == null) return _clearOthers(_cm);
    _inch.text = _fmt(n / _cmPerInch);
    _ft.text = _fmt(n / _cmPerFoot);
    _m.text = _fmt(n / 100);
  }

  void _onM(String v) {
    final n = double.tryParse(v);
    if (n == null) return _clearOthers(_m);
    final cm = n * 100;
    _inch.text = _fmt(cm / _cmPerInch);
    _ft.text = _fmt(cm / _cmPerFoot);
    _cm.text = _fmt(cm);
  }

  void _clearOthers(TextEditingController keep) {
    for (final c in [_inch, _ft, _cm, _m]) {
      if (c != keep) c.text = '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final inchRows = const [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];
    final ftRows = const [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 14];

    // 사용 안내. 입력 시 _setFromCm 사용은 표 탭 시 사용
    void onTapInch(double v) {
      _setFromCm(v * _cmPerInch);
      FocusScope.of(context).unfocus();
    }

    void onTapFt(double v) {
      _setFromCm(v * _cmPerFoot);
      FocusScope.of(context).unfocus();
    }

    return SingleChildScrollView(
      padding: AppSpacing.pageAll,
      child: Column(
        children: [
          _ConverterCard(
            title: '길이 변환',
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _NumberField(
                        label: '인치',
                        controller: _inch,
                        onChanged: _onInch,
                        suffix: 'in',
                      ),
                    ),
                    AppSpacing.gapW12,
                    Expanded(
                      child: _NumberField(
                        label: '피트',
                        controller: _ft,
                        onChanged: _onFt,
                        suffix: 'ft',
                      ),
                    ),
                  ],
                ),
                AppSpacing.gapH12,
                Row(
                  children: [
                    Expanded(
                      child: _NumberField(
                        label: '센티미터',
                        controller: _cm,
                        onChanged: _onCm,
                        suffix: 'cm',
                      ),
                    ),
                    AppSpacing.gapW12,
                    Expanded(
                      child: _NumberField(
                        label: '미터',
                        controller: _m,
                        onChanged: _onM,
                        suffix: 'm',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          AppSpacing.gapH16,
          _SegmentSwitch(
            value: _exampleSegment,
            labels: const ['인치 예시', '피트 예시'],
            onChanged: (v) => setState(() => _exampleSegment = v),
          ),
          AppSpacing.gapH12,
          if (_exampleSegment == 0)
            _TappableRefTable(
              title: '인치 → cm',
              note: '1 in = 2.54 cm. 행을 탭하면 변환기에 값이 입력됩니다.',
              leftHeader: '인치',
              rightHeader: 'cm',
              rows: inchRows
                  .map((v) =>
                      (v.toDouble(), '$v in', '${_fmt(v * _cmPerInch)} cm'))
                  .toList(),
              onTap: onTapInch,
            )
          else
            _TappableRefTable(
              title: '피트 → m',
              note: '1 ft = 30.48 cm. 행을 탭하면 변환기에 값이 입력됩니다.',
              leftHeader: '피트',
              rightHeader: 'm',
              rows: ftRows
                  .map((v) => (v.toDouble(), '$v ft',
                      '${_fmt(v * _cmPerFoot / 100)} m'))
                  .toList(),
              onTap: onTapFt,
            ),
        ],
      ),
    );
  }
}

class _TappableRefTable extends StatelessWidget {
  const _TappableRefTable({
    required this.title,
    required this.note,
    required this.leftHeader,
    required this.rightHeader,
    required this.rows,
    required this.onTap,
  });

  final String title;
  final String note;
  final String leftHeader;
  final String rightHeader;
  final List<(double value, String left, String right)> rows;
  final ValueChanged<double> onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subColor =
        isDark ? AppColors.darkTextSub : AppColors.lightTextSub;
    final dividerColor =
        isDark ? AppColors.darkDivider : AppColors.lightDivider;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: AppTextStyles.heading4.copyWith(color: textColor)),
          const SizedBox(height: AppSpacing.xs),
          Text(note,
              style: AppTextStyles.caption.copyWith(color: subColor)),
          AppSpacing.gapH12,
          Row(
            children: [
              Expanded(
                child: Text(leftHeader,
                    style: AppTextStyles.captionBold
                        .copyWith(color: subColor)),
              ),
              Expanded(
                child: Text(rightHeader,
                    textAlign: TextAlign.right,
                    style: AppTextStyles.captionBold
                        .copyWith(color: subColor)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(height: 1, color: dividerColor),
          ...rows.map((r) => InkWell(
                onTap: () => onTap(r.$1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(r.$2,
                            style: AppTextStyles.body
                                .copyWith(color: textColor)),
                      ),
                      Expanded(
                        child: Text(r.$3,
                            textAlign: TextAlign.right,
                            style: AppTextStyles.bodyBold
                                .copyWith(color: textColor)),
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
