import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/extensions/theme_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../data/league_team_model.dart';

/// 팀 순위 탭 상단의 "내 팀" 배너를 그려야 하는가.
///
/// 호스트 배정 리그에 그리면 누를 수 없는 버튼을 보여주는 셈이다
/// (set_my_league_team 이 SELF_PICK_DISABLED 를 던진다).
///
/// 프로덕션 경로(league_team_ranking_tab)가 호출하므로 @visibleForTesting 을
/// 붙이면 안 된다 — analyze 가 invalid_use_of_visible_for_testing_member
/// 경고를 내고, 경고는 analyze 를 실패시킨다.
bool shouldShowMyTeamBanner({
  required bool isSelfPick,
  required bool isApprovedParticipant,
}) =>
    isSelfPick && isApprovedParticipant;

/// 자율 선택 리그에서 본인의 팀 상태를 보여주는 배너.
///
/// 미배정이면 "팀에 들어가야 점수가 반영된다"고 알리고 선택 화면으로 보낸다.
/// 배정돼 있으면 한 줄로 내 팀과 `변경` 만 보여준다.
class LeagueMyTeamBanner extends StatelessWidget {
  const LeagueMyTeamBanner({
    super.key,
    required this.leagueId,
    required this.myTeam,
    required this.hasAnyTeam,
  });

  final String leagueId;

  /// 본인이 속한 팀. null 이면 미배정.
  final LeagueTeam? myTeam;

  /// 리그에 팀이 하나라도 있는가. 없으면 고를 수 있는 게 없다.
  final bool hasAnyTeam;

  void _open(BuildContext context) => context.push('/league/my-team/$leagueId');

  @override
  Widget build(BuildContext context) {
    final accent = context.accentColor;
    final sub = context.isDark ? AppColors.darkTextSub : AppColors.lightTextSub;
    final divColor =
        context.isDark ? AppColors.darkDivider : AppColors.lightDivider;
    final team = myTeam;

    if (team != null) {
      return AppCard(
        variant: AppCardVariant.surface,
        radius: 14,
        borderColor: divColor,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        child: Row(children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: AppColors.teamColor(team.color), shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text('내 팀: ${team.name}',
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.heading4),
          ),
          TextButton(
            onPressed: () => _open(context),
            child: const Text('변경'),
          ),
        ]),
      );
    }

    return AppCard(
      variant: AppCardVariant.tinted,
      tintColor: accent,
      tintAlpha: 0.08,
      borderColor: accent,
      radius: 14,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(LucideIcons.users, size: 17, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('아직 팀을 선택하지 않았습니다',
                    style: AppTextStyles.heading4),
                const SizedBox(height: 4),
                Text(
                  hasAnyTeam
                      ? '팀에 들어가야 내 조과가 팀 점수에 반영됩니다. 리그 중에도 바꿀 수 있습니다.'
                      : '호스트가 팀을 만들면 선택할 수 있습니다.',
                  style:
                      AppTextStyles.caption.copyWith(color: sub, height: 1.5),
                ),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 12),
        AppButton(
          label: '내 팀 선택',
          onPressed: hasAnyTeam ? () => _open(context) : null,
        ),
      ]),
    );
  }
}
