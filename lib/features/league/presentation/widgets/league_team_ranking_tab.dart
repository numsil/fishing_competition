import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../data/league_model.dart';
import '../../data/league_repository.dart';
import '../../data/team_ranking.dart';
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
  });

  final League league;
  final bool isDark;
  final Color accent;

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

    if (teams.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(LucideIcons.users, size: 48, color: sub),
            const SizedBox(height: 12),
            Text('아직 팀이 없습니다', style: TextStyle(fontSize: 14, color: sub)),
            const SizedBox(height: 6),
            Text(
              '호스트가 리그 관리 > 팀 관리에서 팀을 만들면\n팀 순위가 표시됩니다.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: sub, height: 1.5),
            ),
          ]),
        ),
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
        itemCount: rows.length,
        itemBuilder: (_, i) {
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
      variant: widget.rank == 1 ? AppCardVariant.tinted : AppCardVariant.surface,
      tintColor: AppColors.gold,
      tintAlpha: 0.06,
      borderColor:
          widget.rank == 1 ? AppColors.gold.withValues(alpha: 0.3) : divider,
      radius: 14,
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.zero,
      child: Column(children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              if (!isUnassigned) ...[
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
                      isUnassigned
                          ? '${row.memberCount}명 · 팀 점수에 반영되지 않음'
                          : '${row.memberCount}명 · ${row.totalCount}마리',
                      style: TextStyle(fontSize: 12, color: sub),
                    ),
                  ],
                ),
              ),
              if (!isUnassigned)
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
              onTap: () => context.push(
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
