import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../dm/data/dm_repository.dart';
import '../../../../core/widgets/stat_widgets.dart';
import '../../../../core/widgets/score_card.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../data/profile_repository.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../my_league/data/my_league_repository.dart';
import '../../../marketplace/data/marketplace_model.dart';
import '../../../marketplace/data/marketplace_repository.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/widgets/app_action_sheet.dart';
import '../../../../core/widgets/menu_item.dart';
import '../../../../core/extensions/theme_extensions.dart';

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

    // 카메라 / 갤러리 선택
    final choice = await showAppActionSheet<ImageSource>(
      context,
      items: [
        AppMenuItem(
          icon: LucideIcons.camera,
          label: '카메라로 촬영',
          onTap: () => Navigator.pop(context, ImageSource.camera),
        ),
        AppMenuItem(
          icon: LucideIcons.image,
          label: '갤러리에서 선택',
          onTap: () => Navigator.pop(context, ImageSource.gallery),
        ),
      ],
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
                AppSnackBar.success(context, '프로필 사진이 업데이트되었습니다!');
      }
    } catch (e) {
      if (mounted) {
                AppSnackBar.error(context, '업로드 실패: $e');
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _openAdminDm() async {
    try {
      final conversationId = await ref
          .read(dmRepositoryProvider)
          .getOrCreateConversation(AppConstants.adminUserId);
      if (!mounted) return;
      context.push(
        AppRoutes.dmChat,
        extra: DmConversation(
          id: conversationId,
          otherUserId: AppConstants.adminUserId,
          otherUsername: AppConstants.adminUsername,
          otherAvatarUrl: null,
          lastMessageAt: DateTime.now(),
          hasUnread: false,
        ),
      );
    } catch (e) {
      if (mounted) AppSnackBar.error(context, '문의 화면을 열 수 없습니다');
    }
  }

  Future<void> _logout() async {
    final confirm = await showConfirmDialog(
      context,
      title: '로그아웃',
      content: '정말 로그아웃 하시겠어요?',
      confirmText: '로그아웃',
      confirmColor: AppColors.error,
      icon: Icons.logout_rounded,
    );
    if (!confirm) return;
    // navigate 먼저: signOut() 호출 시 authState 변화로
    // myProfile이 재빌드되어 에러 화면이 보이는 문제 방지
    if (mounted) context.go(AppRoutes.login);
    await ref.read(authRepositoryProvider).signOut();
  }

  Future<void> _showSettingsSheet(BuildContext rootContext, UserProfile profile) async {
    await showAppActionSheet<void>(
      rootContext,
      items: [
        AppMenuItem(
          icon: LucideIcons.pencil,
          label: '프로필 수정',
          onTap: () {
            Navigator.pop(rootContext);
            rootContext.push(AppRoutes.profileEdit, extra: profile);
          },
        ),
        AppMenuItem(
          icon: LucideIcons.lock,
          label: '비밀번호 변경',
          onTap: () {
            Navigator.pop(rootContext);
            rootContext.push(AppRoutes.passwordChange);
          },
        ),
        AppMenuItem(
          icon: LucideIcons.headphones,
          label: '관리자에게 문의',
          onTap: () {
            Navigator.pop(rootContext);
            _openAdminDm();
          },
        ),
        AppMenuItem(
          icon: LucideIcons.ban,
          label: '차단한 사용자',
          onTap: () {
            Navigator.pop(rootContext);
            rootContext.push(AppRoutes.blockedUsers);
          },
        ),
        const AppMenuDivider(),
        AppMenuItem(
          icon: LucideIcons.fileText,
          label: '서비스 이용약관',
          onTap: () {
            Navigator.pop(rootContext);
            rootContext.push(AppRoutes.terms);
          },
        ),
        AppMenuItem(
          icon: LucideIcons.shield,
          label: '개인정보처리방침',
          onTap: () {
            Navigator.pop(rootContext);
            rootContext.push(AppRoutes.privacy);
          },
        ),
        const AppMenuDivider(),
        AppMenuItem(
          icon: LucideIcons.logOut,
          label: '로그아웃',
          destructive: true,
          onTap: () {
            Navigator.pop(rootContext);
            _logout();
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final sub = context.isDark ? const Color(0xFF666666) : const Color(0xFFAAAAAA);
    final cardBg = context.isDark ? AppColors.darkSurface : Colors.white;

    return ref.watch(myProfileProvider).when(
      data: (profile) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('프로필', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
            actions: [
              IconButton(
                icon: Icon(LucideIcons.menu,
                    color: context.isDark ? Colors.white : Colors.black),
                onPressed: () => _showSettingsSheet(context, profile),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(myProfileProvider);
              ref.invalidate(myPostsProvider);
              ref.invalidate(myLeaguesProvider);
            },
            child: NestedScrollView(
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
                                border: Border.all(color: context.accentColor.withValues(alpha: 0.35), width: 2),
                              ),
                              child: _uploadingAvatar
                                  ? SizedBox(
                                      width: 76, height: 76,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5, color: context.accentColor),
                                    )
                                  : UserAvatar(
                                      username: profile.username,
                                      avatarUrl: profile.avatarUrl,
                                      radius: 38,
                                      isDark: context.isDark,
                                    ),
                            ),
                            Positioned(
                              bottom: 2, right: 2,
                              child: Container(
                                width: 24, height: 24,
                                decoration: BoxDecoration(
                                  color: context.accentColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: context.isDark ? AppColors.darkBg : Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  Icons.camera_alt_rounded,
                                  size: 12,
                                  color: context.isDark ? Colors.black : Colors.white,
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
                            StatNumber(value: '${profile.postCount}', label: '게시물', subColor: sub),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => context.push(
                                '${AppRoutes.userProfile}/${profile.id}/followers',
                                extra: profile.username,
                              ),
                              child: StatNumber(value: '${profile.followerCount}', label: '팔로워', subColor: sub),
                            ),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => context.push(
                                '${AppRoutes.userProfile}/${profile.id}/following',
                                extra: profile.username,
                              ),
                              child: StatNumber(value: '${profile.followingCount}', label: '팔로잉', subColor: sub),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(profile.username, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      const SizedBox(width: 6),
                      if (profile.isLunkerClub) const _LunkerBadge(),
                      const Spacer(),
                      FutureBuilder<PackageInfo>(
                        future: PackageInfo.fromPlatform(),
                        builder: (_, snap) {
                          if (!snap.hasData) return const SizedBox();
                          final versionText = Text('v${snap.data!.version}', style: TextStyle(fontSize: 11, color: sub));
                          if (!kDebugMode) return versionText;
                          return GestureDetector(
                            onLongPress: () => context.push(AppRoutes.widgetCatalog),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('v${snap.data!.version} DEV', style: TextStyle(fontSize: 11, color: AppColors.warning)),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('@${profile.userKey}', style: TextStyle(fontSize: 12, color: sub)),
                  ),
                  const SizedBox(height: 14),
                  // 버튼
                  Row(children: [
                    Expanded(child: OutlinedButton(
                      onPressed: () => context.push(AppRoutes.profileEdit, extra: profile),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        padding: EdgeInsets.zero,
                        side: BorderSide(color: context.isDark ? AppColors.darkSurface2 : AppColors.lightDivider),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text('프로필 수정', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.isDark ? Colors.white : Colors.black)),
                    )),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(36, 36),
                        padding: EdgeInsets.zero,
                        side: BorderSide(color: context.isDark ? AppColors.darkSurface2 : AppColors.lightDivider),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Icon(LucideIcons.userPlus, size: 18, color: context.isDark ? Colors.white : Colors.black),
                    ),
                  ]),
                  const SizedBox(height: 16),

                  ScoreCard(
                    label: '리그 점수',
                    icon: LucideIcons.trophy,
                    score: profile.leagueScore,
                    isDark: context.isDark,
                    accent: context.accentColor,
                  ),
                  const SizedBox(height: 8),
                  ScoreCard(
                    label: '앵글러 점수',
                    icon: LucideIcons.star,
                    score: profile.anglerScore,
                    isDark: context.isDark,
                    accent: context.accentColor,
                  ),
                  const SizedBox(height: 10),

                  // 런커 기록
                  if (profile.maxFishPost != null)
                    AppCard(
                      variant: AppCardVariant.tinted,
                      tintColor: AppColors.gold,
                      tintAlpha: 0.05,
                      borderColor: AppColors.gold.withValues(alpha: 0.2),
                      radius: 14,
                      padding: const EdgeInsets.all(14),
                      child: Row(children: [
                        Icon(LucideIcons.award, size: 32, color: AppColors.gold),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('역대 최대어', style: TextStyle(fontSize: 11, color: sub)),
                            Text(
                              '${profile.maxFishPost!.fishType} ${profile.maxFishPost!.length!.toStringAsFixed(1)}cm',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.gold),
                            ),
                            Text(
                              '${DateFormat('yyyy.MM.dd').format(profile.maxFishPost!.createdAt)}'
                              '${profile.maxFishPost!.location != null && profile.maxFishPost!.location!.isNotEmpty ? " · ${profile.maxFishPost!.location}" : ""}',
                              style: TextStyle(fontSize: 11, color: sub),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ]),
                        ),
                        const SizedBox(width: 8),
                        Column(children: [
                          Icon(LucideIcons.checkCircle, color: AppColors.gold, size: 16),
                          const SizedBox(height: 2),
                          const Text('인증', style: TextStyle(fontSize: 10, color: AppColors.gold)),
                        ]),
                      ]),
                    ),
                  const SizedBox(height: 10),

                  // 통계 4칸
                  Row(children: [
                    StatBox(icon: LucideIcons.waves, value: '${profile.participationCount}', label: '리그참가', isDark: context.isDark, accent: context.accentColor),
                    const SizedBox(width: 8),
                    StatBox(icon: LucideIcons.medal, value: '${profile.winCount}', label: '우승', isDark: context.isDark, accent: context.accentColor),
                    const SizedBox(width: 8),
                    StatBox(icon: LucideIcons.fish, value: '${profile.lunkerCount}', label: '런커', isDark: context.isDark, accent: context.accentColor),
                    const SizedBox(width: 8),
                    StatBox(icon: LucideIcons.heart, value: '${profile.totalLikesReceived}', label: '받은좋아요', isDark: context.isDark, accent: context.accentColor),
                  ]),
                  const SizedBox(height: 6),

                  // 탭
                  TabBar(
                    controller: _tab,
                    indicatorSize: TabBarIndicatorSize.tab,
                    tabs: const [
                      Tab(icon: Icon(LucideIcons.layoutGrid, size: 20)),
                      Tab(icon: Icon(LucideIcons.shoppingBag, size: 20)),
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
                _Grid(isDark: context.isDark),
                _MyMarketplace(isDark: context.isDark, accent: context.accentColor, sub: sub, cardBg: cardBg),
              ],
            ),
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
                CachedNetworkImage(
                  imageUrl: post.imageUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    color: isDark ? AppColors.darkSurface2 : AppColors.lightDivider,
                    child: Icon(LucideIcons.image, size: 24, color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFA1A1AA)),
                  ),
                ),
                if (post.videoUrl != null)
                  const Positioned(
                    top: 6, right: 6,
                    child: Icon(Icons.videocam, color: Colors.white, size: 16, shadows: [
                      Shadow(color: Colors.black54, blurRadius: 4),
                    ]),
                  )
                else if ((post.imageUrls?.length ?? 0) > 1)
                  const Positioned(
                    top: 6, right: 6,
                    child: Icon(Icons.filter_none, color: Colors.white, size: 16, shadows: [
                      Shadow(color: Colors.black54, blurRadius: 4),
                    ]),
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

class _MyMarketplace extends ConsumerWidget {
  const _MyMarketplace({required this.isDark, required this.accent, required this.sub, required this.cardBg});
  final bool isDark;
  final Color accent, sub, cardBg;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(myMarketplaceItemsProvider).when(
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(LucideIcons.shoppingBag, size: 48, color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFA1A1AA)),
              const SizedBox(height: 12),
              Text('등록한 중고거래 상품이 없어요', style: TextStyle(color: sub, fontSize: 14)),
            ]),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (_, i) {
            final item = items[i];
            final statusColor = item.isSelling ? accent : sub;

            return GestureDetector(
              onTap: () => context.push('/marketplace/${item.id}', extra: item),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppColors.darkSurface2 : AppColors.lightDivider,
                  ),
                ),
                child: Row(children: [
                  // 썸네일
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 52, height: 52,
                      child: item.imageUrls.isNotEmpty
                          ? Image.network(
                              item.imageUrls.first,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: isDark ? AppColors.darkSurface2 : AppColors.lightBg,
                                child: Icon(LucideIcons.image, size: 18, color: sub),
                              ),
                            )
                          : Container(
                              color: isDark ? AppColors.darkSurface2 : AppColors.lightBg,
                              child: Icon(LucideIcons.image, size: 18, color: sub),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(item.formattedPrice, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: isDark ? AppColors.neonGreen : AppColors.navy)),
                  ])),
                  // 판매중이 아니면 상태 배지 (예약중/판매완료)
                  if (!item.isSelling)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(item.statusLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor)),
                    ),
                ]),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('불러오기 실패', style: TextStyle(color: sub))),
    );
  }
}

