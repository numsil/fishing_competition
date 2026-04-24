import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../data/profile_repository.dart';
import '../../../my_league/data/my_league_repository.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  bool _uploadingAvatar = false;

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

  Future<void> _pickAndUploadAvatar() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.neonGreen : AppColors.navy;

    // 카메라 / 갤러리 선택
    final choice = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF444444) : const Color(0xFFDDDDDD),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.camera_alt_rounded, color: accent),
              title: const Text('카메라로 촬영', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.photo_library_rounded, color: accent),
              title: const Text('갤러리에서 선택', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (choice == null) return;

    final picked = await ImagePicker().pickImage(
      source: choice,
      imageQuality: 85,
      maxWidth: 400,
    );
    if (picked == null) return;

    setState(() => _uploadingAvatar = true);
    try {
      await ref.read(profileRepositoryProvider).uploadAvatar(File(picked.path));
      ref.invalidate(myProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('프로필 사진이 업데이트되었습니다!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('업로드 실패: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
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
                      GestureDetector(
                        onTap: _uploadingAvatar ? null : _pickAndUploadAvatar,
                        child: Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: accent.withValues(alpha: 0.35), width: 2),
                              ),
                              child: _uploadingAvatar
                                  ? SizedBox(
                                      width: 76, height: 76,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5, color: accent),
                                    )
                                  : UserAvatar(
                                      username: profile.username,
                                      avatarUrl: profile.avatarUrl,
                                      radius: 38,
                                      isDark: isDark,
                                    ),
                            ),
                            Positioned(
                              bottom: 2, right: 2,
                              child: Container(
                                width: 24, height: 24,
                                decoration: BoxDecoration(
                                  color: accent,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDark ? AppColors.darkBg : Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  Icons.camera_alt_rounded,
                                  size: 12,
                                  color: isDark ? Colors.black : Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
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
                    child: Text('@${profile.username}', style: TextStyle(fontSize: 12, color: sub)),
                  ),
                  const SizedBox(height: 14),
                  // 버튼
                  Row(children: [
                    Expanded(child: OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        padding: EdgeInsets.zero,
                        side: BorderSide(color: isDark ? AppColors.darkSurface2 : AppColors.lightDivider),
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
                        side: BorderSide(color: isDark ? AppColors.darkSurface2 : AppColors.lightDivider),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Icon(LucideIcons.userPlus, size: 18, color: isDark ? Colors.white : Colors.black),
                    ),
                  ]),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isDark ? AppColors.darkSurface2 : AppColors.lightDivider),
                    ),
                    child: Column(children: [
                      Row(children: [
                        Text('앵글러 온도', style: TextStyle(fontSize: 12, color: sub, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Text('${profile.mannerTemperature}°', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: accent)),
                      ]),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: profile.mannerTemperature / 100,
                          backgroundColor: isDark ? AppColors.darkSurface2 : AppColors.lightDivider,
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
                        color: AppColors.gold.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
                      ),
                      child: Row(children: [
                        Icon(LucideIcons.award, size: 32, color: AppColors.gold),
                        const SizedBox(width: 12),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('역대 최대어', style: TextStyle(fontSize: 11, color: sub)),
                          Text('배스 ${profile.maxFishLength}cm', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.gold)),
                          Text('2026.04.22 · 충주호', style: TextStyle(fontSize: 11, color: sub)),
                        ]),
                        const Spacer(),
                        Column(children: [
                          Icon(LucideIcons.checkCircle, color: AppColors.gold, size: 16),
                          const SizedBox(height: 2),
                          const Text('인증', style: TextStyle(fontSize: 10, color: AppColors.gold)),
                        ]),
                      ]),
                    ),
                  const SizedBox(height: 10),

                  // 통계 4칸
                  Builder(builder: (context) {
                    final participationCount = ref.watch(myLeaguesProvider).maybeWhen(
                      data: (map) {
                        final participated = map['participated'] ?? [];
                        final hosted = map['hosted'] ?? [];
                        final allIds = {
                          ...participated.map((l) => l.id),
                          ...hosted.map((l) => l.id),
                        };
                        return allIds.length;
                      },
                      orElse: () => 0,
                    );
                    return Row(children: [
                      _StatBox(icon: LucideIcons.waves, value: '$participationCount', label: '참가', isDark: isDark, accent: accent),
                      const SizedBox(width: 8),
                      _StatBox(icon: LucideIcons.medal, value: '-', label: '우승', isDark: isDark, accent: accent),
                      const SizedBox(width: 8),
                      _StatBox(icon: LucideIcons.fish, value: '${profile.lunkerCount}', label: '런커', isDark: isDark, accent: accent),
                      const SizedBox(width: 8),
                      _StatBox(icon: LucideIcons.barChart2, value: '-', label: '점수', isDark: isDark, accent: accent),
                    ]);
                  }),
                  const SizedBox(height: 6),

                  // 탭
                  TabBar(
                    controller: _tab,
                    indicatorSize: TabBarIndicatorSize.tab,
                    tabs: const [
                      Tab(icon: Icon(LucideIcons.layoutGrid, size: 20)),
                      Tab(icon: Icon(LucideIcons.list, size: 20)),
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
        color: AppColors.gold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(LucideIcons.award, size: 10, color: AppColors.gold),
        const SizedBox(width: 4),
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
  const _StatBox({required this.icon, required this.value, required this.label, required this.isDark, required this.accent});
  final IconData icon;
  final String value, label;
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
          border: Border.all(color: isDark ? AppColors.darkSurface2 : AppColors.lightDivider),
        ),
        child: Column(children: [
          Icon(icon, size: 18, color: subColor(isDark)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: accent)),
          Text(label, style: TextStyle(fontSize: 10, color: subColor(isDark))),
        ]),
      ),
    );
  }
  
  Color subColor(bool isDark) => isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A);
}

class _Grid extends ConsumerWidget {
  const _Grid({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(myPostsProvider).when(
      data: (posts) {
        if (posts.isEmpty) {
          return Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(LucideIcons.image, size: 48, color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFA1A1AA)),
              const SizedBox(height: 12),
              Text('아직 게시물이 없어요', style: TextStyle(color: isDark ? const Color(0xFF71717A) : const Color(0xFFA1A1AA), fontSize: 14)),
            ]),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2,
          ),
          itemCount: posts.length,
          itemBuilder: (_, i) {
            final post = posts[i];
            return GestureDetector(
              onTap: () => context.push(AppRoutes.postDetail, extra: post),
              child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  post.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: isDark ? AppColors.darkSurface2 : AppColors.lightDivider,
                    child: Icon(LucideIcons.image, size: 24, color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFA1A1AA)),
                  ),
                ),
                if (post.isLunker)
                  Positioned(
                    bottom: 4, right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(4)),
                      child: Text(
                        post.length != null ? '${post.length}cm' : '런커',
                        style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.black),
                      ),
                    ),
                  ),
              ],
            ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('불러오기 실패: $e')),
    );
  }
}

class _History extends ConsumerWidget {
  const _History({required this.isDark, required this.accent, required this.sub, required this.cardBg});
  final bool isDark;
  final Color accent, sub, cardBg;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(myLeaguesProvider).when(
      data: (myLeaguesMap) {
        final participated = [...(myLeaguesMap['participated'] ?? [])];
        participated.sort((a, b) => b.startTime.compareTo(a.startTime));

        if (participated.isEmpty) {
          return Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(LucideIcons.fish, size: 48, color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFA1A1AA)),
              const SizedBox(height: 12),
              Text('참가한 리그가 없어요', style: TextStyle(color: sub, fontSize: 14)),
            ]),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: participated.length,
          itemBuilder: (_, i) {
            final league = participated[i];
            final isCompleted = league.status == 'completed';
            final isLive = league.status == 'in_progress';
            final statusLabel = isLive ? '진행중' : isCompleted ? '종료' : '모집중';
            final statusColor = isLive ? AppColors.liveRed : isCompleted ? sub : accent;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isLive
                      ? accent.withValues(alpha: 0.3)
                      : (isDark ? AppColors.darkSurface2 : AppColors.lightDivider),
                ),
              ),
              child: Row(children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? (isDark ? AppColors.darkSurface2 : AppColors.lightBg)
                        : accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(
                      isCompleted ? LucideIcons.award : LucideIcons.trophy,
                      size: 18,
                      color: isCompleted ? sub : accent,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(league.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Row(children: [
                    Icon(LucideIcons.mapPin, size: 11, color: sub),
                    const SizedBox(width: 3),
                    Text(league.location, style: TextStyle(fontSize: 11, color: sub)),
                  ]),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(statusLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor)),
                  ),
                  const SizedBox(height: 4),
                  Text('${league.participantsCount}명 참가', style: TextStyle(fontSize: 11, color: sub)),
                ]),
              ]),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('불러오기 실패', style: TextStyle(color: sub))),
    );
  }
}
