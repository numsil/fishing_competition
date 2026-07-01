import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/extensions/theme_extensions.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_elevation.dart';
import '../core/theme/app_durations.dart';
import '../core/services/app_update_service.dart';
import '../core/widgets/app_button.dart';
import '../core/widgets/app_card.dart';
import '../core/widgets/app_snack_bar.dart';
import '../core/widgets/app_text_field.dart';
import '../core/widgets/confirm_dialog.dart';
import '../core/widgets/empty_state.dart';
import '../core/widgets/info_chip.dart';
import '../core/widgets/menu_item.dart';
import '../core/widgets/app_action_sheet.dart';
import '../core/widgets/score_card.dart';
import '../core/widgets/section_label.dart';
import '../core/widgets/slide_to_confirm.dart';
import '../core/widgets/stat_widgets.dart';
import '../core/widgets/tier_avatar.dart';
import '../core/widgets/update_dialog.dart';
import '../core/widgets/user_avatar.dart';

class WidgetCatalogScreen extends StatefulWidget {
  const WidgetCatalogScreen({super.key});

  @override
  State<WidgetCatalogScreen> createState() => _WidgetCatalogScreenState();
}

class _WidgetCatalogScreenState extends State<WidgetCatalogScreen> {
  final _textCtrl = TextEditingController();

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final accent = context.accentColor;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final sub = isDark ? AppColors.darkTextSub : AppColors.lightTextSub;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            const Text('위젯 카탈로그', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('DEBUG', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.warning)),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── 색상 ──────────────────────────────────────────
          _Section(label: '색상', color: accent, children: [
            _ColorGrid(isDark: isDark),
          ]),

          // ── 타이포그래피 ──────────────────────────────────
          _Section(label: '타이포그래피', color: accent, children: [
            _TypoRow('heading1', AppTextStyles.heading1),
            _TypoRow('heading2', AppTextStyles.heading2),
            _TypoRow('heading3', AppTextStyles.heading3),
            _TypoRow('heading4', AppTextStyles.heading4),
            _TypoRow('bodyBold', AppTextStyles.bodyBold),
            _TypoRow('body', AppTextStyles.body),
            _TypoRow('bodySmall', AppTextStyles.bodySmall),
            _TypoRow('caption', AppTextStyles.caption),
            _TypoRow('captionBold', AppTextStyles.captionBold),
            _TypoRow('captionSmall', AppTextStyles.captionSmall),
            _TypoRow('badge', AppTextStyles.badge),
          ]),

          // ── 버튼 ─────────────────────────────────────────
          _Section(label: '버튼 — variant', color: accent, children: [
            AppButton(label: 'primary', onPressed: () {}),
            const SizedBox(height: 10),
            AppButton(label: 'secondary', onPressed: () {}, variant: AppButtonVariant.secondary),
            const SizedBox(height: 10),
            AppButton(label: 'ghost', onPressed: () {}, variant: AppButtonVariant.ghost),
            const SizedBox(height: 10),
            AppButton(label: 'destructive', onPressed: () {}, variant: AppButtonVariant.destructive),
            const SizedBox(height: 10),
            AppButton(label: 'disabled', onPressed: null),
          ]),
          _Section(label: '버튼 — 확장', color: accent, children: [
            AppButton(
              label: 'outline · accent',
              onPressed: () {},
              variant: AppButtonVariant.outline,
            ),
            const SizedBox(height: 10),
            AppButton(
              label: 'outline · error',
              onPressed: () {},
              variant: AppButtonVariant.outline,
              tone: AppButtonTone.error,
            ),
            const SizedBox(height: 10),
            AppButton(
              label: 'ghost · error',
              onPressed: () {},
              variant: AppButtonVariant.ghost,
              tone: AppButtonTone.error,
            ),
            const SizedBox(height: 10),
            AppButton(
              label: 'disabledColor (회색)',
              onPressed: null,
              disabledColor: const Color(0xFF2A2A2A),
              disabledLabelColor: const Color(0xFFEEEEEE),
            ),
            const SizedBox(height: 10),
            AppButton(label: 'elevation 6', onPressed: () {}, elevation: 6),
          ]),
          _Section(label: '버튼 — size', color: accent, children: [
            Row(children: [
              Expanded(child: AppButton(label: 'sm', onPressed: () {}, size: AppButtonSize.sm)),
              const SizedBox(width: 8),
              Expanded(child: AppButton(label: 'md', onPressed: () {}, size: AppButtonSize.md)),
              const SizedBox(width: 8),
              Expanded(child: AppButton(label: 'lg', onPressed: () {})),
            ]),
            const SizedBox(height: 10),
            AppButton(label: '아이콘 버튼', onPressed: () {}, icon: LucideIcons.fish),
          ]),

          // ── 텍스트 필드 ───────────────────────────────────
          _Section(label: '텍스트 필드', color: accent, children: [
            AppTextField(label: '기본 필드', hint: '입력하세요', controller: _textCtrl),
            const SizedBox(height: 12),
            const AppTextField(label: '비밀번호', hint: '비밀번호 입력', obscureText: true),
            const SizedBox(height: 12),
            const AppTextField(label: '여러 줄', hint: '내용을 입력하세요', maxLines: 3, minLines: 3),
            const SizedBox(height: 12),
            AppTextField(
              label: '아이콘 포함',
              hint: '위치 검색',
              suffixIcon: Icon(Icons.location_on_outlined, color: sub, size: 20),
            ),
            const SizedBox(height: 12),
            const AppTextField(label: '비활성화', hint: '입력 불가', enabled: false),
          ]),

          // ── 카드 ─────────────────────────────────────────
          _Section(label: '카드 — variant', color: accent, children: [
            AppCard(
              child: _CardContent(title: 'surface', sub: sub),
            ),
            const SizedBox(height: 10),
            AppCard(
              variant: AppCardVariant.tinted,
              child: _CardContent(title: 'tinted', sub: sub),
            ),
            const SizedBox(height: 10),
            AppCard(
              variant: AppCardVariant.outlined,
              child: _CardContent(title: 'outlined', sub: sub),
            ),
            const SizedBox(height: 10),
            AppCard(
              onTap: () {},
              child: _CardContent(title: 'onTap 있는 카드 (탭 가능)', sub: sub),
            ),
          ]),

          // ── 카드 — 확장 props ────────────────────────────
          _Section(label: '카드 — 확장', color: accent, children: [
            AppCard(
              variant: AppCardVariant.tinted,
              tintColor: accent,
              tintAlpha: 0.06,
              borderColor: accent.withValues(alpha: 0.3),
              child: _CardContent(title: 'tinted + borderColor', sub: sub),
            ),
            const SizedBox(height: 10),
            AppCard(
              borderColor: accent,
              borderWidth: 1.5,
              child: _CardContent(title: 'borderWidth 1.5', sub: sub),
            ),
            const SizedBox(height: 10),
            AppCard(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
              child: _CardContent(title: 'boxShadow', sub: sub),
            ),
            const SizedBox(height: 10),
            AppCard(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              child: _CardContent(title: 'margin (좌우 24)', sub: sub),
            ),
          ]),

          // ── 칩 ───────────────────────────────────────────
          _Section(label: '칩', color: accent, children: [
            Wrap(spacing: 12, runSpacing: 10, children: [
              InfoChip(icon: LucideIcons.fish, label: 'InfoChip', color: accent),
              InfoChip(icon: LucideIcons.mapPin, label: '위치', color: AppColors.info),
              InfoChip(icon: LucideIcons.award, label: '런커', color: AppColors.gold),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 12, runSpacing: 10, children: [
              InfoChipFilled(icon: LucideIcons.fish, label: 'InfoChipFilled', color: accent, isDark: isDark),
              InfoChipFilled(icon: LucideIcons.trophy, label: '1위', color: AppColors.gold, isDark: isDark),
              InfoChipFilled(icon: LucideIcons.badgeCheck, label: '인증', color: AppColors.success, isDark: isDark),
              InfoChipFilled(icon: LucideIcons.alertTriangle, label: '경고', color: AppColors.warning, isDark: isDark),
            ]),
          ]),

          // ── 섹션 라벨 ─────────────────────────────────────
          _Section(label: '섹션 라벨', color: accent, children: [
            SectionLabel(text: '기본 섹션 라벨', color: accent),
            const SizedBox(height: 8),
            SectionLabel(text: '에러 색상', color: AppColors.error),
            const SizedBox(height: 8),
            SectionLabel(text: '골드 색상', color: AppColors.gold),
          ]),

          // ── 알림 (SnackBar) ───────────────────────────────
          _Section(label: '알림 (SnackBar)', color: accent, children: [
            Row(children: [
              Expanded(child: AppButton(
                label: 'success',
                onPressed: () => AppSnackBar.success(context, '성공 메시지입니다'),
                size: AppButtonSize.sm,
              )),
              const SizedBox(width: 8),
              Expanded(child: AppButton(
                label: 'error',
                onPressed: () => AppSnackBar.error(context, '에러 메시지입니다'),
                variant: AppButtonVariant.destructive,
                size: AppButtonSize.sm,
              )),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: AppButton(
                label: 'warning',
                onPressed: () => AppSnackBar.warning(context, '경고 메시지입니다'),
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.sm,
              )),
              const SizedBox(width: 8),
              Expanded(child: AppButton(
                label: 'info',
                onPressed: () => AppSnackBar.info(context, '안내 메시지입니다'),
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.sm,
              )),
            ]),
          ]),

          // ── 모달 / 다이얼로그 ─────────────────────────────
          _Section(label: '모달 / 다이얼로그', color: accent, children: [
            AppButton(
              label: 'ConfirmDialog 열기',
              onPressed: () => showConfirmDialog(
                context,
                title: '정말 삭제하시겠어요?',
                content: '삭제하면 복구할 수 없어요.',
                confirmText: '삭제',
                confirmColor: AppColors.error,
                icon: LucideIcons.trash2,
              ),
              variant: AppButtonVariant.secondary,
            ),
            const SizedBox(height: 10),
            AppButton(
              label: '삭제 확인 바텀시트 열기',
              onPressed: () => showDeleteConfirmSheet(
                context,
                title: '게시물 삭제',
                content: '이 게시물을 삭제하면 복구할 수 없어요.',
                onConfirmed: () {},
              ),
              variant: AppButtonVariant.destructive,
            ),
          ]),

          // ── SlideToConfirm ────────────────────────────────
          _Section(label: 'SlideToConfirm', color: accent, children: [
            SlideToConfirm(
              label: '밀어서 확인',
              color: AppColors.error,
              onConfirmed: () => AppSnackBar.success(context, '확인됐어요!'),
            ),
          ]),

          // ── 옵션 시트 (showAppActionSheet + AppMenuItem) ──
          _Section(label: '옵션 시트 (showAppActionSheet)', color: accent, children: [
            AppButton(
              label: '옵션 시트 열기',
              variant: AppButtonVariant.secondary,
              onPressed: () => showAppActionSheet(
                context,
                items: [
                  AppMenuItem(
                    icon: LucideIcons.pencil,
                    label: '수정하기',
                    onTap: () => Navigator.pop(context),
                  ),
                  AppMenuItem(
                    icon: LucideIcons.share2,
                    label: '공유하기',
                    onTap: () => Navigator.pop(context),
                  ),
                  AppMenuItem(
                    icon: LucideIcons.download,
                    label: '저장하기',
                    onTap: () => Navigator.pop(context),
                  ),
                  const AppMenuDivider(),
                  AppMenuItem(
                    icon: LucideIcons.trash2,
                    label: '삭제',
                    destructive: true,
                    onTap: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ]),

          // ── 통계 위젯 ─────────────────────────────────────
          _Section(label: '통계 위젯', color: accent, children: [
            Row(children: [
              StatBox(icon: LucideIcons.fish, value: '42', label: '게시물', isDark: isDark, accent: accent),
              const SizedBox(width: 8),
              StatBox(icon: LucideIcons.trophy, value: '3', label: '리그', isDark: isDark, accent: accent),
              const SizedBox(width: 8),
              StatBox(icon: LucideIcons.award, value: '1', label: '런커', isDark: isDark, accent: accent),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              StatBoxTinted(value: '52cm', label: '최대 길이', isDark: isDark, accent: accent),
              const SizedBox(width: 8),
              StatBoxTinted(value: '1,250g', label: '최대 무게', isDark: isDark, accent: accent),
            ]),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              StatNumber(value: '128', label: '게시물', subColor: sub),
              StatNumber(value: '47', label: '팔로워', subColor: sub),
              StatNumber(value: '23', label: '팔로잉', subColor: sub),
            ]),
          ]),

          // ── 점수 카드 ─────────────────────────────────────
          _Section(label: '점수 카드 (ScoreCard)', color: accent, children: [
            ScoreCard(label: '개인 기록 점수', icon: LucideIcons.fish, score: 850, isDark: isDark, accent: accent),
            const SizedBox(height: 10),
            ScoreCard(label: '리그 점수', icon: LucideIcons.trophy, score: 4500, isDark: isDark, accent: accent),
            const SizedBox(height: 10),
            ScoreCard(label: '레전드 티어', icon: LucideIcons.award, score: 21000, isDark: isDark, accent: accent),
          ]),

          // ── EmptyState ────────────────────────────────────
          _Section(label: 'EmptyState', color: accent, children: [
            SizedBox(
              height: 160,
              child: EmptyState(
                icon: LucideIcons.fish,
                message: '아직 게시물이 없어요',
                subMessage: '첫 번째 조과를 기록해보세요',
                subColor: sub,
              ),
            ),
          ]),

          // ── 아바타 (UserAvatar) ───────────────────────────
          _Section(label: '아바타 (UserAvatar)', color: accent, children: [
            Row(children: [
              UserAvatar(username: '홍길동', radius: 20, isDark: isDark),
              const SizedBox(width: 14),
              UserAvatar(username: '김철수', radius: 28, isDark: isDark),
              const SizedBox(width: 14),
              UserAvatar(username: '이영희', radius: 28, isDark: isDark, borderColor: accent),
            ]),
          ]),

          // ── 티어 아바타 (TierAvatar) ──────────────────────
          _Section(label: '티어 아바타 (TierAvatar)', color: accent, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              Column(mainAxisSize: MainAxisSize.min, children: [
                TierAvatar(username: 'M', score: 6000, radius: 28, isDark: isDark),
                const SizedBox(height: 6),
                Text('마스터', style: TextStyle(fontSize: 10, color: sub)),
              ]),
              Column(mainAxisSize: MainAxisSize.min, children: [
                TierAvatar(username: 'L', score: 12000, radius: 28, isDark: isDark),
                const SizedBox(height: 6),
                Text('레전드', style: TextStyle(fontSize: 10, color: sub)),
              ]),
              Column(mainAxisSize: MainAxisSize.min, children: [
                TierAvatar(username: 'G', score: 21000, radius: 28, isDark: isDark),
                const SizedBox(height: 6),
                Text('그랜드마스터', style: TextStyle(fontSize: 10, color: sub)),
              ]),
            ]),
          ]),

          // ── 업데이트 다이얼로그 (샘플) ────────────────────
          _Section(label: '업데이트 다이얼로그 (UpdateDialog)', color: accent, children: [
            AppButton(
              label: 'UpdateDialog 열기 (샘플)',
              variant: AppButtonVariant.secondary,
              onPressed: () => showUpdateDialog(
                context,
                const AppVersionInfo(
                  version: '1.1.0',
                  buildNumber: 60,
                  currentBuildNumber: 52,
                  releaseNotes: '• 중고거래 팝니다/삽니다 추가\n• 버그 수정 및 성능 개선',
                  forceUpdate: false,
                ),
                AppUpdateService(Supabase.instance.client),
              ),
            ),
          ]),

          // ── 간격 토큰 (AppSpacing) ────────────────────────
          _Section(label: '간격 (AppSpacing)', color: accent, children: [
            _SpaceRow('xs', AppSpacing.xs, accent),
            _SpaceRow('sm', AppSpacing.sm, accent),
            _SpaceRow('md', AppSpacing.md, accent),
            _SpaceRow('lg', AppSpacing.lg, accent),
            _SpaceRow('xl', AppSpacing.xl, accent),
            _SpaceRow('xxl', AppSpacing.xxl, accent),
            _SpaceRow('xxxl', AppSpacing.xxxl, accent),
            _SpaceRow('huge', AppSpacing.huge, accent),
            _SpaceRow('mega', AppSpacing.mega, accent),
          ]),

          // ── 모서리 토큰 (AppRadius) ───────────────────────
          _Section(label: '모서리 (AppRadius)', color: accent, children: [
            Wrap(spacing: 14, runSpacing: 14, children: [
              _RadiusBox('xs', AppRadius.xs, accent),
              _RadiusBox('sm', AppRadius.sm, accent),
              _RadiusBox('md', AppRadius.md, accent),
              _RadiusBox('lg', AppRadius.lg, accent),
              _RadiusBox('xl', AppRadius.xl, accent),
              _RadiusBox('xxl', AppRadius.xxl, accent),
            ]),
          ]),

          // ── 그림자 토큰 (AppElevation) ────────────────────
          _Section(label: '그림자 (AppElevation)', color: accent, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _ShadowBox('sm', AppElevation.sm(Colors.black), isDark),
              _ShadowBox('md', AppElevation.md(Colors.black), isDark),
              _ShadowBox('lg', AppElevation.lg(Colors.black), isDark),
            ]),
          ]),

          // ── 애니메이션 시간 (AppDurations) ────────────────
          _Section(label: '애니메이션 (AppDurations)', color: accent, children: [
            _DurRow('instant', AppDurations.instant, sub),
            _DurRow('fast', AppDurations.fast, sub),
            _DurRow('normal', AppDurations.normal, sub),
            _DurRow('slow', AppDurations.slow, sub),
          ]),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ── 섹션 래퍼 ────────────────────────────────────────────
class _Section extends StatelessWidget {
  const _Section({required this.label, required this.color, required this.children});
  final String label;
  final Color color;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(text: label, color: color),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

// ── 색상 그리드 ───────────────────────────────────────────
class _ColorGrid extends StatelessWidget {
  const _ColorGrid({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = isDark
        ? [
            ('darkBg', AppColors.darkBg),
            ('darkSurface', AppColors.darkSurface),
            ('darkSurface2', AppColors.darkSurface2),
            ('neonGreen', AppColors.neonGreen),
            ('neonGreenDim', AppColors.neonGreenDim),
            ('darkText', AppColors.darkText),
            ('darkTextSub', AppColors.darkTextSub),
            ('darkDivider', AppColors.darkDivider),
          ]
        : [
            ('lightBg', AppColors.lightBg),
            ('lightSurface', AppColors.lightSurface),
            ('navy', AppColors.navy),
            ('navyLight', AppColors.navyLight),
            ('lightText', AppColors.lightText),
            ('lightTextSub', AppColors.lightTextSub),
            ('lightDivider', AppColors.lightDivider),
          ];

    final shared = [
      ('gold', AppColors.gold),
      ('success', AppColors.success),
      ('warning', AppColors.warning),
      ('error', AppColors.error),
      ('info', AppColors.info),
      ('liveRed', AppColors.liveRed),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...colors.map((c) => _ColorChip(name: c.$1, color: c.$2)),
        ...shared.map((c) => _ColorChip(name: c.$1, color: c.$2)),
      ],
    );
  }
}

class _ColorChip extends StatelessWidget {
  const _ColorChip({required this.name, required this.color});
  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
        ),
        const SizedBox(height: 4),
        Text(name, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ── 타이포그래피 행 ────────────────────────────────────────
class _TypoRow extends StatelessWidget {
  const _TypoRow(this.name, this.style);
  final String name;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final sub = context.isDark ? AppColors.darkTextSub : AppColors.lightTextSub;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(name, style: TextStyle(fontSize: 10, color: sub, fontFamily: 'monospace')),
          ),
          Expanded(child: Text('가나다 ABC 123', style: style)),
        ],
      ),
    );
  }
}

// ── 카드 내부 더미 콘텐츠 ──────────────────────────────────
class _CardContent extends StatelessWidget {
  const _CardContent({required this.title, required this.sub});
  final String title;
  final Color sub;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 4),
        Text('카드 서브텍스트 예시입니다', style: TextStyle(fontSize: 12, color: sub)),
      ],
    );
  }
}

// ── 간격 행 ───────────────────────────────────────────────
class _SpaceRow extends StatelessWidget {
  const _SpaceRow(this.name, this.value, this.color);
  final String name;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final sub = context.isDark ? AppColors.darkTextSub : AppColors.lightTextSub;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(name,
                style: TextStyle(fontSize: 11, color: sub, fontFamily: 'monospace')),
          ),
          Container(height: 12, width: value, color: color),
          const SizedBox(width: 8),
          Text('${value.toInt()}', style: TextStyle(fontSize: 10, color: sub)),
        ],
      ),
    );
  }
}

// ── 모서리 박스 ───────────────────────────────────────────
class _RadiusBox extends StatelessWidget {
  const _RadiusBox(this.name, this.value, this.color);
  final String name;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final sub = context.isDark ? AppColors.darkTextSub : AppColors.lightTextSub;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            border: Border.all(color: color),
            borderRadius: BorderRadius.circular(value),
          ),
        ),
        const SizedBox(height: 4),
        Text('$name ${value.toInt()}', style: TextStyle(fontSize: 9, color: sub)),
      ],
    );
  }
}

// ── 그림자 박스 ───────────────────────────────────────────
class _ShadowBox extends StatelessWidget {
  const _ShadowBox(this.name, this.shadow, this.isDark);
  final String name;
  final List<BoxShadow> shadow;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final sub = isDark ? AppColors.darkTextSub : AppColors.lightTextSub;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 48,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface2 : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: shadow,
          ),
        ),
        const SizedBox(height: 10),
        Text(name, style: TextStyle(fontSize: 10, color: sub)),
      ],
    );
  }
}

// ── 애니메이션 시간 행 ─────────────────────────────────────
class _DurRow extends StatelessWidget {
  const _DurRow(this.name, this.duration, this.sub);
  final String name;
  final Duration duration;
  final Color sub;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(name,
                style: TextStyle(fontSize: 11, color: sub, fontFamily: 'monospace')),
          ),
          Text('${duration.inMilliseconds}ms',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
