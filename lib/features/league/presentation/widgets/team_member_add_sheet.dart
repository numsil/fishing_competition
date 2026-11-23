import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../data/league_repository.dart';
import '../../data/league_team_model.dart';
import '../../data/team_assign_options.dart';

/// 팀에 여러 명을 한 번에 넣는 바텀시트.
///
/// 1명당 2탭이면 100명·20팀에서 200탭이 된다. 방향을 뒤집어 팀 1개당
/// 1번으로 만드는 것이 이 시트의 목적이다 — 확인 시 RPC 1회.
///
/// 기본 목록은 **미배정자만**이다. 전체 명단을 깔면 `전체 선택` 이
/// "모두 이 팀으로"가 되어, 되돌릴 수 없는 일괄 이동이 한 번의 탭으로
/// 일어난다 (이 경로에는 되돌리기가 없다). 다른 팀 소속은 검색으로 찾는다.
///
/// 고른 userId 목록을 돌려주고, 취소면 null 이다.
/// [remaining] 이 음수면 정원 무제한이다.
Future<List<String>?> showTeamMemberAddSheet({
  required BuildContext context,
  required LeagueTeam team,
  required List<LeagueRankEntry> participants,
  required Map<String, String?> teamIdByUserId,
  required Map<String, String> teamNameByUserId,
  required int remaining,
  required bool isDark,
}) {
  final selected = <String>{};
  final ctrl = TextEditingController();
  final sub = isDark ? AppColors.darkTextSub : AppColors.lightTextSub;
  final divColor = isDark ? AppColors.darkDivider : AppColors.lightDivider;
  final teamColor = AppColors.teamColor(team.color);
  final unlimited = remaining < 0;

  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: SafeArea(
        child: StatefulBuilder(
          builder: (ctx, setSheetState) {
            final q = ctrl.text.trim();
            final shown = memberAddCandidates(
              participants: participants,
              teamIdByUserId: teamIdByUserId,
              thisTeamId: team.id,
              query: q,
            );
            final atLimit = !unlimited && selected.length >= remaining;

            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.8,
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                  child: Row(children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          color: teamColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('${team.name}에 추가',
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.heading3),
                    ),
                    Text(
                      unlimited ? '정원 무제한' : '$remaining자리 남음',
                      style: AppTextStyles.caption.copyWith(
                          color: teamColor, fontWeight: FontWeight.w700),
                    ),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                  child: AppTextField(
                    controller: ctrl,
                    hint: '이름으로 찾기',
                    onChanged: (_) => setSheetState(() {}),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 2),
                  child: Row(children: [
                    Expanded(
                      child: Text(
                          q.isEmpty
                              ? '미배정 ${shown.length}명'
                              : '검색 결과 ${shown.length}명',
                          style: AppTextStyles.caption.copyWith(
                              color: sub, fontWeight: FontWeight.w700)),
                    ),
                    if (unlimited || remaining > 0)
                      TextButton(
                        onPressed: () => setSheetState(() {
                          selected
                            ..clear()
                            ..addAll(unlimited
                                ? shown.map((c) => c.userId)
                                : shown.take(remaining).map((c) => c.userId));
                        }),
                        child: const Text('전체 선택'),
                      ),
                  ]),
                ),
                if (shown.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                        q.isEmpty
                            ? '미배정 참가자가 없습니다.\n다른 팀에서 데려오려면 이름을 검색하세요.'
                            : '검색 결과가 없습니다',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: sub, height: 1.5)),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                      itemCount: shown.length,
                      itemBuilder: (_, i) {
                        final c = shown[i];
                        final checked = selected.contains(c.userId);
                        // 남은 자리를 넘는 줄은 비활성. 이미 고른 줄은 해제 가능.
                        final blocked = !checked && atLimit;
                        final currentTeam = teamNameByUserId[c.userId];
                        return Opacity(
                          opacity: blocked ? 0.55 : 1,
                          child: CheckboxListTile(
                            value: checked,
                            onChanged: blocked
                                ? null
                                : (v) => setSheetState(() {
                                      if (v == true) {
                                        selected.add(c.userId);
                                      } else {
                                        selected.remove(c.userId);
                                      }
                                    }),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                            title: Row(children: [
                              UserAvatar(
                                  username: c.username,
                                  avatarUrl: c.avatarUrl,
                                  radius: 15,
                                  isDark: isDark),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(c.username,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.body),
                              ),
                              if (blocked)
                                Text('자리 없음',
                                    style: AppTextStyles.caption.copyWith(
                                        color: AppColors.warning,
                                        fontWeight: FontWeight.w700))
                              else
                                Text(
                                    currentTeam == null
                                        ? '${c.totalCount}마리'
                                        : '$currentTeam · ${c.totalCount}마리',
                                    style: AppTextStyles.caption
                                        .copyWith(color: sub)),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
                Divider(height: 1, color: divColor),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
                  child: Column(children: [
                    AppButton(
                      label: selected.isEmpty
                          ? '추가할 사람을 고르세요'
                          : '${selected.length}명 추가',
                      icon: LucideIcons.userPlus,
                      onPressed: selected.isEmpty
                          ? null
                          : () => Navigator.pop(ctx, selected.toList()),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      unlimited
                          ? '미배정 참가자만 보입니다. 이름을 검색하면 다른 팀 소속도 나오고, 고르면 그 팀에서 옮겨집니다.'
                          : '미배정 참가자만 보입니다. 정원을 넘기면 더 고를 수 없습니다. 검색하면 다른 팀 소속도 나옵니다.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption
                          .copyWith(color: sub, height: 1.5),
                    ),
                  ]),
                ),
              ]),
            );
          },
        ),
      ),
    ),
  ).whenComplete(ctrl.dispose);
}
