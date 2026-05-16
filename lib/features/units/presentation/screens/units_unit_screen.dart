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
// 일반적인 모노/나일론 라인 기준 근사값 (대부분의 라인 패키지 표기 기준)
const List<(double ho, double lb)> _lineTable = [
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

double _hoToLb(double ho) {
  if (ho <= 0) return 0;
  // 근사식: lb ≈ 4 * 호수 (모노 라인 기준)
  return ho * 4.0;
}

double _lbToHo(double lb) {
  if (lb <= 0) return 0;
  return lb / 4.0;
}

class _LineTab extends StatefulWidget {
  const _LineTab();
  @override
  State<_LineTab> createState() => _LineTabState();
}

class _LineTabState extends State<_LineTab> {
  final _ho = TextEditingController();
  final _lb = TextEditingController();

  @override
  void dispose() {
    _ho.dispose();
    _lb.dispose();
    super.dispose();
  }

  void _onHo(String v) {
    final n = double.tryParse(v);
    if (n == null) {
      _lb.text = '';
      return;
    }
    _lb.text = _fmt(_hoToLb(n));
  }

  void _onLb(String v) {
    final n = double.tryParse(v);
    if (n == null) {
      _ho.text = '';
      return;
    }
    _ho.text = _fmt(_lbToHo(n));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: AppSpacing.pageAll,
      child: Column(
        children: [
          _ConverterCard(
            title: '라인 호수 ↔ 파운드(lb)',
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
                    label: '파운드',
                    controller: _lb,
                    onChanged: _onLb,
                    suffix: 'lb',
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.gapH16,
          _ReferenceTable(
            title: '라인 호수 환산표',
            note: '모노/나일론 라인 기준 일반 근사값. 제품별로 차이 있음.',
            leftHeader: '호수',
            rightHeader: '파운드(lb)',
            rows: _lineTable
                .map((e) => ('${_fmt(e.$1)}호', '${_fmt(e.$2)} lb'))
                .toList(),
          ),
        ],
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
  final _oz = TextEditingController();
  final _g = TextEditingController();

  @override
  void dispose() {
    _oz.dispose();
    _g.dispose();
    super.dispose();
  }

  void _onOz(String v) {
    final n = double.tryParse(v);
    if (n == null) {
      _g.text = '';
      return;
    }
    _g.text = _fmt(n * _gPerOz);
  }

  void _onG(String v) {
    final n = double.tryParse(v);
    if (n == null) {
      _oz.text = '';
      return;
    }
    _oz.text = _fmt(n / _gPerOz);
  }

  @override
  Widget build(BuildContext context) {
    const List<double> rows = [
      1 / 32, 1 / 16, 1 / 8, 1 / 4, 3 / 8, 1 / 2, 5 / 8, 3 / 4, 1.0, 1.5, 2.0, 3.0
    ];
    return SingleChildScrollView(
      padding: AppSpacing.pageAll,
      child: Column(
        children: [
          _ConverterCard(
            title: '온스(oz) ↔ 그램(g)',
            child: Row(
              children: [
                Expanded(
                  child: _NumberField(
                    label: '온스',
                    controller: _oz,
                    onChanged: _onOz,
                    suffix: 'oz',
                  ),
                ),
                AppSpacing.gapW12,
                const Icon(LucideIcons.arrowLeftRight, size: 18),
                AppSpacing.gapW12,
                Expanded(
                  child: _NumberField(
                    label: '그램',
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
          _TappableRefTable(
            title: '인치 → cm',
            note: '1 in = 2.54 cm',
            leftHeader: '인치',
            rightHeader: 'cm',
            rows: inchRows
                .map((v) =>
                    (v.toDouble(), '$v in', '${_fmt(v * _cmPerInch)} cm'))
                .toList(),
            onTap: onTapInch,
          ),
          AppSpacing.gapH16,
          _TappableRefTable(
            title: '피트 → m',
            note: '1 ft = 30.48 cm',
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
