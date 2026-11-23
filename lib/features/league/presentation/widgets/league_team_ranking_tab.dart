import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../data/league_model.dart';
import '../../data/league_repository.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/data/auth_repository.dart';
import '../../data/league_team_model.dart';
import '../../../../core/router/app_router.dart';
import '../../data/team_capacity.dart';
import '../../data/team_ranking.dart';
import 'league_my_team_banner.dart';
import '../screens/league_participant_detail_screen.dart';

/// 팀 순위 탭.
///
/// 집계용 RPC 를 새로 만들지 않는다. 개인 탭이 이미 쓰는
/// leagueRankingProvider 결과를 leagueTeamsProvider 의 팀 명단과 합쳐
/// buildTeamRanking 이 묶는다.
class LeagueTeamRankingTab extends ConsumerWidget {
  const LeagueTeamRankingTab({
    super.key,
    required this.league,
    required this.isDark,
    required this.accent,
    this.preStart = false,
  });

  final League league;
  final bool isDark;
  final Color accent;

  /// 모집중 리그인가. 조과가 없으므로 순위·기록 대신 `인원 / 정원` 만 보여준다.
  final bool preStart;

  /// 팀 카드를 전부 펼쳐 둘 임계값. 이 수 이상이면 1위만 펼친다.
  static const int _expandAllThreshold = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sub = isDark ? AppColors.darkTextSub : AppColors.lightTextSub;
    final teamsAsync = ref.watch(leagueTeamsProvider(league.id));
    final rankingAsync = ref.watch(leagueRankingProvider(league.id));

    if (teamsAsync.isLoading || rankingAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (teamsAsync.hasError) {
      return Center(child: Text('팀 정보를 불러오지 못했습니다: ${teamsAsync.error}'));
    }
    if (rankingAsync.hasError) {
      return Center(child: Text('순위를 불러오지 못했습니다: ${rankingAsync.error}'));
    }

    final teams = teamsAsync.requireValue;
    final ranking = rankingAsync.requireValue;

    // 자율 선택 리그에서 본인이 승인 참가자일 때만 내 팀 배너를 그린다.
    // 호스트 배정 리그에 그리면 누를 수 없는 버튼을 보여주는 셈이다.
    final myUserId = ref.watch(currentUserProvider)?.id;
    final isApproved =
        myUserId != null && ranking.any((e) => e.userId == myUserId);
    // 모집중에 신청만 해둔 사람에게도 배너를 보여준다 (고르지는 못한다).
    // 이 provider 는 리그 상세가 이미 watch 하므로 추가 조회가 없다.
    final isPending =
        ref.watch(myParticipantStatusProvider(league.id)).valueOrNull ==
            'pending';
    final showBanner = shouldShowMyTeamBanner(
      isSelfPick: league.isSelfPick,
      isApprovedParticipant: isApproved,
      isPendingParticipant: isPending,
    );
    LeagueTeam? myTeam;
    if (showBanner && myUserId != null) {
      for (final t in teams) {
        if (t.memberUserIds.contains(myUserId)) {
          myTeam = t;
          break;
        }
      }
    }
    final banner = showBanner
        ? LeagueMyTeamBanner(
            leagueId: league.id,
            myTeam: myTeam,
            hasAnyTeam: teams.isNotEmpty,
            canPick: isApproved,
          )
        : null;

    if (teams.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          if (banner != null) banner,
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(LucideIcons.users, size: 48, color: sub),
              const SizedBox(height: 12),
              Text('아직 팀이 없습니다',
                  style: AppTextStyles.body.copyWith(color: sub)),
              const SizedBox(height: 6),
              Text(
                preStart
                    ? '호스트가 팀을 만들면 여기서 팀을 고를 수 있습니다.'
                    : '호스트가 리그 관리 > 팀 관리에서 팀을 만들면\n팀 순위가 표시됩니다.',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(color: sub, height: 1.5),
              ),
            ]),
          ),
        ],
      );
    }

    final rows = buildTeamRanking(
      ranking: ranking,
      teams: teams,
      rule: league.rule,
    );
    // 참가자 상세 화면이 rank 를 아바타 배지에 그대로 찍으므로
    // 실제 개인 순위를 넘긴다 (0 을 넘기면 "0" 배지가 보인다).
    final rankByUser = rankByUserId(ranking);
    final expandAll = teams.length < _expandAllThreshold;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(leagueTeamsProvider(league.id));
        ref.invalidate(leagueRankingProvider(league.id));
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: rows.length + (banner != null ? 1 : 0),
        itemBuilder: (_, i) {
          if (banner != null) {
            if (i == 0) return banner;
            i -= 1;
          }
          final row = rows[i];
          return _TeamRankCard(
            // 미배정 그룹은 순위를 받지 않는다 (0)
            rank: row.isUnassigned ? 0 : i + 1,
            row: row,
            leagueId: league.id,
            rule: league.rule,
            catchLimit: league.catchLimit,
            isDark: isDark,
            accent: accent,
            rankByUserId: rankByUser,
            initiallyExpanded: row.isUnassigned || expandAll || i == 0,
            preStart: preStart,
            capacity: league.teamCapacity,
          );
        },
      ),
    );
  }
}

class _TeamRankCard extends StatefulWidget {
  const _TeamRankCard({
    required this.rank,
    required this.row,
    required this.leagueId,
    required this.rule,
    required this.catchLimit,
    required this.isDark,
    required this.accent,
    required this.rankByUserId,
    required this.initiallyExpanded,
    required this.preStart,
    required this.capacity,
  });

  final int rank; // 0 = 미배정
  final LeagueTeamRank row;
  final String leagueId;
  final String rule;
  final int catchLimit;
  final bool isDark;
  final Color accent;

  /// user_id → 개인 순위. 참가자 상세 화면의 순위 배지에 쓰인다.
  final Map<String, int> rankByUserId;
  final bool initiallyExpanded;

  /// 모집중 모드. 순위 번호·팀 점수·개인 기록을 모두 숨긴다.
  final bool preStart;

  /// 팀당 정원. 0 이면 무제한. 모집중 부제목에 `3 / 5` 로 쓴다.
  final int capacity;

  @override
  State<_TeamRankCard> createState() => _TeamRankCardState();
}

class _TeamRankCardState extends State<_TeamRankCard> {
  late bool _expanded = widget.initiallyExpanded;

  String get _mainValue {
    if (widget.rule == '마릿수') return '${widget.row.totalCount}마리';
    if (widget.rule == '무게') {
      return widget.row.totalMeasure > 0
          ? '${widget.row.totalMeasure.toStringAsFixed(0)}g'
          : '-';
    }
    return widget.row.totalMeasure > 0
        ? '${widget.row.totalMeasure.toStringAsFixed(1)}cm'
        : '-';
  }

  String _memberValue(LeagueRankEntry e) {
    if (widget.rule == '마릿수') return '${e.totalCount}마리';
    if (widget.rule == '무게') {
      return e.totalLength > 0 ? '${e.totalLength.toStringAsFixed(0)}g' : '0g';
    }
    if (widget.catchLimit == 1) {
      return e.bestLength != null
          ? '${e.bestLength!.toStringAsFixed(1)}cm'
          : '0.0cm';
    }
    return '${e.totalLength.toStringAsFixed(1)}cm';
  }

  /// 카드 부제목. 모집중에는 기록이 없으므로 정원 소진 상황만 보여준다.
  String _subtitle() {
    final row = widget.row;
    if (row.isUnassigned) {
      return widget.preStart
          ? '${row.memberCount}명 · 아직 팀을 고르지 않음'
          : '${row.memberCount}명 · 팀 점수에 반영되지 않음';
    }
    if (widget.preStart) {
      final label =
          capacityLabel(capacity: widget.capacity, memberCount: row.memberCount);
      return isTeamFull(capacity: widget.capacity, memberCount: row.memberCount)
          ? '$label · 정원 마감'
          : label;
    }
    return '${row.memberCount}명 · ${row.totalCount}마리';
  }

  Color get _rankColor {
    if (widget.rank == 1) return AppColors.gold;
    if (widget.rank == 2) return AppColors.silver;
    if (widget.rank == 3) return AppColors.bronze;
    return widget.isDark ? AppColors.darkTextSub : AppColors.lightTextSub;
  }

  @override
  Widget build(BuildContext context) {
    final sub = widget.isDark ? AppColors.darkTextSub : AppColors.lightTextSub;
    final text = widget.isDark ? AppColors.darkText : AppColors.lightText;
    final divider =
        widget.isDark ? AppColors.darkDivider : AppColors.lightDivider;
    final row = widget.row;
    final isUnassigned = row.isUnassigned;
    final teamColor = isUnassigned ? sub : AppColors.teamColor(row.team!.color);

    return AppCard(
      variant: (widget.rank == 1 && !widget.preStart)
          ? AppCardVariant.tinted
          : AppCardVariant.surface,
      tintColor: AppColors.gold,
      tintAlpha: 0.06,
      borderColor: (widget.rank == 1 && !widget.preStart)
          ? AppColors.gold.withValues(alpha: 0.3)
          : divider,
      radius: 14,
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.zero,
      child: Column(children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              if (!isUnassigned && !widget.preStart) ...[
                SizedBox(
                  width: 24,
                  child: Text(
                    '${widget.rank}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: _rankColor),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Container(
                width: 10,
                height: 10,
                decoration:
                    BoxDecoration(color: teamColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isUnassigned ? '미배정' : row.team!.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subtitle(),
                      style: TextStyle(fontSize: 12, color: sub),
                    ),
                  ],
                ),
              ),
              if (!isUnassigned && !widget.preStart)
                Text(
                  _mainValue,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: widget.rank == 1 ? AppColors.gold : widget.accent,
                  ),
                ),
              const SizedBox(width: 4),
              Icon(_expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                  size: 18, color: sub),
            ]),
          ),
        ),
        if (_expanded && row.members.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Row(children: [
              Text('아직 팀원이 없습니다',
                  style: TextStyle(fontSize: 12, color: sub)),
            ]),
          ),
        if (_expanded && row.members.isNotEmpty) ...[
          Divider(height: 1, color: divider),
          for (final m in row.members)
            InkWell(
              onTap: () => widget.preStart
                  ? context.push('${AppRoutes.userProfile}/${m.userId}')
                  : context.push(
                      '/league/participant/${widget.leagueId}/${m.userId}',
                      extra: LeagueParticipantArgs(
                        entry: m,
                        rule: widget.rule,
                        catchLimit: widget.catchLimit,
                        rank: widget.rankByUserId[m.userId] ?? 0,
                      ),
                    ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(children: [
                  UserAvatar(
                      username: m.username,
                      avatarUrl: m.avatarUrl,
                      radius: 14,
                      isDark: widget.isDark),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      m.username,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: m.totalCount > 0
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: m.totalCount > 0 ? text : sub,
                      ),
                    ),
                  ),
                  if (!widget.preStart) ...[
                    Text('${m.totalCount}마리',
                        style: TextStyle(fontSize: 12, color: sub)),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 78,
                      child: Text(
                        _memberValue(m),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: m.totalCount > 0 ? text : sub,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 2),
                  Icon(LucideIcons.chevronRight, size: 16, color: sub),
                ]),
              ),
            ),
        ],
      ]),
    );
  }
}
