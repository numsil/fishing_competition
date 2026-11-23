import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/extensions/theme_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../data/league_repository.dart';
import '../../data/league_team_model.dart';
import '../../data/team_assign_options.dart';
import '../../data/team_capacity.dart';
import '../widgets/team_member_add_sheet.dart';

/// 셔플 되돌리기가 실패했을 때 스냅샷을 버려야 하는가.
///
/// 스냅샷이 가리키는 팀이 삭제됐거나 참가자가 탈퇴했으면 그 스냅샷으로는
/// 다시는 성공할 수 없다. 버리지 않으면 `되돌리기` 버튼이 남아 사용자가
/// 같은 에러를 반복해서 본다. 일시적 실패(네트워크, 경합)는 유지한다.
@visibleForTesting
bool shouldDropSnapshot(Object error) {
  final s = error.toString();
  return s.contains('TEAM_NOT_IN_LEAGUE') || s.contains('NOT_PARTICIPANT');
}

/// 호스트 전용 팀 관리 화면.
///
/// 팀 생성/이름 변경/색 변경/삭제, 참가자 배정(단건·다중), 자동 셔플과
/// 되돌리기, 팀당 정원 조정.
///
/// 참가자 명단은 leagueRankingProvider 를 그대로 재사용한다
/// (승인된 참가자 전원이 조과 0마리여도 0점 행으로 들어 있다).
class LeagueTeamManageScreen extends ConsumerStatefulWidget {
  const LeagueTeamManageScreen({super.key, required this.leagueId});

  final String leagueId;

  @override
  ConsumerState<LeagueTeamManageScreen> createState() =>
      _LeagueTeamManageScreenState();
}

class _LeagueTeamManageScreenState
    extends ConsumerState<LeagueTeamManageScreen> {
  /// 펼친 팀 id. 20팀에서 전부 펼치면 화면이 성립하지 않으므로 기본은
  /// 전부 접힘이다. (팀 순위 탭의 기본 펼침 규칙과는 별개다 — 그쪽은
  /// 점수를 보는 화면이고 여기는 배정하는 화면이다)
  final _expanded = <String>{};

  /// 직전 셔플의 **이전** 배정. 화면을 나가면 사라진다 — DB 에 저장하지
  /// 않는다. 커버 범위는 "방금 셔플이 실수였다" 하나다.
  List<TeamAssignment>? _undoSnapshot;

  /// 정원 스테퍼의 낙관적 값. null 이면 서버 값을 그대로 쓴다.
  ///
  /// 서버 값만 보고 그리면 왕복이 끝날 때까지 숫자가 그대로여서, 호스트가
  /// 빠르게 다섯 번 누르면 다섯 번 모두 같은 값(current+1)을 보내고
  /// 결과는 1 이 된다. 왕복도 5회 낭비된다.
  int? _capacityDraft;

  /// 진행 중인 정원 저장. 마지막 값만 서버에 반영한다.
  bool _savingCapacity = false;

  String get leagueId => widget.leagueId;

  /// 팀 변경 후 갱신. 팀 소속이 바뀌어도 개인 점수는 바뀌지 않으므로
  /// 무거운 get_league_ranking RPC 는 다시 호출하지 않는다
  /// (호스트가 한 명씩 배정할 때마다 돌면 낭비다).
  void _refreshTeams() {
    ref.invalidate(leagueTeamsProvider(leagueId));
  }

  /// 당겨서 새로고침. 사용자가 명시적으로 최신 데이터를 요청한 경우라
  /// 참가자 명단(순위)과 리그 정보까지 다시 받는다.
  void _refreshAll() {
    ref.invalidate(leagueTeamsProvider(leagueId));
    ref.invalidate(leagueRankingProvider(leagueId));
    ref.invalidate(leagueDetailProvider(leagueId));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final sub = isDark ? AppColors.darkTextSub : AppColors.lightTextSub;
    final divColor = isDark ? AppColors.darkDivider : AppColors.lightDivider;
    final teamsAsync = ref.watch(leagueTeamsProvider(leagueId));
    final rankingAsync = ref.watch(leagueRankingProvider(leagueId));
    // 정원은 리그 단위다. 리그 상세는 호스트가 관리 화면으로 들어오는
    // 경로에서 이미 캐시돼 있으므로 사실상 추가 쿼리가 아니다.
    final serverCapacity = ref
            .watch(leagueDetailProvider(leagueId))
            .valueOrNull
            ?.teamCapacity ??
        0;
    // 낙관적 값이 있으면 그걸 쓴다 (연속 탭이 유실되지 않게).
    final capacity = _capacityDraft ?? serverCapacity;

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
            // 팀 카드·시트가 같은 수를 보도록 한 곳에서 센다.
            final memberCountByTeamId = <String, int>{
              for (final t in teams)
                t.id: t.memberUserIds
                    .where((uid) => byUserId.containsKey(uid))
                    .length,
            };

            return RefreshIndicator(
              onRefresh: () async => _refreshAll(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                children: [
                  // ── 요약 바 ──
                  Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('참가자 ${participants.length}명 · ${teams.length}팀',
                              style:
                                  AppTextStyles.bodySmall.copyWith(color: sub)),
                          const SizedBox(height: 2),
                          Text(
                            '미배정 ${unassigned.length}명',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: unassigned.isEmpty
                                  ? context.accentColor
                                  : AppColors.warning,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_undoSnapshot != null) ...[
                      AppButton(
                        label: '되돌리기',
                        icon: LucideIcons.undo2,
                        variant: AppButtonVariant.outline,
                        size: AppButtonSize.sm,
                        fullWidth: false,
                        onPressed: _undoShuffle,
                      ),
                      const SizedBox(width: 8),
                    ],
                    AppButton(
                      label: '자동 셔플',
                      icon: LucideIcons.shuffle,
                      variant: AppButtonVariant.outline,
                      size: AppButtonSize.sm,
                      fullWidth: false,
                      onPressed: teams.isEmpty ? null : _shuffle,
                    ),
                  ]),
                  const SizedBox(height: 14),

                  // ── 팀당 정원 ──
                  //
                  // 정원이 팀 카드의 `N / M` 표시와 다중 추가의 `N자리 남음` 을
                  // 모두 지배하므로 팀 목록 앞에 둔다. 화면 하단에 두면 20팀을
                  // 스크롤해야 닿는다.
                  AppCard(
                    variant: AppCardVariant.surface,
                    radius: 12,
                    borderColor: divColor,
                    padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
                    child: Row(children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('팀당 정원', style: AppTextStyles.bodyBold),
                            const SizedBox(height: 2),
                            Text(capacity == 0 ? '무제한' : '$capacity명',
                                style:
                                    AppTextStyles.caption.copyWith(color: sub)),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed:
                            capacity <= 0 ? null : () => _setCapacity(capacity - 1),
                        icon: const Icon(LucideIcons.minus, size: 18),
                        tooltip: '정원 줄이기',
                      ),
                      IconButton(
                        onPressed: capacity >= 50
                            ? null
                            : () => _setCapacity(capacity + 1),
                        icon: const Icon(LucideIcons.plus, size: 18),
                        tooltip: '정원 늘리기',
                      ),
                    ]),
                  ),
                  const SizedBox(height: 14),

                  // ── 미배정 ──
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
                                style: AppTextStyles.bodySmall.copyWith(
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
                                  : () => _pickTeam(teams, p.userId, null,
                                      capacity, memberCountByTeamId),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── 팀 목록 ──
                  for (final t in teams) ...[
                    _TeamCard(
                      team: t,
                      members: [
                        for (final uid in t.memberUserIds)
                          if (byUserId[uid] != null) byUserId[uid]!,
                      ],
                      expanded: _expanded.contains(t.id),
                      onToggle: () => setState(() {
                        if (!_expanded.remove(t.id)) _expanded.add(t.id);
                      }),
                      capacity: capacity,
                      isDark: isDark,
                      divColor: divColor,
                      sub: sub,
                      onRename: () => _editTeam(t),
                      onRecolor: () => _editTeamColor(t),
                      onDelete: () => _deleteTeam(t),
                      onTapMember: (uid) => _pickTeam(
                          teams, uid, t.id, capacity, memberCountByTeamId),
                      onAddMembers: () =>
                          _addMembers(t, teams, participants, capacity),
                    ),
                    const SizedBox(height: 12),
                  ],

                  AppButton(
                    label: '팀 추가',
                    icon: LucideIcons.plus,
                    variant: AppButtonVariant.outline,
                    onPressed: () => _createTeam(teams),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// 정원을 현재 인원보다 작게 줄여도 멤버를 강제로 빼지 않는다.
  /// 그 팀은 "6 / 5" 로 표시되고 신규 진입만 막힌다.
  ///
  /// 화면에는 즉시 반영하고(_capacityDraft), 저장은 직렬화해서 **마지막 값만**
  /// 보낸다. 연속 탭마다 왕복을 걸면 탭이 유실되고 호출이 낭비된다.
  void _setCapacity(int next) {
    final clamped = next < 0 ? 0 : (next > 50 ? 50 : next);
    setState(() => _capacityDraft = clamped);
    _flushCapacity();
  }

  Future<void> _flushCapacity() async {
    if (_savingCapacity) return; // 진행 중이면 끝날 때 최신값으로 다시 돈다
    _savingCapacity = true;
    try {
      while (true) {
        final target = _capacityDraft;
        if (target == null) break;
        await ref
            .read(leagueRepositoryProvider)
            .updateLeague(id: leagueId, teamCapacity: target);
        // 저장하는 동안 더 눌렀으면 그 값으로 한 번 더 돈다.
        if (_capacityDraft != target) continue;
        if (!mounted) return;
        // 서버가 받은 값과 draft 가 같아졌으니 draft 를 비우고 서버 값을 쓴다.
        setState(() => _capacityDraft = null);
        ref.invalidate(leagueDetailProvider(leagueId));
        break;
      }
    } catch (e) {
      if (mounted) {
        setState(() => _capacityDraft = null);
        AppSnackBar.error(context, _message(e));
      }
      ref.invalidate(leagueDetailProvider(leagueId));
    } finally {
      _savingCapacity = false;
    }
  }

  Future<void> _shuffle() async {
    final ok = await showConfirmDialog(
      context,
      title: '자동 셔플',
      content: '승인된 참가자를 팀에 균등하게 다시 배정합니다.\n\n'
          '현재 배정은 모두 덮어씌워집니다. 되돌리기로 복구할 수 있습니다.',
      confirmText: '셔플',
    );
    if (!ok || !mounted) return;
    try {
      final snapshot =
          await ref.read(leagueRepositoryProvider).shuffleLeagueTeams(leagueId);
      if (!mounted) return;
      setState(() => _undoSnapshot = snapshot);
      _refreshTeams();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${snapshot.length}명을 다시 배정했습니다'),
        action: SnackBarAction(label: '되돌리기', onPressed: _undoShuffle),
        duration: const Duration(seconds: 6),
      ));
    } catch (e) {
      if (mounted) AppSnackBar.error(context, _message(e));
    }
  }

  /// 스냅샷을 그대로 되돌린다. 스냅샷이 가리키는 팀이 삭제됐거나 참가자가
  /// 탈퇴했으면 다시는 성공할 수 없으므로 폐기해 버튼을 없앤다.
  Future<void> _undoShuffle() async {
    final snapshot = _undoSnapshot;
    if (snapshot == null) return;
    try {
      await ref.read(leagueRepositoryProvider).assignLeagueTeams(
            leagueId: leagueId,
            assignments: snapshot,
          );
      if (mounted) setState(() => _undoSnapshot = null);
      _refreshTeams();
      if (mounted) AppSnackBar.success(context, '셔플 전으로 되돌렸습니다.');
    } catch (e) {
      if (shouldDropSnapshot(e) && mounted) {
        setState(() => _undoSnapshot = null);
      }
      // 되돌리기는 팀을 고르는 동작이 아니므로 일반 TEAM_FULL 문구
      // ("다른 팀을 골라주세요")는 따를 수 없는 지시가 된다.
      if (mounted) {
        AppSnackBar.error(context, undoFailureMessage(e) ?? _message(e));
      }
    }
  }

  /// 팀에 여러 명을 한 번에 넣는다. 확인 시 RPC 1회.
  ///
  /// 후보는 이 팀의 현재 멤버를 뺀 전원이다 (미배정 + 다른 팀 소속).
  /// 다른 팀 소속도 검색으로 찾아 옮길 수 있어야 한다.
  Future<void> _addMembers(
    LeagueTeam team,
    List<LeagueTeam> teams,
    List<LeagueRankEntry> participants,
    int capacity,
  ) async {
    final nameByUserId = <String, String>{};
    final teamIdByUserId = <String, String?>{
      for (final p in participants) p.userId: null,
    };
    for (final t in teams) {
      for (final uid in t.memberUserIds) {
        nameByUserId[uid] = t.name;
        teamIdByUserId[uid] = t.id;
      }
    }
    // 멤버 수는 카드 표시와 같은 기준(순위에 있는 승인 참가자)으로 센다.
    final mine = team.memberUserIds
        .where((uid) => teamIdByUserId.containsKey(uid))
        .toSet();

    final picked = await showTeamMemberAddSheet(
      context: context,
      team: team,
      participants: participants,
      teamIdByUserId: teamIdByUserId,
      teamNameByUserId: nameByUserId,
      remaining: remainingSlots(capacity: capacity, memberCount: mine.length),
      isDark: context.isDark,
    );
    if (picked == null || picked.isEmpty || !mounted) return;

    try {
      await ref.read(leagueRepositoryProvider).assignLeagueTeams(
            leagueId: leagueId,
            assignments: [
              for (final uid in picked)
                TeamAssignment(userId: uid, teamId: team.id),
            ],
          );
      _refreshTeams();
      if (mounted) {
        AppSnackBar.success(context, '${picked.length}명을 ${team.name}에 넣었습니다.');
      }
    } catch (e) {
      if (mounted) AppSnackBar.error(context, _message(e));
    }
  }

  Future<void> _createTeam(List<LeagueTeam> teams) async {
    final name = await _promptName(title: '팀 추가', initial: '');
    if (name == null || !mounted) return;
    try {
      await ref.read(leagueRepositoryProvider).createLeagueTeam(
            leagueId: leagueId,
            name: name,
            color: AppColors.nextUnusedTeamColorKey(teams.map((t) => t.color)),
            sortOrder: nextTeamSortOrder(teams),
          );
      _refreshTeams();
    } catch (e) {
      if (mounted) AppSnackBar.error(context, _message(e));
    }
  }

  Future<void> _editTeam(LeagueTeam t) async {
    final name = await _promptName(title: '팀 이름 변경', initial: t.name);
    if (name == null || !mounted) return;
    try {
      await ref
          .read(leagueRepositoryProvider)
          .updateLeagueTeam(teamId: t.id, name: name);
      _refreshTeams();
    } catch (e) {
      if (mounted) AppSnackBar.error(context, _message(e));
    }
  }

  /// 팀 색 변경. 색은 팀 탭·개인 탭 배지의 식별 수단이라 겹쳤을 때
  /// 호스트가 직접 고칠 수 있어야 한다.
  Future<void> _editTeamColor(LeagueTeam t) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('팀 색 변경', style: AppTextStyles.heading4),
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
    if (picked == null || !mounted || picked == t.color) return;
    try {
      await ref
          .read(leagueRepositoryProvider)
          .updateLeagueTeam(teamId: t.id, color: picked);
      _refreshTeams();
    } catch (e) {
      if (mounted) AppSnackBar.error(context, _message(e));
    }
  }

  Future<void> _deleteTeam(LeagueTeam t) async {
    final ok = await showConfirmDialog(
      context,
      title: '팀 삭제',
      content: '${t.name} 을(를) 삭제합니다.\n\n'
          '팀원들은 미배정으로 돌아가고, 등록된 조과는 그대로 유지됩니다.',
      confirmText: '삭제',
      confirmColor: AppColors.error,
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(leagueRepositoryProvider).deleteLeagueTeam(t.id);
      // 삭제한 팀이 스냅샷에 들어 있으면 되돌리기가 영구히 실패한다.
      // 누르기 전에 미리 폐기해 쓸모없는 버튼을 남기지 않는다.
      if ((_undoSnapshot?.any((a) => a.teamId == t.id) ?? false) && mounted) {
        setState(() => _undoSnapshot = null);
      }
      _refreshTeams();
    } catch (e) {
      if (mounted) AppSnackBar.error(context, _message(e));
    }
  }

  /// 단건 이동. 팀이 8개를 넘으면 스크롤만으로는 못 찾으므로 검색을 넣는다.
  ///
  /// 정원과 꽉 찬 상태를 **시트에서** 보여준다. 안 보여주면 호스트가 이미
  /// 꽉 찬 팀을 눌러 "방금 정원이 찼습니다" 를 받는데, 시트를 열기 전부터
  /// 꽉 차 있었으므로 거짓말이고, 어느 팀에 자리가 있는지도 알 수 없다.
  Future<void> _pickTeam(
    List<LeagueTeam> teams,
    String userId,
    String? currentTeamId,
    int capacity,
    Map<String, int> memberCountByTeamId,
  ) async {
    final ctrl = TextEditingController();
    final picked = await showModalBottomSheet<_TeamPick>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(
          child: StatefulBuilder(
            builder: (ctx, setSheetState) {
              final q = ctrl.text.trim().toLowerCase();
              final shown = q.isEmpty
                  ? teams
                  : teams
                      .where((t) => t.name.toLowerCase().contains(q))
                      .toList(growable: false);
              return ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.8,
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('팀 선택', style: AppTextStyles.heading4),
                  ),
                  if (teams.length >= 8)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: AppTextField(
                        controller: ctrl,
                        hint: '팀 이름으로 찾기',
                        onChanged: (_) => setSheetState(() {}),
                      ),
                    ),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final t in shown)
                          _buildTeamPickRow(ctx, t, currentTeamId, capacity,
                              memberCountByTeamId[t.id] ?? 0),
                        if (shown.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: Text('검색 결과가 없습니다')),
                          ),
                        if (currentTeamId != null)
                          ListTile(
                            leading: const Icon(LucideIcons.userMinus, size: 18),
                            title: const Text('미배정으로'),
                            onTap: () =>
                                Navigator.pop(ctx, const _TeamPick(null)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ]),
              );
            },
          ),
        ),
      ),
    );
    ctrl.dispose();
    if (picked == null || !mounted) return;
    if (picked.teamId == currentTeamId) return;
    try {
      await ref.read(leagueRepositoryProvider).assignParticipantTeam(
            leagueId: leagueId,
            userId: userId,
            teamId: picked.teamId,
          );
      _refreshTeams();
    } catch (e) {
      if (mounted) AppSnackBar.error(context, _message(e));
    }
  }

  /// 단건 이동 시트의 팀 한 줄. 꽉 찬 팀은 탭할 수 없다.
  Widget _buildTeamPickRow(
    BuildContext ctx,
    LeagueTeam t,
    String? currentTeamId,
    int capacity,
    int memberCount,
  ) {
    final isCurrent = t.id == currentTeamId;
    final pickable = canPickTeam(
      isCurrentTeam: isCurrent,
      capacity: capacity,
      memberCount: memberCount,
    );
    final over = isOverCapacity(capacity: capacity, memberCount: memberCount);
    final sub =
        context.isDark ? AppColors.darkTextSub : AppColors.lightTextSub;

    return Opacity(
      opacity: pickable ? 1 : 0.45,
      child: ListTile(
        enabled: pickable,
        leading: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
              color: AppColors.teamColor(t.color), shape: BoxShape.circle),
        ),
        title: Text(t.name),
        subtitle: Text(
          pickable
              ? capacityLabel(capacity: capacity, memberCount: memberCount)
              : '${capacityLabel(capacity: capacity, memberCount: memberCount)} · 정원 마감',
          style: AppTextStyles.caption.copyWith(
            color: pickable
                ? (over ? AppColors.warning : sub)
                : AppColors.warning,
            fontWeight: pickable && !over ? null : FontWeight.w700,
          ),
        ),
        trailing: isCurrent
            ? const Icon(LucideIcons.check, size: 18)
            : (pickable
                ? null
                : Icon(LucideIcons.lock, size: 16, color: sub)),
        onTap: pickable ? () => Navigator.pop(ctx, _TeamPick(t.id)) : null,
      ),
    );
  }

  Future<String?> _promptName({
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
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
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
    // UI 가 꽉 찬 팀을 미리 막으므로 TEAM_FULL 이 실제로 뜨는 경우는 경합뿐이다.
    if (s.contains('TEAM_FULL')) return '방금 정원이 찼습니다. 다른 팀을 골라주세요.';
    if (s.contains('CAPACITY_TOO_SMALL')) {
      return '정원이 너무 작습니다. 팀을 늘리거나 정원을 올려주세요.';
    }
    if (s.contains('SELF_PICK_DISABLED')) return '이 리그는 호스트가 팀을 배정합니다.';
    if (s.contains('NOT_LEAGUE_HOST')) return '호스트만 팀을 배정할 수 있습니다.';
    if (s.contains('TEAM_NOT_IN_LEAGUE')) {
      return '팀 정보가 바뀌었습니다. 새로고침 해주세요.';
    }
    if (s.contains('NOT_PARTICIPANT')) return '이 리그의 참가자가 아닙니다.';
    if (s.contains('NO_TEAMS')) return '먼저 팀을 만들어주세요.';
    if (s.contains('AUTH_REQUIRED') || s.contains('LEAGUE_NOT_FOUND')) {
      return '다시 시도해주세요.';
    }
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
    required this.expanded,
    required this.onToggle,
    required this.capacity,
    required this.isDark,
    required this.divColor,
    required this.sub,
    required this.onRename,
    required this.onRecolor,
    required this.onDelete,
    required this.onTapMember,
    required this.onAddMembers,
  });

  final LeagueTeam team;
  final List<LeagueRankEntry> members;
  final bool expanded;
  final VoidCallback onToggle;
  final int capacity;
  final bool isDark;
  final Color divColor;
  final Color sub;
  final VoidCallback onRename;
  final VoidCallback onRecolor;
  final VoidCallback onDelete;
  final void Function(String userId) onTapMember;
  final VoidCallback onAddMembers;

  @override
  Widget build(BuildContext context) {
    final over = isOverCapacity(capacity: capacity, memberCount: members.length);
    final left = remainingSlots(capacity: capacity, memberCount: members.length);
    final full = isTeamFull(capacity: capacity, memberCount: members.length);

    return AppCard(
      variant: AppCardVariant.surface,
      radius: 14,
      borderColor: divColor,
      padding: EdgeInsets.zero,
      child: Column(children: [
        InkWell(
          onTap: onToggle,
          child: Padding(
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
                        style: AppTextStyles.heading4),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    capacityLabel(
                        capacity: capacity, memberCount: members.length),
                    style: AppTextStyles.caption.copyWith(
                      color: over ? AppColors.warning : sub,
                      fontWeight: over ? FontWeight.w700 : null,
                    ),
                  ),
                ]),
              ),
              IconButton(
                onPressed: onRename,
                icon: const Icon(LucideIcons.pencil, size: 17),
                tooltip: '${team.name} 이름 변경',
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(LucideIcons.trash2,
                    size: 17, color: AppColors.error),
                tooltip: '${team.name} 삭제',
              ),
              Icon(expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                  size: 18, color: sub),
              const SizedBox(width: 6),
            ]),
          ),
        ),
        if (expanded) ...[
          Divider(height: 1, color: divColor),
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
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Row(children: [
                Text('아직 팀원이 없습니다',
                    style: AppTextStyles.caption.copyWith(color: sub)),
              ]),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: AppButton(
              label: full
                  ? '정원이 찼습니다'
                  : (left < 0 ? '팀원 추가' : '팀원 추가 · $left자리 남음'),
              icon: LucideIcons.userPlus,
              variant: AppButtonVariant.outline,
              size: AppButtonSize.sm,
              onPressed: full ? null : onAddMembers,
            ),
          ),
        ],
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
                overflow: TextOverflow.ellipsis, style: AppTextStyles.body),
          ),
          Text(trailingLabel,
              style: AppTextStyles.caption.copyWith(
                  color: trailingColor, fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          Icon(LucideIcons.chevronDown, size: 16, color: trailingColor),
        ]),
      ),
    );
  }
}
