import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_svg.dart';

// ─────────────────────────────────────────────────────────────────
//  공통 데이터 모델
// ─────────────────────────────────────────────────────────────────
class LeagueDetailData {
  const LeagueDetailData({
    required this.id,
    required this.name,
    required this.status,
    required this.location,
    required this.dateRange,
    required this.fish,
    required this.rule,
    required this.maxParticipants,
    required this.fee,
    this.prize = '',
    this.intro = '',
    required this.leaderboard,
  });
  final String id, name, status, location, dateRange, fish, rule, prize, intro;
  final int maxParticipants, fee;
  final List<LeaderboardEntry> leaderboard;
}

class LeaderboardEntry {
  LeaderboardEntry({
    required this.rank,
    required this.user,
    required this.record,
    required this.score,
    this.isMe = false,
    this.catchTime,
  });
  int rank;
  final String user, record;
  int score;
  final bool isMe;
  final String? catchTime;
}

// ─────────────────────────────────────────────────────────────────
//  샘플 데이터
// ─────────────────────────────────────────────────────────────────
final _liveLeagueData = LeagueDetailData(
  id: 'lg001',
  name: '2026 충주호 배스 오픈',
  status: 'live',
  location: '충주호',
  dateRange: '2026.04.20 ~ 2026.04.27',
  fish: '배스',
  rule: '최대어',
  maxParticipants: 48,
  fee: 30000,
  prize: '1위 50만원 / 2위 30만원 / 3위 20만원',
  intro: '충주호 최대 배스 오픈 대회. 단독 최대어 기준으로 순위를 결정합니다.',
  leaderboard: [
    LeaderboardEntry(rank: 1, user: '박태준', record: '54.1cm', score: 541),
    LeaderboardEntry(rank: 2, user: '이서연', record: '51.2cm', score: 512),
    LeaderboardEntry(rank: 3, user: '강준혁', record: '49.8cm', score: 498),
    LeaderboardEntry(rank: 4, user: '김민준', record: '52.3cm', score: 523, isMe: true, catchTime: '10:32'),
    LeaderboardEntry(rank: 5, user: '정민호', record: '47.5cm', score: 475),
    LeaderboardEntry(rank: 6, user: '윤지후', record: '45.0cm', score: 450),
    LeaderboardEntry(rank: 7, user: '최현수', record: '43.2cm', score: 432),
    LeaderboardEntry(rank: 8, user: '한수진', record: '41.7cm', score: 417),
  ],
);

final _upcomingLeagueData = LeagueDetailData(
  id: 'lg002',
  name: '소양강 봄 챔피언십',
  status: 'upcoming',
  location: '소양강',
  dateRange: '2026.05.01 ~ 2026.05.10',
  fish: '쏘가리',
  rule: '합산 길이',
  maxParticipants: 32,
  fee: 20000,
  prize: '1위 루어 낚시대 세트 / 2위 릴 세트 / 3위 루어박스',
  intro: '소양강 봄 쏘가리 합산 대회입니다. 2일간 잡은 쏘가리 합산 길이로 순위를 결정합니다.\n\n※ 캐치앤릴리즈 필수\n※ 최소 사이즈 25cm 이상만 인정',
  leaderboard: [
    LeaderboardEntry(rank: 1, user: '김민준', record: '-', score: 0, isMe: true),
    LeaderboardEntry(rank: 2, user: '이서연', record: '-', score: 0),
    LeaderboardEntry(rank: 3, user: '박태준', record: '-', score: 0),
  ],
);

final _historyLeagueData = LeagueDetailData(
  id: 'lg_h001',
  name: '충주호 배스 리그 시즌2',
  status: 'finished',
  location: '충주호',
  dateRange: '2026.04.01 ~ 2026.04.07',
  fish: '배스',
  rule: '최대어',
  maxParticipants: 45,
  fee: 30000,
  prize: '1위 50만원 / 2위 30만원 / 3위 20만원',
  intro: '',
  leaderboard: [
    LeaderboardEntry(rank: 1, user: '김민준', record: '50.1cm', score: 501, isMe: true),
    LeaderboardEntry(rank: 2, user: '이서연', record: '48.3cm', score: 483),
    LeaderboardEntry(rank: 3, user: '박태준', record: '46.7cm', score: 467),
    LeaderboardEntry(rank: 4, user: '강준혁', record: '44.2cm', score: 442),
    LeaderboardEntry(rank: 5, user: '정민호', record: '42.9cm', score: 429),
    LeaderboardEntry(rank: 6, user: '윤지후', record: '41.5cm', score: 415),
    LeaderboardEntry(rank: 7, user: '최현수', record: '40.0cm', score: 400),
    LeaderboardEntry(rank: 8, user: '한수진', record: '38.8cm', score: 388),
    LeaderboardEntry(rank: 9, user: '오동건', record: '37.1cm', score: 371),
    LeaderboardEntry(rank: 10, user: '신지원', record: '35.5cm', score: 355),
  ],
);

// 데이터 조회
LeagueDetailData getLeagueDetail(String id, String type) {
  if (type == 'live') return _liveLeagueData;
  if (type == 'upcoming') return _upcomingLeagueData;
  return _historyLeagueData;
}

// ─────────────────────────────────────────────────────────────────
//  메인 상세 화면
// ─────────────────────────────────────────────────────────────────
class MyLeagueDetailScreen extends StatefulWidget {
  const MyLeagueDetailScreen({super.key, required this.leagueId, required this.type});
  final String leagueId;
  final String type; // 'live' | 'upcoming' | 'history'

  @override
  State<MyLeagueDetailScreen> createState() => _MyLeagueDetailScreenState();
}

class _MyLeagueDetailScreenState extends State<MyLeagueDetailScreen>
    with SingleTickerProviderStateMixin {
  late List<LeaderboardEntry> _board;
  late LeagueDetailData _data;
  int? _highlightRank;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _data = getLeagueDetail(widget.leagueId, widget.type);
    _board = List.from(_data.leaderboard);
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  // 조과 등록 후 순위 재계산
  void _submitCatch(double sizeCm) {
    final cm = sizeCm;
    final score = (cm * 10).round();
    final idx = _board.indexWhere((e) => e.isMe);
    if (idx == -1) return;

    setState(() {
      _board[idx].score = score > _board[idx].score ? score : _board[idx].score;
      // record 업데이트는 불변이므로 새 entry로 교체
      final updated = LeaderboardEntry(
        rank: _board[idx].rank,
        user: _board[idx].user,
        record: '${cm.toStringAsFixed(1)}cm',
        score: score,
        isMe: true,
        catchTime: _now(),
      );
      _board[idx] = updated;

      // 점수 기준 내림차순 정렬
      _board.sort((a, b) => b.score.compareTo(a.score));
      for (int i = 0; i < _board.length; i++) {
        _board[i].rank = i + 1;
      }
      _highlightRank = _board.indexWhere((e) => e.isMe) + 1;
    });

    _pulseCtrl.forward(from: 0);
  }

  String _now() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.neonGreen : AppColors.navy;

    return switch (widget.type) {
      'live' => _LiveLeagueScreen(
          data: _data,
          board: _board,
          highlightRank: _highlightRank,
          pulseCtrl: _pulseCtrl,
          isDark: isDark,
          accent: accent,
          onSubmitCatch: _submitCatch,
        ),
      'upcoming' => _UpcomingLeagueScreen(
          data: _data,
          isDark: isDark,
          accent: accent,
        ),
      _ => _HistoryLeagueScreen(
          data: _data,
          board: _board,
          isDark: isDark,
          accent: accent,
        ),
    };
  }
}

// ─────────────────────────────────────────────────────────────────
//  진행중 리그 화면
// ─────────────────────────────────────────────────────────────────
class _LiveLeagueScreen extends StatelessWidget {
  const _LiveLeagueScreen({
    required this.data,
    required this.board,
    required this.highlightRank,
    required this.pulseCtrl,
    required this.isDark,
    required this.accent,
    required this.onSubmitCatch,
  });
  final LeagueDetailData data;
  final List<LeaderboardEntry> board;
  final int? highlightRank;
  final AnimationController pulseCtrl;
  final bool isDark;
  final Color accent;
  final ValueChanged<double> onSubmitCatch;

  LeaderboardEntry? get _myEntry => board.where((e) => e.isMe).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final sub = isDark ? const Color(0xFF8E8E8E) : const Color(0xFF737373);
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final divColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE);
    final myEntry = _myEntry;
    final myRank = myEntry?.rank;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data.name,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Row(
              children: [
                Container(
                  width: 6, height: 6,
                  margin: const EdgeInsets.only(right: 5),
                  decoration: const BoxDecoration(
                    color: AppColors.liveRed, shape: BoxShape.circle,
                  ),
                ),
                const Text('LIVE',
                    style: TextStyle(fontSize: 10, color: AppColors.liveRed, fontWeight: FontWeight.w800)),
                const SizedBox(width: 8),
                Text(data.dateRange, style: TextStyle(fontSize: 10, color: sub)),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCameraSheet(context),
        backgroundColor: accent,
        icon: Icon(Icons.camera_alt_rounded, color: isDark ? Colors.black : Colors.white),
        label: Text(
          '조과 등록',
          style: TextStyle(fontWeight: FontWeight.w800, color: isDark ? Colors.black : Colors.white),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          // ── 내 현황 카드 ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accent.withValues(alpha: 0.4), width: 1.5),
            ),
            child: Row(
              children: [
                // 내 순위
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: _rankBg(myRank, isDark),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: myRank != null
                        ? Text(
                            '$myRank',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: _rankColor(myRank),
                            ),
                          )
                        : Text('–', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: sub)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('나의 현황', style: TextStyle(fontSize: 11, color: Color(0xFF888888))),
                      const SizedBox(height: 2),
                      Text(
                        myEntry?.record == '-' ? '아직 조과 없음' : (myEntry?.record ?? '–'),
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: accent),
                      ),
                      if (myEntry?.catchTime != null)
                        Text('${myEntry!.catchTime} 등록',
                            style: TextStyle(fontSize: 11, color: sub)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      myEntry?.score == 0 ? '–' : '${myEntry?.score}점',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: accent),
                    ),
                    Text('점수', style: TextStyle(fontSize: 10, color: sub)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── 실시간 순위표 ──
          Row(
            children: [
              Text('실시간 순위표',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.liveRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('LIVE',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.liveRed)),
              ),
              const Spacer(),
              Text('${board.length}명 참가', style: TextStyle(fontSize: 12, color: sub)),
            ],
          ),
          const SizedBox(height: 10),

          // 포디움 상위 3
          _LivePodium(board: board, isDark: isDark, accent: accent),
          const SizedBox(height: 12),

          // 4위~
          ...board.skip(3).map((e) => _LiveRankRow(
                entry: e,
                isDark: isDark,
                accent: accent,
                sub: sub,
                cardBg: cardBg,
                divColor: divColor,
                isHighlighted: highlightRank != null && e.isMe,
                pulseCtrl: pulseCtrl,
              )),
        ],
      ),
    );
  }

  void _openCameraSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CatchSubmitSheet(
        isDark: isDark,
        accent: accent,
        fish: data.fish,
        onSubmit: (cm) {
          Navigator.pop(context);
          onSubmitCatch(cm);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${cm.toStringAsFixed(1)}cm 등록 완료! 순위가 업데이트되었습니다'),
              backgroundColor: accent,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              duration: const Duration(seconds: 3),
            ),
          );
        },
      ),
    );
  }

  Color _rankColor(int? rank) {
    if (rank == 1) return AppColors.gold;
    if (rank == 2) return AppColors.silver;
    if (rank == 3) return AppColors.bronze;
    return accent;
  }

  Color _rankBg(int? rank, bool isDark) {
    if (rank == 1) return AppColors.gold.withValues(alpha: 0.15);
    if (rank == 2) return AppColors.silver.withValues(alpha: 0.15);
    if (rank == 3) return AppColors.bronze.withValues(alpha: 0.15);
    return accent.withValues(alpha: 0.1);
  }
}

// ── 실시간 포디움 ──
class _LivePodium extends StatelessWidget {
  const _LivePodium({required this.board, required this.isDark, required this.accent});
  final List<LeaderboardEntry> board;
  final bool isDark;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    if (board.length < 3) return const SizedBox.shrink();
    final top3 = board.take(3).toList();
    final order = [1, 0, 2]; // 2위, 1위, 3위
    final medals = [AppColors.silver, AppColors.gold, AppColors.bronze];
    final heights = [80.0, 100.0, 65.0];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: order.asMap().entries.map((item) {
          final pos = item.key;
          final idx = item.value;
          final e = top3[idx];
          final medal = medals[pos];
          return Expanded(
            child: Column(
              children: [
                if (e.isMe)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('나',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.black : Colors.white)),
                  ),
                Text(e.user,
                    style: TextStyle(
                        fontSize: idx == 0 ? 13 : 11, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
                Text(e.record,
                    style: TextStyle(
                        fontSize: idx == 0 ? 14 : 12,
                        fontWeight: FontWeight.w900,
                        color: medal)),
                const SizedBox(height: 6),
                Container(
                  height: heights[pos],
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: medal.withValues(alpha: isDark ? 0.15 : 0.1),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                    border: Border.all(color: medal.withValues(alpha: 0.4)),
                  ),
                  child: Center(
                    child: Text('${e.rank}위',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, color: medal, fontSize: 16)),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── 4위 이하 행 ──
class _LiveRankRow extends StatelessWidget {
  const _LiveRankRow({
    required this.entry,
    required this.isDark,
    required this.accent,
    required this.sub,
    required this.cardBg,
    required this.divColor,
    required this.isHighlighted,
    required this.pulseCtrl,
  });
  final LeaderboardEntry entry;
  final bool isDark, isHighlighted;
  final Color accent, sub, cardBg, divColor;
  final AnimationController pulseCtrl;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseCtrl,
      builder: (_, __) {
        final glow = isHighlighted && pulseCtrl.isAnimating;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: entry.isMe
                ? accent.withValues(alpha: 0.08)
                : cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: glow
                  ? accent
                  : entry.isMe
                      ? accent.withValues(alpha: 0.35)
                      : divColor,
              width: glow ? 2 : 1,
            ),
            boxShadow: glow
                ? [BoxShadow(color: accent.withValues(alpha: 0.3), blurRadius: 12)]
                : null,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 30,
                child: Text(
                  '${entry.rank}',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w700, color: sub, fontSize: 14),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(children: [
                  Text(entry.user,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  if (entry.isMe) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(4)),
                      child: Text('나',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.black : Colors.white)),
                    ),
                  ],
                ]),
              ),
              if (entry.catchTime != null)
                Text(entry.catchTime!, style: TextStyle(fontSize: 11, color: sub)),
              const SizedBox(width: 10),
              Text(
                entry.record == '-' ? '–' : entry.record,
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: entry.isMe ? accent : (isDark ? Colors.white : Colors.black),
                    fontSize: 14),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  조과 등록 바텀 시트 (카메라 + 사이즈 입력)
// ─────────────────────────────────────────────────────────────────
class _CatchSubmitSheet extends StatefulWidget {
  const _CatchSubmitSheet({
    required this.isDark,
    required this.accent,
    required this.fish,
    required this.onSubmit,
  });
  final bool isDark;
  final Color accent;
  final String fish;
  final ValueChanged<double> onSubmit;

  @override
  State<_CatchSubmitSheet> createState() => _CatchSubmitSheetState();
}

class _CatchSubmitSheetState extends State<_CatchSubmitSheet> {
  bool _photoTaken = false;
  double _size = 0.0;
  final _sizeCtrl = TextEditingController();

  @override
  void dispose() {
    _sizeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final accent = widget.accent;
    final bg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final sub = isDark ? const Color(0xFF8E8E8E) : const Color(0xFF737373);
    final divColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE);
    final canSubmit = _photoTaken && _size > 0;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF444444) : const Color(0xFFCCCCCC),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text('조과 등록',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(width: 8),
                Text(widget.fish,
                    style: TextStyle(fontSize: 14, color: accent, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: divColor),
          const SizedBox(height: 16),

          // ── 사진 영역 ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GestureDetector(
              onTap: () => setState(() => _photoTaken = true),
              child: Container(
                width: double.infinity,
                height: 180,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF2F2F2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _photoTaken ? accent : divColor,
                    width: _photoTaken ? 2 : 1,
                  ),
                ),
                child: _photoTaken
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    isDark ? const Color(0xFF1A3026) : const Color(0xFFC8E6D4),
                                    isDark ? const Color(0xFF0A1A10) : const Color(0xFFE8F5E9),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                            ),
                          ),
                          Center(
                            child: AppSvg(AppIcons.fish, size: 80,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.2)
                                    : Colors.black.withValues(alpha: 0.12)),
                          ),
                          Positioned(
                            top: 10, right: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_rounded, size: 12, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text('촬영 완료',
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white)),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 10, left: 0, right: 0,
                            child: Center(
                              child: GestureDetector(
                                onTap: () => setState(() => _photoTaken = false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.55),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('다시 촬영',
                                      style: TextStyle(color: Colors.white, fontSize: 11)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 56, height: 56,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.camera_alt_rounded, color: accent, size: 28),
                          ),
                          const SizedBox(height: 10),
                          Text('탭하여 사진 촬영',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black)),
                          const SizedBox(height: 4),
                          Text('GPS 위치가 자동 기록됩니다',
                              style: TextStyle(fontSize: 12, color: sub)),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── 사이즈 입력 ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('길이 (cm)',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700, color: sub)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _sizeCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))],
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: _size > 0 ? accent : (isDark ? Colors.white : Colors.black)),
                        decoration: InputDecoration(
                          hintText: '0.0',
                          hintStyle: TextStyle(
                              fontSize: 28, fontWeight: FontWeight.w900, color: sub),
                          suffixText: 'cm',
                          suffixStyle: TextStyle(fontSize: 16, color: sub),
                          border: InputBorder.none,
                        ),
                        onChanged: (v) => setState(() => _size = double.tryParse(v) ?? 0.0),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    _SizeBtn(
                      icon: Icons.add_rounded,
                      onTap: () {
                        final newVal = _size + 0.5;
                        setState(() {
                          _size = newVal;
                          _sizeCtrl.text = newVal.toStringAsFixed(1);
                        });
                      },
                      accent: accent,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 8),
                    _SizeBtn(
                      icon: Icons.remove_rounded,
                      onTap: () {
                        final newVal = (_size - 0.5).clamp(0.0, 999.0);
                        setState(() {
                          _size = newVal;
                          _sizeCtrl.text = newVal > 0 ? newVal.toStringAsFixed(1) : '';
                        });
                      },
                      accent: accent,
                      isDark: isDark,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── 제출 버튼 ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: canSubmit ? () => widget.onSubmit(_size) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canSubmit ? accent : (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE)),
                  foregroundColor: canSubmit ? (isDark ? Colors.black : Colors.white) : sub,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  canSubmit ? '순위표에 등록하기' : '사진과 길이를 입력하세요',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SizeBtn extends StatelessWidget {
  const _SizeBtn({required this.icon, required this.onTap, required this.accent, required this.isDark});
  final IconData icon;
  final VoidCallback onTap;
  final Color accent;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, size: 22, color: accent),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  진행 예정 리그 화면
// ─────────────────────────────────────────────────────────────────
class _UpcomingLeagueScreen extends StatelessWidget {
  const _UpcomingLeagueScreen({required this.data, required this.isDark, required this.accent});
  final LeagueDetailData data;
  final bool isDark;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final sub = isDark ? const Color(0xFF8E8E8E) : const Color(0xFF737373);
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final divColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(data.name,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          // D-Day 카드
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accent, accent.withValues(alpha: 0.6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Text('대회 시작까지',
                    style: TextStyle(
                        fontSize: 13,
                        color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.7),
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text('D-9',
                    style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.black : Colors.white)),
                Text(data.dateRange,
                    style: TextStyle(
                        fontSize: 13,
                        color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.8))),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 상세 정보 카드
          _InfoCard(
            isDark: isDark,
            cardBg: cardBg,
            divColor: divColor,
            children: [
              _InfoRow(icon: Icons.location_on_outlined, label: '장소', value: data.location, accent: accent, sub: sub),
              _InfoRow(icon: Icons.set_meal_outlined, label: '대상 어종', value: data.fish, accent: accent, sub: sub),
              _InfoRow(icon: Icons.leaderboard_outlined, label: '순위 방식', value: data.rule, accent: accent, sub: sub),
              _InfoRow(icon: Icons.people_outline_rounded, label: '최대 참가', value: '${data.maxParticipants}명', accent: accent, sub: sub),
              _InfoRow(icon: Icons.payments_outlined, label: '참가비', value: '${data.fee}원', accent: accent, sub: sub),
            ],
          ),
          const SizedBox(height: 12),

          // 시상 카드
          _InfoCard(
            isDark: isDark,
            cardBg: cardBg,
            divColor: divColor,
            children: [
              _InfoRow(icon: Icons.emoji_events_outlined, label: '시상', value: data.prize, accent: AppColors.gold, sub: sub),
            ],
          ),
          const SizedBox(height: 12),

          // 대회 소개
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: divColor)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('대회 소개', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: sub)),
                const SizedBox(height: 8),
                Text(data.intro, style: const TextStyle(fontSize: 14, height: 1.6)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 참가 취소 버튼
          SizedBox(
            height: 52,
            child: OutlinedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('참가 취소', style: TextStyle(fontWeight: FontWeight.w800)),
                    content: const Text('정말 참가를 취소하시겠습니까?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('아니요')),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pop(context);
                        },
                        child: const Text('취소하기', style: TextStyle(color: AppColors.error)),
                      ),
                    ],
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error),
                foregroundColor: AppColors.error,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('참가 취소', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  지난 대회 결과 화면
// ─────────────────────────────────────────────────────────────────
class _HistoryLeagueScreen extends StatelessWidget {
  const _HistoryLeagueScreen({required this.data, required this.board, required this.isDark, required this.accent});
  final LeagueDetailData data;
  final List<LeaderboardEntry> board;
  final bool isDark;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final sub = isDark ? const Color(0xFF8E8E8E) : const Color(0xFF737373);
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final divColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE);
    final myEntry = board.where((e) => e.isMe).firstOrNull;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data.name,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Text(data.dateRange, style: TextStyle(fontSize: 10, color: sub)),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          // 내 결과 카드
          if (myEntry != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: myEntry.rank == 1
                      ? AppColors.gold.withValues(alpha: 0.5)
                      : accent.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Text(
                    myEntry.rank == 1 ? '🥇' : myEntry.rank == 2 ? '🥈' : myEntry.rank == 3 ? '🥉' : '🎣',
                    style: const TextStyle(fontSize: 40),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('내 최종 순위',
                            style: TextStyle(fontSize: 11, color: sub)),
                        const SizedBox(height: 2),
                        Text(
                          '${myEntry.rank}위 / ${board.length}명',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: myEntry.rank <= 3 ? AppColors.gold : accent),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(myEntry.record,
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w900, color: accent)),
                      Text('+${myEntry.score}점',
                          style: TextStyle(fontSize: 13, color: accent, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 대회 정보
          _InfoCard(
            isDark: isDark, cardBg: cardBg, divColor: divColor,
            children: [
              _InfoRow(icon: Icons.location_on_outlined, label: '장소', value: data.location, accent: accent, sub: sub),
              _InfoRow(icon: Icons.set_meal_outlined, label: '어종', value: data.fish, accent: accent, sub: sub),
              _InfoRow(icon: Icons.people_outline_rounded, label: '참가자', value: '${board.length}명', accent: accent, sub: sub),
              _InfoRow(icon: Icons.emoji_events_outlined, label: '시상', value: data.prize, accent: AppColors.gold, sub: sub),
            ],
          ),
          const SizedBox(height: 16),

          // 최종 순위표
          Row(
            children: [
              const Text('최종 순위표', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const Spacer(),
              Text('${board.length}명 참가', style: TextStyle(fontSize: 12, color: sub)),
            ],
          ),
          const SizedBox(height: 10),

          // 포디움
          _LivePodium(board: board, isDark: isDark, accent: accent),
          const SizedBox(height: 12),

          // 4위~
          ...board.skip(3).map((e) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: e.isMe ? accent.withValues(alpha: 0.08) : cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: e.isMe ? accent.withValues(alpha: 0.4) : divColor,
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 30,
                  child: Text('${e.rank}',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w700, color: sub)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(children: [
                    Text(e.user, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    if (e.isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(4)),
                        child: Text('나', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: isDark ? Colors.black : Colors.white)),
                      ),
                    ],
                  ]),
                ),
                Text(e.record,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: e.isMe ? accent : (isDark ? Colors.white : Colors.black),
                        fontSize: 14)),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  공통 위젯
// ─────────────────────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.isDark, required this.cardBg, required this.divColor, required this.children});
  final bool isDark;
  final Color cardBg, divColor;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: divColor),
      ),
      child: Column(
        children: children.asMap().entries.map((e) => Column(
          children: [
            e.value,
            if (e.key < children.length - 1) Divider(height: 1, color: divColor, indent: 16, endIndent: 16),
          ],
        )).toList(),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value, required this.accent, required this.sub});
  final IconData icon;
  final String label, value;
  final Color accent, sub;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Icon(icon, size: 17, color: sub),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(fontSize: 13, color: sub)),
          const Spacer(),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
