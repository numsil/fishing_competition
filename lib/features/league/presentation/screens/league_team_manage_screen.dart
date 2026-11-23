import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/extensions/theme_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../data/league_repository.dart';
import '../../data/league_team_model.dart';

/// 호스트 전용 팀 관리 화면.
///
/// 팀 생성/이름 변경/삭제, 참가자별 팀 배정, 자동 셔플.
/// 참가자 명단은 leagueRankingProvider 를 그대로 재사용한다
/// (승인된 참가자 전원이 조과 0마리여도 0점 행으로 들어 있다).
class LeagueTeamManageScreen extends ConsumerWidget {
  const LeagueTeamManageScreen({super.key, required this.leagueId});

  final String leagueId;

  /// 팀 변경 후 갱신. 팀 소속이 바뀌어도 개인 점수는 바뀌지 않으므로
  /// 무거운 get_league_ranking RPC 는 다시 호출하지 않는다
  /// (호스트가 한 명씩 배정할 때마다 돌면 낭비다).
  void _refreshTeams(WidgetRef ref) {
    ref.invalidate(leagueTeamsProvider(leagueId));
  }

  /// 당겨서 새로고침. 사용자가 명시적으로 최신 데이터를 요청한 경우라
  /// 참가자 명단(순위)까지 다시 받는다.
  void _refreshAll(WidgetRef ref) {
    ref.invalidate(leagueTeamsProvider(leagueId));
    ref.invalidate(leagueRankingProvider(leagueId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = context.isDark;
    final sub = isDark ? AppColors.darkTextSub : AppColors.lightTextSub;
    final divColor = isDark ? AppColors.darkDivider : AppColors.lightDivider;
    final teamsAsync = ref.watch(leagueTeamsProvider(leagueId));
    final rankingAsync = ref.watch(leagueRankingProvider(leagueId));

    return Scaffold(
      appBar: AppBar(title: const Text('팀 관리')),
      body: teamsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('팀 정보를 불러오지 못했습니다: $e')),
        data: (teams) => rankingAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('참가자를 불러오지 못했습니다: $e')),
          data: (participants) {
            final byUserId = {for (final p in participants) p.userId: p};
            final assigned = <String>{};
            for (final t in teams) {
              assigned.addAll(t.memberUserIds);
            }
            final unassigned =
                participants.where((p) => !assigned.contains(p.userId)).toList();

            return RefreshIndicator(
              onRefresh: () async => _refreshAll(ref),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                children: [
                  Row(children: [
                    Expanded(
                      child: Text('참가자 ${participants.length}명 · ${teams.length}팀',
                          style: TextStyle(fontSize: 13, color: sub)),
                    ),
                    AppButton(
                      label: '자동 셔플',
                      icon: LucideIcons.shuffle,
                      variant: AppButtonVariant.outline,
                      size: AppButtonSize.sm,
                      fullWidth: false,
                      onPressed: teams.isEmpty ? null : () => _shuffle(context, ref),
                    ),
                  ]),
                  const SizedBox(height: 16),

                  if (unassigned.isNotEmpty) ...[
                    AppCard(
                      variant: AppCardVariant.tinted,
                      tintColor: AppColors.warning,
                      tintAlpha: 0.08,
                      borderColor: AppColors.warning.withValues(alpha: 0.35),
                      radius: 12,
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Icon(LucideIcons.alertCircle,
                                size: 16, color: AppColors.warning),
                            const SizedBox(width: 8),
                            Text('미배정 ${unassigned.length}명',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.warning)),
                          ]),
                          const SizedBox(height: 6),
                          for (final p in unassigned)
                            _MemberRow(
                              username: p.username,
                              avatarUrl: p.avatarUrl,
                              trailingLabel: '팀 선택',
                              trailingColor: AppColors.warning,
                              isDark: isDark,
                              onTap: teams.isEmpty
                                  ? null
                                  : () => _pickTeam(context, ref, teams, p.userId, null),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  for (final t in teams) ...[
                    _TeamCard(
                      team: t,
                      members: [
                        for (final uid in t.memberUserIds)
                          if (byUserId[uid] != null) byUserId[uid]!,
                      ],
                      isDark: isDark,
                      divColor: divColor,
                      sub: sub,
                      onRename: () => _editTeam(context, ref, t),
                      onRecolor: () => _editTeamColor(context, ref, t),
                      onDelete: () => _deleteTeam(context, ref, t),
                      onTapMember: (uid) => _pickTeam(context, ref, teams, uid, t.id),
                    ),
                    const SizedBox(height: 12),
                  ],

                  AppButton(
                    label: '팀 추가',
                    icon: LucideIcons.plus,
                    variant: AppButtonVariant.outline,
                    onPressed: () => _createTeam(context, ref, teams),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _shuffle(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(
      context,
      title: '자동 셔플',
      content: '승인된 참가자를 팀에 균등하게 다시 배정합니다.\n\n현재 배정은 모두 덮어씌워집니다.',
      confirmText: '셔플',
    );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(leagueRepositoryProvider).shuffleLeagueTeams(leagueId);
      _refreshTeams(ref);
      if (context.mounted) AppSnackBar.success(context, '팀을 다시 배정했습니다.');
    } catch (e) {
      if (context.mounted) AppSnackBar.error(context, _message(e));
    }
  }

  Future<void> _createTeam(
      BuildContext context, WidgetRef ref, List<LeagueTeam> teams) async {
    final name = await _promptName(context, title: '팀 추가', initial: '');
    if (name == null || !context.mounted) return;
    try {
      await ref.read(leagueRepositoryProvider).createLeagueTeam(
            leagueId: leagueId,
            name: name,
            color: AppColors.nextUnusedTeamColorKey(
                teams.map((t) => t.color)),
            sortOrder: nextTeamSortOrder(teams),
          );
      _refreshTeams(ref);
    } catch (e) {
      if (context.mounted) AppSnackBar.error(context, _message(e));
    }
  }

  Future<void> _editTeam(BuildContext context, WidgetRef ref, LeagueTeam t) async {
    final name = await _promptName(context, title: '팀 이름 변경', initial: t.name);
    if (name == null || !context.mounted) return;
    try {
      await ref
          .read(leagueRepositoryProvider)
          .updateLeagueTeam(teamId: t.id, name: name);
      _refreshTeams(ref);
    } catch (e) {
      if (context.mounted) AppSnackBar.error(context, _message(e));
    }
  }

  /// 팀 색 변경. 색은 팀 탭·개인 탭 배지의 식별 수단이라 겹쳤을 때
  /// 호스트가 직접 고칠 수 있어야 한다.
  Future<void> _editTeamColor(
      BuildContext context, WidgetRef ref, LeagueTeam t) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('팀 색 변경',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final key in AppColors.teamColors.keys)
                  Semantics(
                    label: key,
                    button: true,
                    selected: key == t.color,
                    child: InkWell(
                      onTap: () => Navigator.pop(ctx, key),
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.teamColors[key],
                          shape: BoxShape.circle,
                          border: key == t.color
                              ? Border.all(color: AppColors.darkText, width: 3)
                              : null,
                        ),
                        child: key == t.color
                            ? const Icon(LucideIcons.check,
                                size: 20, color: Colors.white)
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ]),
      ),
    );
    if (picked == null || !context.mounted || picked == t.color) return;
    try {
      await ref
          .read(leagueRepositoryProvider)
          .updateLeagueTeam(teamId: t.id, color: picked);
      _refreshTeams(ref);
    } catch (e) {
      if (context.mounted) AppSnackBar.error(context, _message(e));
    }
  }

  Future<void> _deleteTeam(BuildContext context, WidgetRef ref, LeagueTeam t) async {
    final ok = await showConfirmDialog(
      context,
      title: '팀 삭제',
      content: '${t.name} 을(를) 삭제합니다.\n\n'
          '팀원들은 미배정으로 돌아가고, 등록된 조과는 그대로 유지됩니다.',
      confirmText: '삭제',
      confirmColor: AppColors.error,
    );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(leagueRepositoryProvider).deleteLeagueTeam(t.id);
      _refreshTeams(ref);
    } catch (e) {
      if (context.mounted) AppSnackBar.error(context, _message(e));
    }
  }

  Future<void> _pickTeam(
    BuildContext context,
    WidgetRef ref,
    List<LeagueTeam> teams,
    String userId,
    String? currentTeamId,
  ) async {
    final picked = await showModalBottomSheet<_TeamPick>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('팀 선택',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
          for (final t in teams)
            ListTile(
              leading: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                    color: AppColors.teamColor(t.color), shape: BoxShape.circle),
              ),
              title: Text(t.name),
              trailing: t.id == currentTeamId
                  ? const Icon(LucideIcons.check, size: 18)
                  : null,
              onTap: () => Navigator.pop(ctx, _TeamPick(t.id)),
            ),
          if (currentTeamId != null)
            ListTile(
              leading: const Icon(LucideIcons.userMinus, size: 18),
              title: const Text('미배정으로'),
              onTap: () => Navigator.pop(ctx, const _TeamPick(null)),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (picked == null || !context.mounted) return;
    if (picked.teamId == currentTeamId) return;
    try {
      await ref.read(leagueRepositoryProvider).assignParticipantTeam(
            leagueId: leagueId,
            userId: userId,
            teamId: picked.teamId,
          );
      _refreshTeams(ref);
    } catch (e) {
      if (context.mounted) AppSnackBar.error(context, _message(e));
    }
  }

  Future<String?> _promptName(
    BuildContext context, {
    required String title,
    required String initial,
  }) async {
    final ctrl = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: AppTextField(
          controller: ctrl,
          hint: '팀 이름',
          maxLength: 20,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(
            onPressed: () {
              final v = ctrl.text.trim();
              if (v.isEmpty) return;
              Navigator.pop(ctx, v);
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return result;
  }

  String _message(Object e) {
    final s = e.toString();
    if (s.contains('NOT_LEAGUE_HOST')) return '호스트만 팀을 관리할 수 있습니다.';
    if (s.contains('NO_TEAMS')) return '먼저 팀을 만들어주세요.';
    if (s.contains('league_teams_league_id_name_key')) {
      return '이미 같은 이름의 팀이 있습니다.';
    }
    if (s.contains('league_teams_name_not_blank')) return '팀 이름을 입력해주세요.';
    return '처리에 실패했습니다: $e';
  }
}

class _TeamPick {
  const _TeamPick(this.teamId);
  final String? teamId;
}

class _TeamCard extends StatelessWidget {
  const _TeamCard({
    required this.team,
    required this.members,
    required this.isDark,
    required this.divColor,
    required this.sub,
    required this.onRename,
    required this.onRecolor,
    required this.onDelete,
    required this.onTapMember,
  });

  final LeagueTeam team;
  final List<LeagueRankEntry> members;
  final bool isDark;
  final Color divColor;
  final Color sub;
  final VoidCallback onRename;
  final VoidCallback onRecolor;
  final VoidCallback onDelete;
  final void Function(String userId) onTapMember;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      variant: AppCardVariant.surface,
      radius: 14,
      borderColor: divColor,
      padding: EdgeInsets.zero,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
          child: Row(children: [
            Semantics(
              label: '${team.name} 색 변경',
              button: true,
              child: InkWell(
                onTap: onRecolor,
                customBorder: const CircleBorder(),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                        color: AppColors.teamColor(team.color),
                        shape: BoxShape.circle),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Row(children: [
                Flexible(
                  child: Text(team.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 6),
                Text('${members.length}명',
                    style: TextStyle(fontSize: 12, color: sub)),
              ]),
            ),
            IconButton(
              onPressed: onRename,
              icon: const Icon(LucideIcons.pencil, size: 17),
              tooltip: '${team.name} 이름 변경',
            ),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(LucideIcons.trash2, size: 17, color: AppColors.error),
              tooltip: '${team.name} 삭제',
            ),
          ]),
        ),
        if (members.isNotEmpty) Divider(height: 1, color: divColor),
        for (final m in members)
          _MemberRow(
            username: m.username,
            avatarUrl: m.avatarUrl,
            trailingLabel: team.name,
            trailingColor: sub,
            isDark: isDark,
            onTap: () => onTapMember(m.userId),
          ),
        if (members.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(children: [
              Text('아직 팀원이 없습니다',
                  style: TextStyle(fontSize: 12, color: sub)),
            ]),
          ),
      ]),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.username,
    required this.avatarUrl,
    required this.trailingLabel,
    required this.trailingColor,
    required this.isDark,
    this.onTap,
  });

  final String username;
  final String? avatarUrl;
  final String trailingLabel;
  final Color trailingColor;
  final bool isDark;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(children: [
          UserAvatar(
              username: username,
              avatarUrl: avatarUrl,
              radius: 14,
              isDark: isDark),
          const SizedBox(width: 10),
          Expanded(
            child: Text(username,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14)),
          ),
          Text(trailingLabel,
              style: TextStyle(
                  fontSize: 12,
                  color: trailingColor,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          Icon(LucideIcons.chevronDown, size: 16, color: trailingColor),
        ]),
      ),
    );
  }
}
