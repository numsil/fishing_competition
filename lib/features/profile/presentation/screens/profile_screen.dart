import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_svg.dart';
import '../../data/profile_repository.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.neonGreen : AppColors.navy;
    final sub = isDark ? const Color(0xFF666666) : const Color(0xFFAAAAAA);
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;

    return ref.watch(myProfileProvider).when(
      data: (profile) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('프로필', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
            actions: [
              IconButton(icon: Icon(Icons.settings_outlined, color: isDark ? Colors.white : Colors.black), onPressed: () {}),
              IconButton(icon: const Icon(Icons.logout_rounded, color: AppColors.error, size: 20), onPressed: () => context.go(AppRoutes.login)),
            ],
          ),
          body: NestedScrollView(
            headerSliverBuilder: (context, _) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                children: [
                  // 프로필 행
                  Row(
                    children: [
                      Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.gold, width: 2)),
                            child: CircleAvatar(
                              radius: 38,
                              backgroundColor: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF0F0F0),
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: AppSvg(AppIcons.fishingRod,
                                    color: isDark ? const Color(0xFF444444) : const Color(0xFFBBBBBB)),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0, right: 0,
                            child: Container(
                              width: 22, height: 22,
                              decoration: BoxDecoration(
                                color: AppColors.gold,
                                shape: BoxShape.circle,
                                border: Border.all(color: isDark ? AppColors.darkBg : Colors.white, width: 2),
                              ),
                              child: const Center(child: Text('👑', style: TextStyle(fontSize: 10))),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _Stat(value: '${profile.postCount}', label: '게시물', sub: sub),
                            _Stat(value: '0', label: '팔로워', sub: sub),
                            _Stat(value: '0', label: '팔로잉', sub: sub),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text(profile.username, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                          const SizedBox(width: 6),
                          if (profile.isLunkerClub) const _LunkerBadge(),
                        ]),
                        const SizedBox(height: 2),
                      ],
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('@basking_minjun', style: TextStyle(fontSize: 12, color: sub)),
                  ),
                  const SizedBox(height: 14),
                  // 버튼
                  Row(children: [
                    Expanded(child: OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        padding: EdgeInsets.zero,
                        side: BorderSide(color: isDark ? const Color(0xFF333333) : const Color(0xFFDDDDDD)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text('프로필 수정', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black)),
                    )),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(36, 36),
                        padding: EdgeInsets.zero,
                        side: BorderSide(color: isDark ? const Color(0xFF333333) : const Color(0xFFDDDDDD)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Icon(Icons.person_add_outlined, size: 18, color: isDark ? Colors.white : Colors.black),
                    ),
                  ]),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE)),
                    ),
                    child: Column(children: [
                      Row(children: [
                        Text('앵글러 온도', style: TextStyle(fontSize: 12, color: sub, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Text('${profile.mannerTemperature}°', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: accent)),
                      ]),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: profile.mannerTemperature / 100,
                          backgroundColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE),
                          valueColor: AlwaysStoppedAnimation(accent),
                          minHeight: 6,
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 10),

                  // 런커 기록
                  if (profile.maxFishLength != null)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                      ),
                      child: Row(children: [
                        AppSvg(AppIcons.trophy, size: 36, color: AppColors.gold),
                        const SizedBox(width: 12),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('역대 최대어', style: TextStyle(fontSize: 11, color: sub)),
                          Text('배스 ${profile.maxFishLength}cm', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.gold)),
                          Text('2026.04.22 · 충주호', style: TextStyle(fontSize: 11, color: sub)),
                        ]),
                        const Spacer(),
                        const Column(children: [
                          Icon(Icons.verified_rounded, color: AppColors.gold, size: 18),
                          Text('인증', style: TextStyle(fontSize: 10, color: AppColors.gold)),
                        ]),
                      ]),
                    ),
                  const SizedBox(height: 10),

                  // 통계 4칸
                  Row(children: [
                    _StatBox(emoji: '🎣', value: '12', label: '참가', isDark: isDark, accent: accent),
                    const SizedBox(width: 8),
                    _StatBox(emoji: '🥇', value: '3', label: '우승', isDark: isDark, accent: accent),
                    const SizedBox(width: 8),
                    _StatBox(emoji: '⭐', value: '8', label: '배지', isDark: isDark, accent: accent),
                    const SizedBox(width: 8),
                    _StatBox(emoji: '📊', value: '2.4K', label: '점수', isDark: isDark, accent: accent),
                  ]),
                  const SizedBox(height: 6),

                  // 탭
                  TabBar(
                    controller: _tab,
                    tabs: const [
                      Tab(icon: Icon(Icons.grid_on_rounded, size: 22)),
                      Tab(icon: Icon(Icons.emoji_events_outlined, size: 22)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
            body: TabBarView(
              controller: _tab,
              children: [
                _Grid(isDark: isDark),
                _History(isDark: isDark, accent: accent, sub: sub, cardBg: cardBg),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, st) => Scaffold(body: Center(child: Text('오류: $e'))),
    );
  }
}

class _LunkerBadge extends StatelessWidget {
  const _LunkerBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        AppSvg(AppIcons.trophy, size: 9, color: AppColors.gold),
        const SizedBox(width: 3),
        const Text('런커', style: TextStyle(fontSize: 9, color: AppColors.gold, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.sub});
  final String value, label;
  final Color sub;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      Text(label, style: TextStyle(fontSize: 11, color: sub)),
    ]);
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.emoji, required this.value, required this.label, required this.isDark, required this.accent});
  final String emoji, value, label;
  final bool isDark;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE)),
        ),
        child: Column(children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: accent)),
          Text(label, style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF666666) : const Color(0xFFAAAAAA))),
        ]),
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.isDark});
  final bool isDark;

  static const _items = ['🎣', '🐟', '🐠', '🎏', '🦈', '🐡', '🎣', '🐟', '🐠', '🎏', '🦈', '🐡'];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2,
      ),
      itemCount: _items.length,
      itemBuilder: (_, i) => Container(
        color: isDark ? const Color(0xFF111111) : const Color(0xFFF5F5F5),
        child: Stack(children: [
          Center(child: Text(_items[i], style: const TextStyle(fontSize: 40))),
          if (i == 0) Positioned(
            bottom: 6, right: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(4)),
              child: const Text('52.3cm', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.black)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _History extends StatelessWidget {
  const _History({required this.isDark, required this.accent, required this.sub, required this.cardBg});
  final bool isDark;
  final Color accent, sub, cardBg;

  static const _records = [
    ('충주호 배스 오픈', '🥇 1위', '52.3cm', '+300'),
    ('소양강 챔피언십', '🥈 2위', '38.5cm', '+200'),
    ('팔당 주말 모임', '4위', '32.1cm', '+50'),
    ('가평 계곡 대회', '🥇 1위', '44.8cm', '+300'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _records.length,
      itemBuilder: (_, i) {
        final (title, rank, size, score) = _records[i];
        final isWin = rank.contains('1위');
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE)),
          ),
          child: Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: isWin ? AppColors.gold.withValues(alpha: 0.1) : (isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(child: Text(isWin ? '🥇' : '🎣', style: const TextStyle(fontSize: 18))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Text(size, style: TextStyle(fontSize: 12, color: sub)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(rank, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              Text(score, style: TextStyle(fontSize: 12, color: accent, fontWeight: FontWeight.w700)),
            ]),
          ]),
        );
      },
    );
  }
}
