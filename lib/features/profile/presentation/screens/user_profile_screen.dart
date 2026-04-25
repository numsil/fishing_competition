import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/stat_widgets.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../dm/data/dm_repository.dart';
import '../../data/profile_repository.dart';

class UserProfileScreen extends ConsumerStatefulWidget {
  const UserProfileScreen({super.key, required this.userId});
  final String userId;

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  bool _dmLoading = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 1, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _openDm(String otherUsername, String? otherAvatarUrl) async {
    if (_dmLoading) return;
    setState(() => _dmLoading = true);
    try {
      final conversationId = await ref
          .read(dmRepositoryProvider)
          .getOrCreateConversation(widget.userId);
      if (mounted) {
        context.push(
          AppRoutes.dmChat,
          extra: DmConversation(
            id: conversationId,
            otherUserId: widget.userId,
            otherUsername: otherUsername,
            otherAvatarUrl: otherAvatarUrl,
            lastMessageAt: DateTime.now(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('메시지를 시작할 수 없습니다')),
        );
      }
    } finally {
      if (mounted) setState(() => _dmLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.neonGreen : AppColors.navy;
    final sub = isDark ? const Color(0xFF666666) : const Color(0xFFAAAAAA);
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final currentUser = ref.watch(currentUserProvider);
    final isMe = currentUser?.id == widget.userId;

    // 내 프로필이면 탭으로 리다이렉트
    if (isMe) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(AppRoutes.profile);
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return ref.watch(userProfileProvider(widget.userId)).when(
      skipLoadingOnReload: true,
      data: (profile) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(LucideIcons.arrowLeft,
                color: isDark ? Colors.white : Colors.black),
            onPressed: () => context.pop(),
          ),
          title: Text(
            profile.username,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          backgroundColor: isDark ? AppColors.darkBg : Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 프로필 행
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: accent.withValues(alpha: 0.35), width: 2),
                          ),
                          child: UserAvatar(
                            username: profile.username,
                            avatarUrl: profile.avatarUrl,
                            radius: 38,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              StatNumber(
                                  value: '${profile.postCount}',
                                  label: '게시물',
                                  subColor: sub),
                              StatNumber(value: '0', label: '팔로워', subColor: sub),
                              StatNumber(value: '0', label: '팔로잉', subColor: sub),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      Text(profile.username,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 15)),
                      const SizedBox(width: 6),
                      if (profile.isLunkerClub) const _LunkerBadge(),
                    ]),
                    const SizedBox(height: 2),
                    Text('@${profile.username}',
                        style: TextStyle(fontSize: 12, color: sub)),
                    const SizedBox(height: 14),

                    // 팔로우 / 메시지 버튼
                    Row(children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: () {},
                          style: FilledButton.styleFrom(
                            backgroundColor: accent,
                            minimumSize: const Size(0, 36),
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(
                            '팔로우',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.black : Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _dmLoading
                            ? null
                            : () => _openDm(
                                profile.username, profile.avatarUrl),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(36, 36),
                          padding: EdgeInsets.zero,
                          side: BorderSide(
                              color: isDark
                                  ? AppColors.darkSurface2
                                  : AppColors.lightDivider),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: _dmLoading
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: accent,
                                ),
                              )
                            : Icon(LucideIcons.messageCircle,
                                size: 18,
                                color: isDark ? Colors.white : Colors.black),
                      ),
                    ]),
                    const SizedBox(height: 16),

                    // 앵글러 온도
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: isDark
                                ? AppColors.darkSurface2
                                : AppColors.lightDivider),
                      ),
                      child: Column(children: [
                        Row(children: [
                          Text('앵글러 온도',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: sub,
                                  fontWeight: FontWeight.w600)),
                          const Spacer(),
                          Text('${profile.mannerTemperature}°',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: accent)),
                        ]),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: profile.mannerTemperature / 100,
                            backgroundColor: isDark
                                ? AppColors.darkSurface2
                                : AppColors.lightDivider,
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
                          border: Border.all(
                              color: AppColors.gold.withValues(alpha: 0.2)),
                        ),
                        child: Row(children: [
                          Icon(LucideIcons.award,
                              size: 32, color: AppColors.gold),
                          const SizedBox(width: 12),
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('역대 최대어',
                                    style:
                                        TextStyle(fontSize: 11, color: sub)),
                                Text('배스 ${profile.maxFishLength}cm',
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.gold)),
                              ]),
                          const Spacer(),
                          Column(children: [
                            Icon(LucideIcons.checkCircle,
                                color: AppColors.gold, size: 16),
                            const SizedBox(height: 2),
                            const Text('인증',
                                style: TextStyle(
                                    fontSize: 10, color: AppColors.gold)),
                          ]),
                        ]),
                      ),
                    const SizedBox(height: 10),

                    // 통계 4칸
                    Row(children: [
                      StatBox(
                          icon: LucideIcons.fish,
                          value: '${profile.lunkerCount}',
                          label: '런커',
                          isDark: isDark,
                          accent: accent),
                      const SizedBox(width: 8),
                      StatBox(
                          icon: LucideIcons.medal,
                          value: '-',
                          label: '우승',
                          isDark: isDark,
                          accent: accent),
                      const SizedBox(width: 8),
                      StatBox(
                          icon: LucideIcons.barChart2,
                          value: '-',
                          label: '점수',
                          isDark: isDark,
                          accent: accent),
                      const SizedBox(width: 8),
                      StatBox(
                          icon: LucideIcons.waves,
                          value: '-',
                          label: '참가',
                          isDark: isDark,
                          accent: accent),
                    ]),
                    const SizedBox(height: 6),

                    // 탭 헤더
                    TabBar(
                      controller: _tab,
                      indicatorSize: TabBarIndicatorSize.tab,
                      tabs: const [
                        Tab(icon: Icon(LucideIcons.layoutGrid, size: 20)),
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
              _UserGrid(userId: widget.userId, isDark: isDark),
            ],
          ),
        ),
      ),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) =>
          Scaffold(body: Center(child: Text('프로필을 불러올 수 없어요: $e'))),
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
        const Text('런커',
            style: TextStyle(
                fontSize: 9,
                color: AppColors.gold,
                fontWeight: FontWeight.w800)),
      ]),
    );
  }
}


class _UserGrid extends ConsumerWidget {
  const _UserGrid({required this.userId, required this.isDark});
  final String userId;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(userPostsProvider(userId)).when(
      data: (posts) {
        if (posts.isEmpty) {
          return Center(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.image,
                      size: 48,
                      color: isDark
                          ? const Color(0xFF3F3F46)
                          : const Color(0xFFA1A1AA)),
                  const SizedBox(height: 12),
                  Text('아직 게시물이 없어요',
                      style: TextStyle(
                          color: isDark
                              ? const Color(0xFF71717A)
                              : const Color(0xFFA1A1AA),
                          fontSize: 14)),
                ]),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
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
                      color: isDark
                          ? AppColors.darkSurface2
                          : AppColors.lightDivider,
                      child: Icon(LucideIcons.image,
                          size: 24,
                          color: isDark
                              ? const Color(0xFF3F3F46)
                              : const Color(0xFFA1A1AA)),
                    ),
                  ),
                  if (post.isLunker)
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                            color: AppColors.gold,
                            borderRadius: BorderRadius.circular(4)),
                        child: Text(
                          post.length != null
                              ? '${post.length}cm'
                              : '런커',
                          style: const TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              color: Colors.black),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
      loading: () =>
          const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          const Center(child: Text('게시물을 불러올 수 없어요')),
    );
  }
}
