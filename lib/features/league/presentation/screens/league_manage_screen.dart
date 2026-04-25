import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../data/league_model.dart';
import '../../data/league_repository.dart';
import 'league_detail_screen.dart';

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
    this.record,
    this.rank,
    this.isPending = false,
  });
  final String id, name, username, joinDate;
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🎣 대회가 시작되었습니다!')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('대회가 종료되었습니다. 최종 결과가 확정됩니다.')),
      );
    }
  }

  void _kickParticipant(_Participant p) async {
    try {
      await ref.read(leagueRepositoryProvider).removeParticipant(widget.leagueId, p.id);
      ref.invalidate(leagueRankingProvider(widget.leagueId));
      ref.invalidate(leagueDetailProvider(widget.leagueId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${p.name} 님이 추방되었습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('추방 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${p.name} 님의 참가 신청을 수락했습니다.')),
      );
    }
  }

  void _rejectPending(_Participant p) async {
    await ref.read(leagueRepositoryProvider)
        .removeParticipant(widget.leagueId, p.id);
    ref.invalidate(leaguePendingProvider(widget.leagueId));
    ref.invalidate(leagueDetailProvider(widget.leagueId));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${p.name} 님의 참가 신청을 거절했습니다.')),
      );
    }
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('초대 링크가 클립보드에 복사됐습니다.')),
                      );
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
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${ctrl.text} 님에게 초대장을 보냈습니다.')),
                          );
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

  void _showEditSheet(BuildContext context, League league, Color accent, bool isDark) {
    final nameCtrl = TextEditingController(text: league.title);
    final locationCtrl = TextEditingController(text: league.location);
    final prizeCtrl = TextEditingController(text: league.prizeInfo ?? '');
    final ruleCtrl = TextEditingController(text: league.rule);
    int maxParticipants = league.maxParticipants;
    int fee = league.entryFee;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollCtrl) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
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
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('대회 정보 수정',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        TextButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            await ref.read(leagueRepositoryProvider).updateLeague(
                              id: widget.leagueId,
                              title: nameCtrl.text.trim().isEmpty ? null : nameCtrl.text.trim(),
                              location: locationCtrl.text.trim().isEmpty ? null : locationCtrl.text.trim(),
                              rule: ruleCtrl.text.trim().isEmpty ? null : ruleCtrl.text.trim(),
                              prizeInfo: prizeCtrl.text.trim().isEmpty ? null : prizeCtrl.text.trim(),
                              maxParticipants: maxParticipants,
                              entryFee: fee,
                            );
                            ref.invalidate(leagueDetailProvider(widget.leagueId));
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('대회 정보가 수정되었습니다.')),
                              );
                            }
                          },
                          child: Text('저장',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800, color: accent, fontSize: 15)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              Expanded(
                child: StatefulBuilder(
                  builder: (ctx, setLocal) => ListView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    children: [
                      _EditField(label: '대회명', ctrl: nameCtrl, isDark: isDark, accent: accent),
                      const SizedBox(height: 14),
                      _EditField(label: '장소', ctrl: locationCtrl, isDark: isDark, accent: accent),
                      const SizedBox(height: 14),
                      _EditField(label: '규칙', ctrl: ruleCtrl, isDark: isDark, accent: accent),
                      const SizedBox(height: 14),
                      _EditField(label: '시상 내용', ctrl: prizeCtrl, isDark: isDark, accent: accent, maxLines: 3),
                      const SizedBox(height: 14),
                      _EditSection(
                        label: '최대 참가자',
                        child: Row(
                          children: [
                            _CounterBtn(
                              icon: Icons.remove,
                              onTap: () => setLocal(() { if (maxParticipants > 5) maxParticipants -= 5; }),
                              accent: accent,
                            ),
                            const SizedBox(width: 16),
                            Text('$maxParticipants명',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                            const SizedBox(width: 16),
                            _CounterBtn(
                              icon: Icons.add,
                              onTap: () => setLocal(() => maxParticipants += 5),
                              accent: accent,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _EditSection(
                        label: '참가비',
                        child: Row(
                          children: [
                            _CounterBtn(
                              icon: Icons.remove,
                              onTap: () => setLocal(() { if (fee >= 5000) fee -= 5000; }),
                              accent: accent,
                            ),
                            const SizedBox(width: 16),
                            Text(fee == 0 ? '무료' : '${fee ~/ 1000}천원',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                            const SizedBox(width: 16),
                            _CounterBtn(
                              icon: Icons.add,
                              onTap: () => setLocal(() => fee += 5000),
                              accent: accent,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.neonGreen : AppColors.navy;
    final sub = isDark ? const Color(0xFF666666) : const Color(0xFFAAAAAA);
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final divColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE);
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;

    final leagueAsync = ref.watch(leagueDetailProvider(widget.leagueId));
    final rankingAsync = ref.watch(leagueRankingProvider(widget.leagueId));
    final pendingAsync = ref.watch(leaguePendingProvider(widget.leagueId));

    return leagueAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('불러오기 실패: $e')),
      ),
      data: (league) {
        final status = _statusFromString(league.status);
        final participants = rankingAsync.maybeWhen(
          data: (entries) => _rankEntriesToParticipants(entries),
          orElse: () => <_Participant>[],
        );
        final pending = pendingAsync.maybeWhen(
          data: (entries) => _pendingEntriesToParticipants(entries),
          orElse: () => <_Participant>[],
        );
        final dateRange =
            '${DateFormat('yyyy.MM.dd').format(league.startTime)} ~ ${DateFormat('MM.dd').format(league.endTime)}';

        return Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
            elevation: 0,
            title: const Text('대회 관리',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            actions: [
              TextButton(
                onPressed: () => _showEditSheet(context, league, accent, isDark),
                child: Text('수정',
                    style: TextStyle(color: accent, fontWeight: FontWeight.w700, fontSize: 14)),
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
                currentParticipants: participants.length,
                isDark: isDark,
                accent: accent,
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
                        foregroundColor: accent,
                        side: BorderSide(color: accent.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: Icon(Icons.person_add_outlined, size: 18, color: accent),
                      label: Text('+ 참가자 초대',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: accent)),
                      onPressed: () => _showInviteSheet(context, accent, isDark),
                    ),
                  ),
                ),

              // ── 탭바 ───────────────────────────────────────────
              Container(
                color: isDark ? AppColors.darkBg : AppColors.lightBg,
                child: TabBar(
                  controller: _tab,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  unselectedLabelStyle:
                      const TextStyle(fontWeight: FontWeight.w400, fontSize: 13),
                  indicatorColor: accent,
                  labelColor: accent,
                  unselectedLabelColor: sub,
                  indicatorSize: TabBarIndicatorSize.tab,
                  tabs: [
                    Tab(text: '참가자 관리 (${participants.length}명)'),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('참가 신청'),
                          if (pending.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
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
                    ),
                  ],
                ),
              ),

              // ── 탭 콘텐츠 ──────────────────────────────────────
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: [
                    _ParticipantsTab(
                      participants: participants,
                      status: status,
                      isDark: isDark,
                      accent: accent,
                      sub: sub,
                      cardBg: cardBg,
                      divColor: divColor,
                      onKick: _kickParticipant,
                    ),
                    _PendingTab(
                      pending: pending,
                      isDark: isDark,
                      accent: accent,
                      sub: sub,
                      cardBg: cardBg,
                      divColor: divColor,
                      onApprove: _approvePending,
                      onReject: _rejectPending,
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
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.liveRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 22),
                label: const Text('대회 시작',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                onPressed: onStart,
              ),
            )
          else if (status == LeagueManageStatus.live)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: sub,
                  side: BorderSide(color: divColor),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.stop_rounded, size: 20),
                label: const Text('대회 종료',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                onPressed: onEnd,
              ),
            )
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
  });

  final List<_Participant> participants;
  final LeagueManageStatus status;
  final bool isDark;
  final Color accent, sub, cardBg, divColor;
  final void Function(_Participant) onKick;

  @override
  Widget build(BuildContext context) {
    if (participants.isEmpty) {
      return Center(
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
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: sub)),
            const SizedBox(height: 6),
            Text('초대 버튼을 눌러 참가자를 초대해보세요',
                style: TextStyle(fontSize: 12, color: sub.withValues(alpha: 0.7))),
          ],
        ),
      );
    }

    return ListView.separated(
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
    );
  }
}

class _ParticipantRow extends StatelessWidget {
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

  String get _rankEmoji {
    if (rank == 1) return '🥇';
    if (rank == 2) return '🥈';
    if (rank == 3) return '🥉';
    return '${rank}위';
  }

  @override
  Widget build(BuildContext context) {
    final canKick = status != LeagueManageStatus.ended;

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          // 순위 아바타
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 44, height: 44,
              color: _rankColor.withValues(alpha: 0.1),
              child: Center(
                child: rank <= 3
                    ? Text(_rankEmoji, style: const TextStyle(fontSize: 20))
                    : Text(
                        participant.name.isNotEmpty ? participant.name[0] : '?',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: accent),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(participant.name,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                participant.record != null
                    ? Text(participant.record!,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _rankColor))
                    : Text('조과 없음',
                        style: TextStyle(fontSize: 11, color: sub)),
              ],
            ),
          ),
          // 순위 칩
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _rankColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              rank <= 3 ? _rankEmoji : '$rank위',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: _rankColor),
            ),
          ),
        ],
      ),
    );

    if (!canKick) return row;

    return Dismissible(
      key: Key(participant.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red.withValues(alpha: 0.1),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_remove_outlined, color: Colors.red, size: 20),
            SizedBox(height: 4),
            Text('추방', style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
      confirmDismiss: (direction) => showConfirmDialog(
        context,
        title: '참가자 추방',
        content: '${participant.name} 님을\n대회에서 추방하시겠습니까?',
        confirmText: '추방',
        confirmColor: Colors.red,
      ),
      onDismissed: (direction) => onKick(),
      child: row,
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
  });

  final List<_Participant> pending;
  final bool isDark;
  final Color accent, sub, cardBg, divColor;
  final void Function(_Participant) onApprove;
  final void Function(_Participant) onReject;

  @override
  Widget build(BuildContext context) {
    if (pending.isEmpty) {
      return Center(
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
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: sub)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(
            children: [
              Text('${pending.length}건 대기 중',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: sub)),
              const Spacer(),
              TextButton(
                onPressed: () {
                  for (final p in List<_Participant>.from(pending)) {
                    onApprove(p);
                  }
                },
                child: Text('전체 수락',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: accent)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: pending.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: divColor),
            itemBuilder: (_, i) {
              final p = pending[i];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 44, height: 44,
                        color: accent.withValues(alpha: 0.1),
                        child: Center(
                          child: Text(
                            p.name.isNotEmpty ? p.name[0] : '?',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: accent),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w700)),
                          Text('신청 ${p.joinDate}',
                              style: TextStyle(fontSize: 11, color: sub)),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: sub,
                        side: BorderSide(color: divColor),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => onReject(p),
                      child: const Text('거절',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: isDark ? Colors.black : Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => onApprove(p),
                      child: const Text('수락',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  공통 위젯
// ─────────────────────────────────────────────────────────────────

class _EditField extends StatelessWidget {
  const _EditField({
    required this.label,
    required this.ctrl,
    required this.isDark,
    required this.accent,
    this.maxLines = 1,
  });
  final String label;
  final TextEditingController ctrl;
  final bool isDark;
  final Color accent;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF888888))),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: isDark
                      ? const Color(0xFF333333)
                      : const Color(0xFFDDDDDD)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: accent),
            ),
          ),
        ),
      ],
    );
  }
}

class _EditSection extends StatelessWidget {
  const _EditSection({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF888888))),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _CounterBtn extends StatelessWidget {
  const _CounterBtn(
      {required this.icon, required this.onTap, required this.accent});
  final IconData icon;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: accent),
      ),
    );
  }
}
