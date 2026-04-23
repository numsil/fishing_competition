import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/league_repository.dart';

class LeagueScreen extends ConsumerStatefulWidget {
  const LeagueScreen({super.key});

  @override
  ConsumerState<LeagueScreen> createState() => _LeagueScreenState();
}

class _LeagueScreenState extends ConsumerState<LeagueScreen> {
  int _filter = 0;
  final _filters = ['전체', '모집중', '진행중', '내 주변'];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.neonGreen : AppColors.navy;
    final sub = isDark ? const Color(0xFF555555) : const Color(0xFFCCCCCC);

    return Scaffold(
      appBar: AppBar(
        title: const Text('리그', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
        actions: [
          TextButton.icon(
            onPressed: () => context.go('/league/create'),
            icon: Icon(LucideIcons.plus, size: 18, color: accent),
            label: Text('개설', style: TextStyle(color: accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: Column(
        children: [
          // 검색
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              decoration: InputDecoration(
                hintText: '지역, 대회명으로 검색',
                hintStyle: TextStyle(color: sub, fontSize: 14),
                prefixIcon: Icon(LucideIcons.search, color: sub, size: 20),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          // 필터
          SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filters.length,
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => setState(() => _filter = i),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: _filter == i ? accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _filter == i ? accent : (isDark ? AppColors.darkSurface2 : AppColors.lightDivider)),
                  ),
                  child: Center(
                    child: Text(
                      _filters[i],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _filter == i
                            ? (isDark ? Colors.black : Colors.white)
                            : (isDark ? const Color(0xFF888888) : const Color(0xFF888888)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 리스트
          Expanded(
            child: ref.watch(leaguesProvider).when(
              data: (leaguesData) {
                if (leaguesData.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () async => ref.invalidate(leaguesProvider),
                    child: ListView(
                      children: const [
                        SizedBox(height: 160),
                        Center(child: Text('등록된 리그가 없습니다.', style: TextStyle(color: Colors.grey))),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(leaguesProvider),
                  child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: leaguesData.length,
                  itemBuilder: (context, index) {
                    final l = leaguesData[index];
                    final startStr = DateFormat('M/d').format(l.startTime);
                    final endStr = DateFormat('M/d').format(l.endTime);
                    
                    _Status stat = _Status.open;
                    if (l.status == 'in_progress') stat = _Status.live;
                    else if (l.status == 'completed') stat = _Status.ended;
                    else if (l.status == 'canceled') stat = _Status.canceled;

                    return _LeagueItem(
                      id: l.id,
                      title: l.title,
                      location: l.location,
                      date: startStr == endStr ? startStr : '$startStr ~ $endStr',
                      participants: l.participantsCount,
                      max: l.maxParticipants,
                      prize: l.entryFee > 0 ? '${NumberFormat('#,###').format(l.entryFee)}원' : '무료 참가',
                      status: stat,
                      rule: l.description ?? '',
                    );
                  },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => RefreshIndicator(
                onRefresh: () async => ref.invalidate(leaguesProvider),
                child: ListView(
                  children: [
                    const SizedBox(height: 160),
                    Center(child: Text('오류가 발생했습니다: $e', style: const TextStyle(color: Colors.grey))),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _Status { live, open, ended, canceled }

class _LeagueItem extends StatelessWidget {
  const _LeagueItem({required this.id, required this.title, required this.location, required this.date, required this.participants, required this.max, required this.prize, required this.status, required this.rule});
  final String id, title, location, date, prize, rule;
  final int participants, max;
  final _Status status;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.neonGreen : AppColors.navy;
    final sub = isDark ? const Color(0xFF666666) : const Color(0xFF999999);
    final bg = isDark ? AppColors.darkSurface : Colors.white;
    final border = isDark ? AppColors.darkSurface2 : AppColors.lightDivider;

    final (statusText, statusColor) = switch (status) {
      _Status.live => ('LIVE', AppColors.liveRed),
      _Status.open => ('모집중', AppColors.success),
      _Status.ended => ('종료', sub),
      _Status.canceled => ('취소', AppColors.error),
    };

    return GestureDetector(
      onTap: () => context.go('/league/detail/$id'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단: 상태 + 제목
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(statusText, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: statusColor)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15), overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // 중간: 정보
            Row(
              children: [
                Icon(LucideIcons.mapPin, size: 12, color: sub),
                const SizedBox(width: 4),
                Text(location, style: TextStyle(fontSize: 12, color: sub)),
                const SizedBox(width: 12),
                Icon(LucideIcons.calendar, size: 12, color: sub),
                const SizedBox(width: 4),
                Text(date, style: TextStyle(fontSize: 12, color: sub)),
              ],
            ),
            const SizedBox(height: 12),
            // 하단: 참가 바 + 상금 + 규칙
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$participants / $max명', style: TextStyle(fontSize: 11, color: sub)),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: participants / max,
                          backgroundColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0),
                          valueColor: AlwaysStoppedAnimation(accent),
                          minHeight: 3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(prize, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: accent)),
                    Text(rule, style: TextStyle(fontSize: 11, color: sub)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
