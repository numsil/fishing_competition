import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';

class LeagueScreen extends StatefulWidget {
  const LeagueScreen({super.key});

  @override
  State<LeagueScreen> createState() => _LeagueScreenState();
}

class _LeagueScreenState extends State<LeagueScreen> {
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
            icon: Icon(Icons.add, size: 18, color: accent),
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
                prefixIcon: Icon(Icons.search_rounded, color: sub, size: 20),
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
                    border: Border.all(color: _filter == i ? accent : sub),
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
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: const [
                _LeagueItem(id: '1', title: '2026 충주호 배스 오픈', location: '충북 충주시', date: '4/22 ~ 4/23', participants: 24, max: 30, prize: '50만원', status: _Status.live, rule: '최대어'),
                SizedBox(height: 1),
                _LeagueItem(id: '2', title: '소양강 쏘가리 챔피언십', location: '강원 춘천시', date: '4/26 ~ 4/27', participants: 12, max: 20, prize: '30만원', status: _Status.open, rule: '합산'),
                SizedBox(height: 1),
                _LeagueItem(id: '3', title: '팔당 주말 릴낚시 모임', location: '경기 남양주시', date: '5/3', participants: 8, max: 15, prize: '식사 제공', status: _Status.open, rule: '마릿수'),
                SizedBox(height: 1),
                _LeagueItem(id: '4', title: '가평 계곡 송어 대회', location: '경기 가평군', date: '5/10 ~ 5/11', participants: 5, max: 40, prize: '100만원', status: _Status.soon, rule: '최대어'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _Status { live, open, soon }

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
    final border = isDark ? const Color(0xFF222222) : const Color(0xFFF0F0F0);

    final (statusText, statusColor) = switch (status) {
      _Status.live => ('LIVE', AppColors.liveRed),
      _Status.open => ('모집중', AppColors.success),
      _Status.soon => ('예정', sub),
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
                Icon(Icons.location_on_outlined, size: 12, color: sub),
                const SizedBox(width: 3),
                Text(location, style: TextStyle(fontSize: 12, color: sub)),
                const SizedBox(width: 12),
                Icon(Icons.calendar_today_outlined, size: 12, color: sub),
                const SizedBox(width: 3),
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
