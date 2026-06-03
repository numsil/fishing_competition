import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'follow_repository.g.dart';

class FollowUser {
  final String userId;
  final String username;
  final String userKey;
  final String? avatarUrl;
  final bool isLunkerClub;
  final bool isFollowing; // 현재 로그인 유저가 이 사람을 팔로우 중인지
  final DateTime followedAt;
  final int maxScore; // 피드 바 티어 테두리용: max(league_score, angler_score)
  final DateTime? lastPostAt; // 가장 최근 피드 게시 시각 (정렬용)

  FollowUser({
    required this.userId,
    required this.username,
    required this.userKey,
    this.avatarUrl,
    required this.isLunkerClub,
    required this.isFollowing,
    required this.followedAt,
    this.maxScore = 0,
    this.lastPostAt,
  });

  factory FollowUser.fromJson(Map<String, dynamic> json) {
    final lastPostAtRaw = json['last_post_at'] as String?;
    return FollowUser(
      userId: json['user_id'] as String,
      username: json['username'] as String,
      userKey: (json['user_key'] as String?) ?? (json['username'] as String),
      avatarUrl: json['avatar_url'] as String?,
      isLunkerClub: (json['is_lunker_club'] as bool?) ?? false,
      isFollowing: (json['is_following'] as bool?) ?? false,
      followedAt: DateTime.parse(json['followed_at'] as String).toLocal(),
      maxScore: (json['max_score'] as num?)?.toInt() ?? 0,
      lastPostAt: lastPostAtRaw != null ? DateTime.parse(lastPostAtRaw).toLocal() : null,
    );
  }

  FollowUser copyWith({bool? isFollowing}) {
    return FollowUser(
      userId: userId,
      username: username,
      userKey: userKey,
      avatarUrl: avatarUrl,
      isLunkerClub: isLunkerClub,
      isFollowing: isFollowing ?? this.isFollowing,
      followedAt: followedAt,
      maxScore: maxScore,
      lastPostAt: lastPostAt,
    );
  }
}

class FollowRepository {
  final SupabaseClient _supabase;
  FollowRepository(this._supabase);

  Future<void> follow(String followeeId) async {
    final me = _supabase.auth.currentUser?.id;
    if (me == null) throw Exception('Not logged in');
    if (me == followeeId) throw Exception('Cannot follow self');
    // upsert + ignoreDuplicates: 동시 클릭/다중 디바이스 race condition에서
    // PK unique violation 방지 (이미 팔로우 상태면 no-op)
    await _supabase.from('follows').upsert(
      {
        'follower_id': me,
        'followee_id': followeeId,
      },
      ignoreDuplicates: true,
    );
  }

  Future<void> unfollow(String followeeId) async {
    final me = _supabase.auth.currentUser?.id;
    if (me == null) throw Exception('Not logged in');
    await _supabase
        .from('follows')
        .delete()
        .eq('follower_id', me)
        .eq('followee_id', followeeId);
  }

  Future<List<FollowUser>> getFollowers(
    String userId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final res = await _supabase.rpc('get_followers', params: {
      'p_user_id': userId,
      'p_limit': limit,
      'p_offset': offset,
    });
    return (res as List)
        .map((e) => FollowUser.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<FollowUser>> getFollowing(
    String userId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final res = await _supabase.rpc('get_following', params: {
      'p_user_id': userId,
      'p_limit': limit,
      'p_offset': offset,
    });
    return (res as List)
        .map((e) => FollowUser.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 피드 상단 바 전용: 팔로잉 + 시즌 max_score 포함.
  Future<List<FollowUser>> getFollowingWithScore(
    String userId, {
    int limit = 100,
  }) async {
    final res = await _supabase.rpc('get_following_with_max_score', params: {
      'p_user_id': userId,
      'p_limit': limit,
    });
    return (res as List)
        .map((e) => FollowUser.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

@riverpod
FollowRepository followRepository(FollowRepositoryRef ref) {
  return FollowRepository(Supabase.instance.client);
}

/// 피드 상단 팔로우 바 용 — 내가 팔로우한 유저 최대 100명을 캐시.
/// keepAlive 10분: 위젯이 자체 Timer로 셔플하니 잦은 재페치 불필요.
@riverpod
Future<List<FollowUser>> myFollowingsForFeed(
  MyFollowingsForFeedRef ref,
) async {
  final link = ref.keepAlive();
  Timer(const Duration(minutes: 10), link.close);
  final myId = Supabase.instance.client.auth.currentUser?.id;
  if (myId == null) return [];
  return ref.read(followRepositoryProvider).getFollowingWithScore(myId, limit: 100);
}
