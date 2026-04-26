import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/feed/presentation/screens/feed_screen.dart';
import '../../features/league/presentation/screens/league_screen.dart';
import '../../features/league/presentation/screens/league_detail_screen.dart';
import '../../features/league/presentation/screens/league_create_screen.dart';
import '../../features/league/presentation/screens/league_manage_screen.dart';
import '../../features/my_league/presentation/screens/my_league_screen.dart';
import '../../features/my_league/presentation/screens/my_league_detail_screen.dart';
import '../../features/my_league/presentation/screens/personal_catch_screen.dart';
import '../../features/my_league/presentation/screens/personal_record_detail_screen.dart';
import '../../features/feed/presentation/screens/post_detail_screen.dart';
import '../../features/upload/presentation/screens/upload_screen.dart';
import '../../features/ranking/presentation/screens/ranking_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/league/presentation/screens/league_participant_detail_screen.dart';
import '../../features/profile/presentation/screens/user_profile_screen.dart';
import '../../features/dm/data/dm_repository.dart';
import '../../features/dm/presentation/screens/dm_list_screen.dart';
import '../../features/dm/presentation/screens/dm_chat_screen.dart';
import '../presentation/screens/main_screen.dart';
import '../presentation/screens/splash_screen.dart';

part 'app_router.g.dart';

@riverpod
GoRouter appRouter(Ref ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        builder: (context, state) => const SignupScreen(),
      ),
      // 피드 상세: ShellRoute 밖 → 하단 탭 없음
      GoRoute(
        path: AppRoutes.postDetail,
        pageBuilder: (context, state) {
          final post = state.extra as dynamic;
          return MaterialPage(child: PostDetailScreen(post: post));
        },
      ),
      // 업로드: ShellRoute 밖 → 하단 탭 없는 풀스크린
      GoRoute(
        path: AppRoutes.upload,
        pageBuilder: (context, state) => const MaterialPage(
          fullscreenDialog: true,
          child: UploadScreen(),
        ),
      ),
      // 개인 기록 조과 촬영: 풀스크린
      GoRoute(
        path: AppRoutes.personalCatch,
        pageBuilder: (context, state) => const MaterialPage(
          fullscreenDialog: true,
          child: PersonalCatchScreen(),
        ),
      ),
      // 개인 기록 갤러리 상세
      GoRoute(
        path: AppRoutes.personalRecordDetail,
        pageBuilder: (context, state) {
          final post = state.extra as dynamic;
          return MaterialPage(child: PersonalRecordDetailScreen(post: post));
        },
      ),
      // DM 목록: ShellRoute 밖 → 하단 탭 없음
      GoRoute(
        path: AppRoutes.dm,
        pageBuilder: (context, state) => const MaterialPage(child: DmListScreen()),
      ),
      // DM 채팅: ShellRoute 밖 → 하단 탭 없음
      GoRoute(
        path: AppRoutes.dmChat,
        pageBuilder: (context, state) {
          final conv = state.extra as DmConversation;
          return MaterialPage(child: DmChatScreen(conversation: conv));
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
  static const String postDetail = '/post';
  static const String userProfile = '/user';
  static const String dm = '/dm';
  static const String dmChat = '/dm/chat';
}
