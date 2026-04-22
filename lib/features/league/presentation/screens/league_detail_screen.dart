import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class LeagueDetailScreen extends StatelessWidget {
  const LeagueDetailScreen({super.key, required this.leagueId});

  final String leagueId;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.neonGreen : AppColors.navy;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 헤더
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: isDark ? AppColors.darkSurface2 : AppColors.lightDivider,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: 60),
                    Text('🎣', style: TextStyle(fontSize: 70)),
                  ],
                ),
              ),
            ),
            actions: [
              IconButton(icon: const Icon(Icons.share_outlined), onPressed: () {}),
              IconButton(icon: const Icon(Icons.bookmark_border_rounded), onPressed: () {}),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 상태 + 제목
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.liveRed,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          '🔴 LIVE 진행중',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '2026 충주호 배스 오픈',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 14, color: accent),
                      const SizedBox(width: 2),
                      Text(
                        '충청북도 충주시 · 0.3km',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 지도 영역 (더미)
                  Container(
                    height: 150,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface2 : const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
                      ),
                    ),
                    child: Stack(
                      children: [
                        const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.map_outlined, size: 32, color: Colors.grey),
                              SizedBox(height: 4),
                              Text('대회 구역 지도', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: accent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '지도 열기',
                              style: TextStyle(
                                color: isDark ? Colors.black : Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 통계 카드들
                  Row(
                    children: [
                      _StatBox(label: '참가자', value: '24/30명', accent: accent),
                      const SizedBox(width: 10),
                      _StatBox(label: '총 상금', value: '50만원', accent: accent),
                      const SizedBox(width: 10),
                      _StatBox(label: '순위 방식', value: '최대어', accent: accent),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 대회 규정
                  _SectionTitle(title: '대회 규정', isDark: isDark),
                  const SizedBox(height: 10),
                  _RuleRow(icon: '🐟', label: '대상어종', value: '배스'),
                  _RuleRow(icon: '📏', label: '최소 기준', value: '25cm 이상'),
                  _RuleRow(icon: '🔢', label: '제출 제한', value: '1인 5마리'),
                  _RuleRow(icon: '📍', label: '계측 방법', value: '전장 기준'),
                  _RuleRow(icon: '⏰', label: '계측 마감', value: '오후 5시'),
                  const SizedBox(height: 20),

                  // 실시간 리더보드
                  Row(
                    children: [
                      _SectionTitle(title: '실시간 순위', isDark: isDark),
                      const SizedBox(width: 8),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.liveRed,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'LIVE',
                        style: TextStyle(
                            color: AppColors.liveRed,
                            fontSize: 11,
                            fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ..._buildLeaderboard(isDark, accent),
                  const SizedBox(height: 20),

                  // 호스트 정보
                  _SectionTitle(title: '주최 정보', isDark: isDark),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
                      ),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 24,
                          child: Text('🎣', style: TextStyle(fontSize: 22)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('충주낚시클럽',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700, fontSize: 15)),
                              Row(
                                children: [
                                  const Icon(Icons.star_rounded,
                                      size: 14, color: AppColors.gold),
                                  const Text(' 4.8 · 리그 32회 주최',
                                      style: TextStyle(fontSize: 12)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            side: BorderSide(color: accent),
                            foregroundColor: accent,
                          ),
                          child: const Text('문의'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      // 하단 버튼
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: Icon(Icons.share, color: accent),
                  label: Text('초대 링크', style: TextStyle(color: accent)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 50),
                    side: BorderSide(color: accent),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.how_to_reg_rounded),
                  label: const Text('참가 신청하기'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildLeaderboard(bool isDark, Color accent) {
    final entries = [
      ('1', '배스왕 김민준', '52.3cm', '🏆'),
      ('2', '루어마스터 이서연', '48.7cm', '🥈'),
      ('3', '주말낚시 박태준', '45.1cm', '🥉'),
      ('4', '가평낚시 최현수', '42.8cm', '4'),
      ('5', '소양강 정민호', '41.5cm', '5'),
    ];

    return entries.map((e) {
      final isTop3 = int.parse(e.$1) <= 3;
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isTop3
                ? accent.withValues(alpha: 0.3)
                : (isDark ? AppColors.darkDivider : AppColors.lightDivider),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Text(
                e.$4,
                style: const TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                e.$2,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              e.$3,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: accent,
                fontSize: 15,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label, value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: accent,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.isDark});

  final String title;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final String icon, label, value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
