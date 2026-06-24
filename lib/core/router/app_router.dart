import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/auth/presentation/screens/password_change_email_screen.dart';
import '../../features/auth/presentation/screens/password_change_otp_screen.dart';
import '../../features/feed/presentation/screens/feed_screen.dart';
import '../../features/league/presentation/screens/league_screen.dart';
import '../../features/league/presentation/screens/league_detail_screen.dart';
import '../../features/league/presentation/screens/league_create_screen.dart';
import '../../features/league/presentation/screens/league_manage_screen.dart';
import '../../features/my_league/presentation/screens/my_league_screen.dart';
import '../../features/my_league/presentation/screens/my_league_detail_screen.dart';
import '../../features/my_league/presentation/screens/personal_catch_screen.dart';
import '../../features/my_league/presentation/screens/personal_record_detail_screen.dart';
import '../../features/my_league/presentation/screens/album_bundle_share_screen.dart';
import '../../features/feed/data/post_model.dart';
import '../../features/feed/presentation/screens/post_detail_screen.dart';
import '../../features/feed/presentation/screens/post_detail_loader_screen.dart';
import '../../features/upload/presentation/screens/upload_screen.dart';
import '../../features/ranking/presentation/screens/ranking_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/league/presentation/screens/league_participant_detail_screen.dart';
import '../../features/profile/presentation/screens/user_profile_screen.dart';
import '../../features/profile/presentation/screens/profile_edit_screen.dart';
import '../../features/profile/presentation/screens/blocked_users_screen.dart';
import '../../features/profile/data/profile_repository.dart';
import '../../features/follow/presentation/screens/follow_list_screen.dart';
import '../../features/legal/presentation/screens/legal_document_screen.dart';
import '../../features/dm/data/dm_repository.dart';
import '../../features/dm/presentation/screens/dm_list_screen.dart';
import '../../features/dm/presentation/screens/dm_chat_screen.dart';
import '../../features/marketplace/data/marketplace_model.dart';
import '../../features/marketplace/presentation/screens/marketplace_detail_screen.dart';
import '../../features/notifications/presentation/screens/notification_screen.dart';
import '../../features/units/presentation/screens/units_unit_screen.dart';
import '../presentation/screens/main_screen.dart';
import '../presentation/screens/splash_screen.dart';
import '../../dev/widget_catalog_screen.dart';

part 'app_router.g.dart';

@riverpod
GoRouter appRouter(Ref ref) {
  // 로그아웃 후 ProviderScope 재시작 시 유저가 없으면 splash 생략하고 바로 로그인
  final hasUser = Supabase.instance.client.auth.currentUser != null;
  return GoRouter(
    initialLocation: hasUser ? AppRoutes.splash : AppRoutes.login,
    debugLogDiagnostics: true,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      if (kDebugMode)
        GoRoute(
          path: AppRoutes.widgetCatalog,
          builder: (context, state) => const WidgetCatalogScreen(),
        ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: AppRoutes.passwordChange,
        builder: (context, state) => const PasswordChangeEmailScreen(),
      ),
      GoRoute(
        path: AppRoutes.passwordChangeOtp,
        builder: (context, state) =>
            PasswordChangeOtpScreen(email: state.extra as String),
      ),
      GoRoute(
        path: AppRoutes.terms,
        builder: (context, state) =>
            const LegalDocumentScreen(type: LegalDocType.terms),
      ),
      GoRoute(
        path: AppRoutes.privacy,
        builder: (context, state) =>
            const LegalDocumentScreen(type: LegalDocType.privacy),
      ),
      GoRoute(
        path: AppRoutes.blockedUsers,
        builder: (context, state) => const BlockedUsersScreen(),
      ),
      // 피드 상세: ShellRoute 밖 → 하단 탭 없음
      GoRoute(
        path: AppRoutes.postDetail,
        pageBuilder: (context, state) {
          final post = state.extra as dynamic;
          return MaterialPage(child: PostDetailScreen(post: post));
        },
      ),
      // 피드 상세 딥링크 진입: /post/:id (extra 없이 ID로 fetch)
      GoRoute(
        path: '${AppRoutes.postDetail}/:id',
        pageBuilder: (context, state) => MaterialPage(
          child: PostDetailLoaderScreen(
            postId: state.pathParameters['id']!,
          ),
        ),
      ),
      // 업로드: ShellRoute 밖 → 하단 탭 없는 풀스크린
      GoRoute(
        path: AppRoutes.upload,
        pageBuilder: (context, state) {
          final editPost = state.extra is Post ? state.extra as Post : null;
          return MaterialPage(
            fullscreenDialog: true,
            child: UploadScreen(editPost: editPost),
          );
        },
      ),
      // 개인 기록 조과 촬영: 풀스크린
      GoRoute(
        path: AppRoutes.personalCatch,
        pageBuilder: (context, state) {
          final initialImage = state.extra is File ? state.extra as File : null;
          return MaterialPage(
            fullscreenDialog: true,
            child: PersonalCatchScreen(initialImage: initialImage),
          );
        },
      ),
      // 개인 기록 갤러리 상세
      GoRoute(
        path: AppRoutes.personalRecordDetail,
        pageBuilder: (context, state) {
          final post = state.extra as dynamic;
          return MaterialPage(child: PersonalRecordDetailScreen(post: post));
        },
      ),
      // 조과 앨범 묶음 피드 등록
      GoRoute(
        path: AppRoutes.albumBundleShare,
        pageBuilder: (context, state) {
          final posts = (state.extra as List).cast<Post>();
          return MaterialPage(child: AlbumBundleShareScreen(posts: posts));
        },
      ),
      // 중고거래 상세: ShellRoute 밖 → 하단 탭 없음
      GoRoute(
        path: '/marketplace/:id',
        pageBuilder: (context, state) => MaterialPage(
          child: MarketplaceDetailScreen(
            item: state.extra as MarketplaceItem,
          ),
        ),
      ),
      // 단위 변환: ShellRoute 밖 → 하단 탭 없음
      GoRoute(
        path: AppRoutes.units,
        pageBuilder: (context, state) =>
            const MaterialPage(child: UnitsScreen()),
      ),
      // DM 목록: ShellRoute 밖 → 하단 탭 없음
      GoRoute(
        path: AppRoutes.dm,
        pageBuilder: (context, state) => const MaterialPage(child: DmListScreen()),
      ),
      // 알림함: ShellRoute 밖 → 하단 탭 없음
      GoRoute(
        path: AppRoutes.notifications,
        builder: (context, state) => const NotificationScreen(),
      ),
      // DM 채팅: ShellRoute 밖 → 하단 탭 없음
      GoRoute(
        path: AppRoutes.dmChat,
        pageBuilder: (context, state) {
          final conv = state.extra as DmConversation;
          return MaterialPage(child: DmChatScreen(conversation: conv));
        },
      ),
      // 프로필 수정: ShellRoute 밖 → 하단 탭 없음
      GoRoute(
        path: AppRoutes.profileEdit,
        pageBuilder: (context, state) {
          final profile = state.extra as UserProfile;
          return MaterialPage(child: ProfileEditScreen(profile: profile));
        },
      ),
      // 다른 유저 프로필: ShellRoute 밖 → 하단 탭 없음
      GoRoute(
        path: '/user/:userId',
        pageBuilder: (context, state) => MaterialPage(
          child: UserProfileScreen(
            userId: state.pathParameters['userId']!,
          ),
        ),
      ),
      // 팔로워 목록
      GoRoute(
        path: '/user/:userId/followers',
        pageBuilder: (context, state) => MaterialPage(
          child: FollowListScreen(
            userId: state.pathParameters['userId']!,
            type: FollowListType.followers,
            username: state.extra is String ? state.extra as String : null,
          ),
        ),
      ),
      // 팔로잉 목록
      GoRoute(
        path: '/user/:userId/following',
        pageBuilder: (context, state) => MaterialPage(
          child: FollowListScreen(
            userId: state.pathParameters['userId']!,
            type: FollowListType.following,
            username: state.extra is String ? state.extra as String : null,
          ),
        ),
      ),
      // 리그 참가자 상세: ShellRoute 밖 → 하단 탭 없음
      GoRoute(
        path: '/league/participant/:leagueId/:userId',
        pageBuilder: (context, state) {
          final args = state.extra as LeagueParticipantArgs;
          return MaterialPage(
            child: LeagueParticipantDetailScreen(
              leagueId: state.pathParameters['leagueId']!,
              userId: state.pathParameters['userId']!,
              entry: args.entry,
              rule: args.rule,
              catchLimit: args.catchLimit,
              rank: args.rank,
            ),
          );
        },
      ),
      // 리그 관리: ShellRoute 밖 → 하단 탭 없음
      GoRoute(
        path: '${AppRoutes.league}/manage/:id',
        pageBuilder: (context, state) => MaterialPage(
          child: LeagueManageScreen(
            leagueId: state.pathParameters['id']!,
          ),
        ),
      ),
      // 나의 리그 상세: ShellRoute 밖 → 하단 탭 없음
      GoRoute(
        path: '${AppRoutes.myLeague}/detail/:id',
        pageBuilder: (context, state) => MaterialPage(
          child: MyLeagueDetailScreen(
            leagueId: state.pathParameters['id']!,
            type: state.uri.queryParameters['type'] ?? 'live',
          ),
        ),
      ),
      ShellRoute(
        builder: (context, state, child) => MainScreen(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.feed,
            builder: (context, state) => const FeedScreen(),
          ),
          GoRoute(
            path: AppRoutes.league,
            builder: (context, state) => const LeagueScreen(),
            routes: [
              GoRoute(
                path: 'detail/:id',
                builder: (context, state) => LeagueDetailScreen(
                  leagueId: state.pathParameters['id']!,
                ),
              ),
              GoRoute(
                path: 'create',
                builder: (context, state) => const LeagueCreateScreen(),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.myLeague,
            builder: (context, state) => const MyLeagueScreen(),
          ),
          GoRoute(
            path: AppRoutes.ranking,
            builder: (context, state) => const RankingScreen(),
          ),
          GoRoute(
            path: AppRoutes.profile,
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
    ],
  );
}

class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String feed = '/feed';
  static const String league = '/league';
  static const String myLeague = '/my-league';
  static const String myLeagueDetail = '/my-league/detail';
  static const String leagueManage = '/league/manage';
  static const String upload = '/upload';
  static const String personalCatch = '/personal-catch';
  static const String personalRecordDetail = '/personal-record';
  static const String ranking = '/ranking';
  static const String profile = '/profile';
  static const String profileEdit = '/profile/edit';
  static const String postDetail = '/post';
  static const String userProfile = '/user';
  static const String dm = '/dm';
  static const String notifications = '/notifications';
  static const String units = '/units';
  static const String dmChat = '/dm/chat';
  static const String albumBundleShare = '/album-bundle-share';
  static const String widgetCatalog = '/widget-catalog';
  static const String terms = '/legal/terms';
  static const String privacy = '/legal/privacy';
  static const String passwordChange = '/password-change';
  static const String passwordChangeOtp = '/password-change/otp';
  static const String blockedUsers = '/profile/blocked-users';
}
