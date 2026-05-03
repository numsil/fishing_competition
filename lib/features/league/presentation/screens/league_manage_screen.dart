import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/slide_to_confirm.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../data/league_model.dart';
import '../../data/league_repository.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../my_league/data/my_league_repository.dart';
import 'league_create_screen.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/extensions/theme_extensions.dart';

// ─────────────────────────────────────────────────────────────────
//  상태 enum
// ─────────────────────────────────────────────────────────────────

enum LeagueManageStatus { upcoming, live, ended }

LeagueManageStatus _statusFromString(String s) {
  switch (s) {
    case 'in_progress': return LeagueManageStatus.live;
    case 'completed':   return LeagueManageStatus.ended;
    default:            return LeagueManageStatus.upcoming;
  }
}

// ─────────────────────────────────────────────────────────────────
//  UI 참가자 모델 (표시용)
// ─────────────────────────────────────────────────────────────────

class _Participant {
  _Participant({
    required this.id,
    required this.name,
    required this.username,
    required this.joinDate,
    this.avatarUrl,
    this.record,
    this.rank,
    this.isPending = false,
  });
  final String id, name, username, joinDate;
  final String? avatarUrl;
  final String? record;
  final int? rank;
  final bool isPending;
}

List<_Participant> _rankEntriesToParticipants(List<LeagueRankEntry> entries) {
  return entries.asMap().entries.map((e) {
    final idx = e.key;
    final entry = e.value;
    final hasRecord = entry.bestLength != null && entry.bestLength! > 0;
    return _Participant(
      id: entry.userId,
      name: entry.username,
      username: entry.username,
      avatarUrl: entry.avatarUrl,
      joinDate: '-',
      record: hasRecord ? '${entry.bestLength!.toStringAsFixed(1)}cm' : null,
      rank: hasRecord ? idx + 1 : null,
    );
  }).toList();
}

List<_Participant> _pendingEntriesToParticipants(List<LeaguePendingEntry> entries) {
  return entries.map((e) => _Participant(
    id: e.userId,
    name: e.username,
    username: e.username,
    joinDate: DateFormat('MM.dd').format(e.joinedAt),
    isPending: true,
  )).toList();
}

// ─────────────────────────────────────────────────────────────────
//  메인 화면
// ─────────────────────────────────────────────────────────────────

class LeagueManageScreen extends ConsumerStatefulWidget {
  const LeagueManageScreen({super.key, required this.leagueId});
  final String leagueId;

  @override
  ConsumerState<LeagueManageScreen> createState() => _LeagueManageScreenState();
}

class _LeagueManageScreenState extends ConsumerState<LeagueManageScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  // ── DB 액션들 ──────────────────────────────────────────────────

  void _startLeague() async {
    final confirmed = await showConfirmDialog(
      context,
      title: '대회 시작',
      content: '대회를 시작하면 참가자들에게 알림이 전송되고\n순위표가 활성화됩니다.\n\n지금 시작하시겠습니까?',
      confirmText: '대회 시작',
      confirmColor: AppColors.liveRed,
    );
    if (!confirmed || !mounted) return;
    await ref.read(leagueRepositoryProvider).updateLeagueStatus(widget.leagueId, 'in_progress');
    ref.invalidate(leagueDetailProvider(widget.leagueId));
    ref.invalidate(leagueRankingProvider(widget.leagueId));
    if (mounted) {
            AppSnackBar.success(context, '🎣 대회가 시작되었습니다!');
    }
  }

  void _endLeague() async {
    final confirmed = await showConfirmDialog(
      context,
      title: '대회 종료',
      content: '대회를 종료하면 더 이상 조과를 등록할 수 없고\n최종 결과가 확정됩니다.\n\n지금 종료하시겠습니까?',
      confirmText: '대회 종료',
      confirmColor: Colors.grey[700],
    );
    if (!confirmed || !mounted) return;
    await ref.read(leagueRepositoryProvider).updateLeagueStatus(widget.leagueId, 'completed');
    ref.invalidate(leagueDetailProvider(widget.leagueId));
    ref.invalidate(leagueRankingProvider(widget.leagueId));
    if (mounted) {
            AppSnackBar.info(context, '대회가 종료되었습니다. 최종 결과가 확정됩니다.');
    }
  }

  void _kickParticipant(_Participant p) async {
    try {
      await ref.read(leagueRepositoryProvider).removeParticipant(widget.leagueId, p.id);
      ref.invalidate(leagueRankingProvider(widget.leagueId));
      ref.invalidate(leagueDetailProvider(widget.leagueId));
      if (mounted) {
                AppSnackBar.info(context, '${p.name} 님이 추방되었습니다.');
      }
    } catch (e) {
      if (mounted) {
                AppSnackBar.error(context, '추방 실패: $e');
      }
    }
  }

  void _approvePending(_Participant p) async {
    await ref.read(leagueRepositoryProvider)
        .approveParticipant(widget.leagueId, p.id);
    ref.invalidate(leaguePendingProvider(widget.leagueId));
    ref.invalidate(leagueRankingProvider(widget.leagueId));
    ref.invalidate(leagueDetailProvider(widget.leagueId));
    if (mounted) {
            AppSnackBar.success(context, '${p.name} 님의 참가 신청을 수락했습니다.');
    }
  }

  void _rejectPending(_Participant p) async {
    await ref.read(leagueRepositoryProvider)
        .removeParticipant(widget.leagueId, p.id);
    ref.invalidate(leaguePendingProvider(widget.leagueId));
    ref.invalidate(leagueDetailProvider(widget.leagueId));
    if (mounted) {
            AppSnackBar.info(context, '${p.name} 님의 참가 신청을 거절했습니다.');
    }
  }

  void _deleteLeague(BuildContext context, League league) {
    showDeleteConfirmSheet(
      context,
      title: '리그 삭제',
      content: '"${league.title}"\n\n리그를 삭제하면 모든 참가자 데이터도 함께 삭제됩니다.',
      onConfirmed: () async {
        final navigator = Navigator.of(context);
        try {
          await ref.read(leagueRepositoryProvider).deleteLeague(league.id);
          ref.invalidate(myLeaguesProvider);
          ref.invalidate(leaguesProvider);
          if (mounted) {
                        AppSnackBar.success(context, '리그가 삭제되었습니다.');
            navigator.pop();
          }
        } catch (e) {
          if (mounted) {
                        AppSnackBar.error(context, '삭제 실패: $e');
          }
        }
      },
    );
  }

  void _showInviteSheet(BuildContext context, Color accent, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF444444) : const Color(0xFFDDDDDD),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('참가자 초대', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: accent.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.link_rounded, color: accent, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('초대 링크 공유',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: accent)),
                        const SizedBox(height: 2),
                        const Text('링크를 공유하면 누구든 참가 신청 가능',
                            style: TextStyle(fontSize: 12, color: Color(0xFF888888))),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(
                          text: 'https://huk.app/join/${widget.leagueId}'));
                      Navigator.pop(context);
                                            AppSnackBar.info(context, '초대 링크가 클립보드에 복사됐습니다.');
                    },
                    child: Text('복사', style: TextStyle(fontWeight: FontWeight.w700, color: accent)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('아이디로 초대',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF888888))),
            const SizedBox(height: 8),
            StatefulBuilder(
              builder: (ctx, setLocal) {
                final ctrl = TextEditingController();
                return Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: ctrl,
                        decoration: InputDecoration(
                          hintText: '@username 입력',
                          hintStyle: const TextStyle(color: Color(0xFF888888)),
                          prefixIcon: const Icon(Icons.person_search_rounded, size: 20),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: isDark ? const Color(0xFF333333) : const Color(0xFFDDDDDD)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: accent),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: isDark ? Colors.black : Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        if (ctrl.text.isNotEmpty) {
                          Navigator.pop(context);
                                                    AppSnackBar.success(context, '${ctrl.text} 님에게 초대장을 보냈습니다.');
                        }
                      },
                      child: const Text('초대', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final sub = context.isDark ? const Color(0xFF666666) : const Color(0xFFAAAAAA);
    final cardBg = context.isDark ? AppColors.darkSurface : Colors.white;
    final divColor = context.isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE);
    final bg = context.isDark ? AppColors.darkBg : AppColors.lightBg;

    // leagueDetailProvider만 watch — ranking/pending은 각 탭 ConsumerWidget이 담당
    final leagueAsync = ref.watch(leagueDetailProvider(widget.leagueId));

    return leagueAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('불러오기 실패: $e')),
      ),
      data: (league) {
        final status = _statusFromString(league.status);
        final dateRange =
            '${DateFormat('yyyy.MM.dd').format(league.startTime)} ~ ${DateFormat('MM.dd').format(league.endTime)}';

        return Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            backgroundColor: context.isDark ? AppColors.darkBg : AppColors.lightBg,
            elevation: 0,
            title: const Text('대회 관리',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            actions: [
              TextButton(
                onPressed: () => _deleteLeague(context, league),
                child: const Text('리그삭제',
                    style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700, fontSize: 14)),
              ),
              TextButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LeagueCreateScreen(league: league),
                    ),
                  );
                  ref.invalidate(leagueDetailProvider(widget.leagueId));
                },
                child: Text('수정',
                    style: TextStyle(color: context.accentColor, fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            ],
          ),
          body: Column(
            children: [

              // ── 대회 정보 카드 ──────────────────────────────────
              _StatusCard(
                status: status,
                name: league.title,
                location: league.location,
                dateRange: dateRange,
                fish: league.fishTypes,
                rule: league.rule,
                maxParticipants: league.maxParticipants,
                fee: league.entryFee,
                // leagueDetailProvider에서 직접 가져옴 (rankingProvider 불필요)
                currentParticipants: league.participantsCount,
                isDark: context.isDark,
                accent: context.accentColor,
                sub: sub,
                cardBg: cardBg,
                divColor: divColor,
                onStart: _startLeague,
                onEnd: _endLeague,
              ),

              // ── 참가자 초대 버튼 ────────────────────────────────
              if (status != LeagueManageStatus.ended)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.accentColor,
                        side: BorderSide(color: context.accentColor.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: Icon(Icons.person_add_outlined, size: 18, color: context.accentColor),
                      label: Text('+ 참가자 초대',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: context.accentColor)),
                      onPressed: () => _showInviteSheet(context, context.accentColor, context.isDark),
                    ),
                  ),
                ),

              // ── 탭바 ───────────────────────────────────────────
              Container(
                color: context.isDark ? AppColors.darkBg : AppColors.lightBg,
                child: TabBar(
                  controller: _tab,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  unselectedLabelStyle:
                      const TextStyle(fontWeight: FontWeight.w400, fontSize: 13),
                  indicatorColor: context.accentColor,
                  labelColor: context.accentColor,
                  unselectedLabelColor: sub,
                  indicatorSize: TabBarIndicatorSize.tab,
                  tabs: [
                    // 각 탭 라벨이 자신의 provider만 구독
                    _RankingTabLabel(leagueId: widget.leagueId),
                    _PendingTabLabel(leagueId: widget.leagueId),
                  ],
                ),
              ),

              // ── 탭 콘텐츠 ──────────────────────────────────────
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: [
                    // 참가자 탭: leagueRankingProvider만 구독
                    _RankingTabBody(
                      leagueId: widget.leagueId,
                      status: status,
                      isDark: context.isDark,
                      accent: context.accentColor,
                      sub: sub,
                      cardBg: cardBg,
                      divColor: divColor,
                      onKick: _kickParticipant,
                      onRefresh: () async {
                        ref.invalidate(leagueRankingProvider(widget.leagueId));
                        ref.invalidate(leagueDetailProvider(widget.leagueId));
                      },
                    ),
                    // 대기 탭: leaguePendingProvider만 구독
                    _PendingTabBody(
                      leagueId: widget.leagueId,
                      isDark: context.isDark,
                      accent: context.accentColor,
                      sub: sub,
                      cardBg: cardBg,
                      divColor: divColor,
                      onApprove: _approvePending,
                      onReject: _rejectPending,
                      onRefresh: () async {
                        ref.invalidate(leaguePendingProvider(widget.leagueId));
                        ref.invalidate(leagueDetailProvider(widget.leagueId));
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  탭 라벨 ConsumerWidget — leagueRankingProvider 전용
// ─────────────────────────────────────────────────────────────────

class _RankingTabLabel extends ConsumerWidget {
  const _RankingTabLabel({required this.leagueId});
  final String leagueId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(leagueRankingProvider(leagueId)).maybeWhen(
      data: (entries) => entries.length,
      orElse: () => 0,
    );
    return Tab(text: '참가자 관리 ($count명)');
  }
}

// ─────────────────────────────────────────────────────────────────
//  탭 라벨 ConsumerWidget — leaguePendingProvider 전용
// ─────────────────────────────────────────────────────────────────

class _PendingTabLabel extends ConsumerWidget {
  const _PendingTabLabel({required this.leagueId});
  final String leagueId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(leaguePendingProvider(leagueId)).maybeWhen(
      data: (entries) => entries,
      orElse: () => <LeaguePendingEntry>[],
    );
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('참가 신청'),
          if (pending.isNotEmpty) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.liveRed,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${pending.length}',
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  탭 바디 ConsumerWidget — leagueRankingProvider 전용
// ─────────────────────────────────────────────────────────────────

class _RankingTabBody extends ConsumerWidget {
  const _RankingTabBody({
    required this.leagueId,
    required this.status,
    required this.isDark,
    required this.accent,
    required this.sub,
    required this.cardBg,
    required this.divColor,
    required this.onKick,
    required this.onRefresh,
  });
  final String leagueId;
  final LeagueManageStatus status;
  final bool isDark;
  final Color accent, sub, cardBg, divColor;
  final void Function(_Participant) onKick;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final participants = ref.watch(leagueRankingProvider(leagueId)).maybeWhen(
      data: (entries) => _rankEntriesToParticipants(entries),
      orElse: () => <_Participant>[],
    );
    return _ParticipantsTab(
      participants: participants,
      status: status,
      isDark: isDark,
      accent: accent,
      sub: sub,
      cardBg: cardBg,
      divColor: divColor,
      onKick: onKick,
      onRefresh: onRefresh,
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  탭 바디 ConsumerWidget — leaguePendingProvider 전용
// ─────────────────────────────────────────────────────────────────

class _PendingTabBody extends ConsumerWidget {
  const _PendingTabBody({
    required this.leagueId,
    required this.isDark,
    required this.accent,
    required this.sub,
    required this.cardBg,
    required this.divColor,
    required this.onApprove,
    required this.onReject,
    required this.onRefresh,
  });
  final String leagueId;
  final bool isDark;
  final Color accent, sub, cardBg, divColor;
  final void Function(_Participant) onApprove;
  final void Function(_Participant) onReject;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(leaguePendingProvider(leagueId)).maybeWhen(
      data: (entries) => _pendingEntriesToParticipants(entries),
      orElse: () => <_Participant>[],
    );
    return _PendingTab(
      pending: pending,
      isDark: isDark,
      accent: accent,
      sub: sub,
      cardBg: cardBg,
      divColor: divColor,
      onApprove: onApprove,
      onReject: onReject,
      onRefresh: onRefresh,
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  대회 상태 카드
// ─────────────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.status,
    required this.name,
    required this.location,
    required this.dateRange,
    required this.fish,
    required this.rule,
    required this.maxParticipants,
    required this.fee,
    required this.currentParticipants,
    required this.isDark,
    required this.accent,
    required this.sub,
    required this.cardBg,
    required this.divColor,
    required this.onStart,
    required this.onEnd,
  });

  final LeagueManageStatus status;
  final String name, location, dateRange, fish, rule;
  final int maxParticipants, fee, currentParticipants;
  final bool isDark;
  final Color accent, sub, cardBg, divColor;
  final VoidCallback onStart, onEnd;

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor) = switch (status) {
      LeagueManageStatus.upcoming => ('진행 예정', accent),
      LeagueManageStatus.live     => ('진행중', AppColors.liveRed),
      LeagueManageStatus.ended    => ('종료', sub),
    };

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: status == LeagueManageStatus.live
              ? AppColors.liveRed.withValues(alpha: 0.35)
              : divColor,
          width: status == LeagueManageStatus.live ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // 상태 뱃지 + 대회명
          Row(
            children: [
              _StatusBadge(label: statusLabel, color: statusColor,
                  showDot: status == LeagueManageStatus.live),
              const SizedBox(width: 10),
              Expanded(
                child: Text(name,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // 장소 + 날짜
          Text('$location  ·  $dateRange',
              style: TextStyle(fontSize: 11, color: sub),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 14),

          // 정보 칩 3개
          Row(
            children: [
              _InfoChip(
                icon: Icons.people_outline_rounded,
                label: '$currentParticipants/$maxParticipants명',
                accent: accent,
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _InfoChip(
                icon: Icons.set_meal_rounded,
                label: fish,
                accent: accent,
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _InfoChip(
                icon: Icons.payments_outlined,
                label: fee == 0 ? '무료' : '${fee ~/ 1000}천원',
                accent: accent,
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 액션 버튼
          if (status == LeagueManageStatus.upcoming)
            _StartButton(onPressed: onStart)
          else if (status == LeagueManageStatus.live)
            _EndButton(onPressed: onEnd, sub: sub, divColor: divColor)
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text('대회가 종료되었습니다',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: sub)),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.color,
    required this.showDot,
  });
  final String label;
  final Color color;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 6, height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: color)),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.accent,
    required this.isDark,
  });
  final IconData icon;
  final String label;
  final Color accent;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: accent),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: accent)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  참가자 관리 탭
// ─────────────────────────────────────────────────────────────────

class _ParticipantsTab extends StatelessWidget {
  const _ParticipantsTab({
    required this.participants,
    required this.status,
    required this.isDark,
    required this.accent,
    required this.sub,
    required this.cardBg,
    required this.divColor,
    required this.onKick,
    required this.onRefresh,
  });

  final List<_Participant> participants;
  final LeagueManageStatus status;
  final bool isDark;
  final Color accent, sub, cardBg, divColor;
  final void Function(_Participant) onKick;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (participants.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      color: sub.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.group_outlined, size: 36, color: sub),
                  ),
                  const SizedBox(height: 16),
                  Text('참가자가 없습니다',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: sub)),
                  const SizedBox(height: 6),
                  Text('초대 버튼을 눌러 참가자를 초대해보세요',
                      style: TextStyle(fontSize: 12, color: sub.withValues(alpha: 0.7))),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: participants.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: divColor),
      itemBuilder: (_, i) {
        final p = participants[i];
        return _ParticipantRow(
          participant: p,
          rank: i + 1,
          status: status,
          isDark: isDark,
          accent: accent,
          sub: sub,
          onKick: () => onKick(p),
        );
      },
      ),
    );
  }
}

class _ParticipantRow extends ConsumerWidget {
  const _ParticipantRow({
    required this.participant,
    required this.rank,
    required this.status,
    required this.isDark,
    required this.accent,
    required this.sub,
    required this.onKick,
  });

  final _Participant participant;
  final int rank;
  final LeagueManageStatus status;
  final bool isDark;
  final Color accent, sub;
  final VoidCallback onKick;

  Color get _rankColor {
    if (rank == 1) return AppColors.gold;
    if (rank == 2) return AppColors.silver;
    if (rank == 3) return AppColors.bronze;
    return accent;
  }

  String get _rankLabel {
    if (rank == 1) return '1위';
    if (rank == 2) return '2위';
    if (rank == 3) return '3위';
    return '$rank위';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canKick = status != LeagueManageStatus.ended;
    final currentUserId = ref.watch(currentUserProvider)?.id;
    final isMe = currentUserId == participant.id;

    return InkWell(
      onTap: isMe ? null : () => context.push('/user/${participant.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            // 프로필 아바타
            Stack(
              clipBehavior: Clip.none,
              children: [
                UserAvatar(
                  username: participant.name,
                  avatarUrl: participant.avatarUrl,
                  radius: 22,
                  isDark: isDark,
                ),
                if (status != LeagueManageStatus.upcoming && rank <= 3)
                  Positioned(
                    bottom: -4, right: -4,
                    child: Container(
                      width: 18, height: 18,
                      decoration: BoxDecoration(
                        color: _rankColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? AppColors.darkBg : Colors.white,
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$rank',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(participant.name,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                      if (isMe) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('나', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: accent)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  if (status == LeagueManageStatus.upcoming)
                    Text('참가 신청', style: TextStyle(fontSize: 11, color: sub))
                  else if (participant.record != null)
                    Text(participant.record!,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _rankColor))
                  else
                    Text('조과 없음', style: TextStyle(fontSize: 11, color: sub)),
                ],
              ),
            ),
            // 순위 칩 (모집중엔 숨김)
            if (status != LeagueManageStatus.upcoming)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _rankColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _rankLabel,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _rankColor),
                ),
              ),
            if (canKick && !isMe) ...[
              const SizedBox(width: 4),
              IconButton(
                onPressed: () => showDeleteConfirmSheet(
                  context,
                  title: '참가자 추방',
                  content: '${participant.name} 님을\n대회에서 추방하시겠습니까?',
                  slideLabel: '밀어서 추방',
                  onConfirmed: onKick,
                ),
                icon: const Icon(Icons.person_remove_outlined, size: 20),
                color: Colors.red.withValues(alpha: 0.6),
                tooltip: '추방',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  참가 신청 탭
// ─────────────────────────────────────────────────────────────────

class _PendingTab extends StatelessWidget {
  const _PendingTab({
    required this.pending,
    required this.isDark,
    required this.accent,
    required this.sub,
    required this.cardBg,
    required this.divColor,
    required this.onApprove,
    required this.onReject,
    required this.onRefresh,
  });

  final List<_Participant> pending;
  final bool isDark;
  final Color accent, sub, cardBg, divColor;
  final void Function(_Participant) onApprove;
  final void Function(_Participant) onReject;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (pending.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      color: sub.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.inbox_outlined, size: 36, color: sub),
                  ),
                  const SizedBox(height: 16),
                  Text('대기 중인 참가 신청이 없습니다',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: sub)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: pending.length + 1,
        separatorBuilder: (_, i) => i == 0 ? const SizedBox.shrink() : Divider(height: 1, color: divColor),
        itemBuilder: (_, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(
                children: [
                  Text('${pending.length}건 대기 중',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: sub)),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      for (final p in List<_Participant>.from(pending)) {
                        onApprove(p);
                      }
                    },
                    child: Text('전체 수락',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: accent)),
                  ),
                ],
              ),
            );
          }
          final p = pending[i - 1];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => context.push('/user/${p.id}'),
                  child: UserAvatar(
                    username: p.name,
                    avatarUrl: p.avatarUrl,
                    radius: 22,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      Text('신청 ${p.joinDate}', style: TextStyle(fontSize: 11, color: sub)),
                    ],
                  ),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: sub,
                    side: BorderSide(color: divColor),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => onReject(p),
                  child: const Text('거절', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => onApprove(p),
                  child: const Text('수락', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── 대회 시작 버튼 ────────────────────────────────────────
class _StartButton extends StatelessWidget {
  const _StartButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFF3B30), Color(0xFFFF6B35)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: InkWell(
          onTap: onPressed,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.play, size: 14, color: Colors.white),
                ),
                const SizedBox(width: 10),
                const Text(
                  '대회 시작하기',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── 대회 종료 버튼 ────────────────────────────────────────
class _EndButton extends StatelessWidget {
  const _EndButton({required this.onPressed, required this.sub, required this.divColor});
  final VoidCallback onPressed;
  final Color sub;
  final Color divColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: sub,
          side: BorderSide(color: divColor),
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.x, size: 16, color: sub),
            const SizedBox(width: 8),
            Text('대회 종료',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: sub,
                )),
          ],
        ),
      ),
    );
  }
}
