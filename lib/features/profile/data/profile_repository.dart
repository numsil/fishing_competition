import 'dart:async';
import 'dart:io';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/data/auth_repository.dart';
import '../../feed/data/post_model.dart';

part 'profile_repository.g.dart';

class UserProfile {
  final String id;
  // 본인 프로필일 때만 채워짐 (auth.currentUser.email). 다른 유저 프로필은 null.
  // users.email 컬럼은 anon/authenticated 가 SELECT 할 수 없도록 잠겨있음.
  final String? email;
  final String username;
  final String userKey;
  final String? avatarUrl;
  final double mannerTemperature;
  final bool isLunkerClub;
  final int postCount;
  final int lunkerCount;
  final double? maxFishLength;
  final Post? maxFishPost;
  final int leagueScore;
  final int anglerScore;
  final int participationCount; // 완료된 리그 참가 수
  final int winCount;           // 우승 횟수 (rank == 1)
  final int followerCount;
  final int followingCount;
  final bool isFollowing; // 현재 로그인 유저가 이 프로필을 팔로우 중인지
  final int totalLikesReceived; // 내 게시물이 받은 총 좋아요 수

  UserProfile({
    required this.id,
    this.email,
    required this.username,
    required this.userKey,
    this.avatarUrl,
    required this.mannerTemperature,
    required this.isLunkerClub,
    this.postCount = 0,
    this.lunkerCount = 0,
    this.maxFishLength,
    this.maxFishPost,
    this.leagueScore = 0,
    this.anglerScore = 0,
    this.participationCount = 0,
    this.winCount = 0,
    this.followerCount = 0,
    this.followingCount = 0,
    this.isFollowing = false,
    this.totalLikesReceived = 0,
  });
}

class ProfileRepository {
  final SupabaseClient _supabase;

  ProfileRepository(this._supabase);

  /// 통합 RPC 호출: user 정보 + 시즌 점수 + 우승/참가 + 최대어 한 번에.
  /// email 은 RPC 응답에 포함되지 않으므로(타인 프로필 PII 차단) 본인일 경우에만
  /// 호출자가 [email] 인자로 전달한다.
  Future<UserProfile> _buildProfileViaRpc(
    String userId,
    List<Post> posts, {
    String? email,
  }) async {
    final res = await _supabase.rpc(
      'get_user_profile_summary',
      params: {'p_user_id': userId},
    );
    if (res == null) throw Exception('User not found');
    final data = res as Map<String, dynamic>;

    Post? maxFishPost;
    final maxFishData = data['max_fish'] as Map<String, dynamic>?;
    if (maxFishData != null) {
      maxFishPost = Post.fromJson({
        ...maxFishData,
        'user_id': userId,
      });
    }

    return UserProfile(
      id: data['id'] as String,
      email: email,
      username: data['username'] as String,
      userKey: (data['user_key'] as String?) ?? (data['username'] as String),
      avatarUrl: data['avatar_url'] as String?,
      mannerTemperature: (data['manner_temperature'] as num).toDouble(),
      isLunkerClub: (data['is_lunker_club'] as bool?) ?? false,
      postCount: posts.length,
      lunkerCount: (data['lunker_count'] as num?)?.toInt() ?? 0,
      maxFishLength: maxFishPost?.length,
      maxFishPost: maxFishPost,
      leagueScore: (data['league_score'] as num?)?.toInt() ?? 0,
      anglerScore: (data['angler_score'] as num?)?.toInt() ?? 0,
      participationCount: (data['participation_count'] as num?)?.toInt() ?? 0,
      winCount: (data['win_count'] as num?)?.toInt() ?? 0,
      followerCount: (data['follower_count'] as num?)?.toInt() ?? 0,
      followingCount: (data['following_count'] as num?)?.toInt() ?? 0,
      isFollowing: (data['is_following'] as bool?) ?? false,
      totalLikesReceived: (data['total_likes_received'] as num?)?.toInt() ?? 0,
    );
  }

  /// posts는 myPostsProvider에서 이미 받아온 것을 재사용 — RPC로 통계 일괄 조회
  Future<UserProfile> buildMyProfileFromPosts(List<Post> posts) async {
    final me = _supabase.auth.currentUser;
    if (me == null) throw Exception('Not logged in');
    return _buildProfileViaRpc(me.id, posts, email: me.email);
  }

  Future<bool> isUserKeyAvailable(String userKey) async {
    final userId = _supabase.auth.currentUser?.id;
    final existing = await _supabase
        .from('users')
        .select('id')
        .eq('user_key', userKey)
        .neq('id', userId ?? '')
        .maybeSingle();
    return existing == null;
  }

  Future<void> updateProfile({String? username, String? userKey}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in');

    final updates = <String, dynamic>{};
    if (username != null) updates['username'] = username;
    if (userKey != null) updates['user_key'] = userKey;
    if (updates.isEmpty) return;

    await _supabase.from('users').update(updates).eq('id', userId);
  }

  Future<String> uploadAvatar(File imageFile) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in');

    final ext = imageFile.path.split('.').last.toLowerCase();
    final storagePath = '$userId/avatar.$ext';

    await _supabase.storage.from('avatars').upload(
      storagePath,
      imageFile,
      fileOptions: FileOptions(
        contentType: 'image/$ext',
        upsert: true,
      ),
    );

    final url = _supabase.storage.from('avatars').getPublicUrl(storagePath);

    await _supabase
        .from('users')
        .update({'avatar_url': url})
        .eq('id', userId);

    return url;
  }

  Future<List<Post>> getMyPosts() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in');

    final response = await _supabase
        .from('posts')
        .select('id, user_id, league_id, image_url, image_urls, media, aspect_ratio, video_url, youtube_url, caption, fish_type, length, weight, catch_count, is_lunker, is_personal_record, location, created_at, users(username, avatar_url)')
        .eq('user_id', userId)
        .isFilter('league_id', null)
        .eq('is_personal_record', false)
        .or('is_deleted.is.null,is_deleted.eq.false')
        .order('created_at', ascending: false);

    return response.map((data) => _mapPost(data)).toList();
  }

  Future<List<Post>> getMyPersonalRecords() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in');

    final response = await _supabase
        .from('posts')
        .select('id, user_id, league_id, image_url, image_urls, media, aspect_ratio, video_url, youtube_url, caption, fish_type, length, weight, catch_count, is_lunker, is_personal_record, review_status, location, created_at, users(username, avatar_url)')
        .eq('user_id', userId)
        .isFilter('league_id', null)
        .eq('is_personal_record', true)
        .or('is_deleted.is.null,is_deleted.eq.false')
        .order('created_at', ascending: false);

    return response.map((data) => _mapPost(data)).toList();
  }

  Post _mapPost(Map<String, dynamic> data) {
    final post = Post.fromJson(data);
    final usersData = data['users'];
    final String username = (usersData != null && usersData is Map)
        ? usersData['username'] ?? 'Unknown'
        : 'Unknown';
    final String avatarUrl = (usersData != null && usersData is Map)
        ? usersData['avatar_url'] ?? ''
        : '';
    return post.copyWith(username: username, avatarUrl: avatarUrl);
  }

  /// posts는 userPostsProvider에서 이미 받아온 것을 재사용
  Future<UserProfile> buildUserProfileFromPosts(String userId, List<Post> posts) {
    return _buildProfileViaRpc(userId, posts);
  }

  Future<List<Post>> getUserPosts(String userId) async {
    final response = await _supabase
        .from('posts')
        .select(
          'id, user_id, league_id, image_url, image_urls, media, aspect_ratio, video_url, youtube_url, caption, '
          'fish_type, length, location, is_lunker, is_personal_record, '
          'created_at, users(username, avatar_url)',
        )
        .eq('user_id', userId)
        .isFilter('league_id', null)
        .eq('is_personal_record', false)
        .or('is_deleted.is.null,is_deleted.eq.false')
        .order('created_at', ascending: false);

    return response.map((data) => _mapPost(data)).toList();
  }
}

@riverpod
ProfileRepository profileRepository(ProfileRepositoryRef ref) {
  return ProfileRepository(Supabase.instance.client);
}

@riverpod
Future<UserProfile> myProfile(MyProfileRef ref) async {
  // 로그인/로그아웃 시만 자동 재빌드 (TOKEN_REFRESHED는 무시)
  ref.watch(authStateProvider.select(
    (async) => async.valueOrNull?.session?.user.id,
  ));
  final link = ref.keepAlive();
  Timer(const Duration(minutes: 3), link.close);
  final posts = await ref.watch(myPostsProvider.future);
  return ref.watch(profileRepositoryProvider).buildMyProfileFromPosts(posts);
}

@riverpod
Future<List<Post>> myPosts(MyPostsRef ref) {
  final link = ref.keepAlive();
  Timer(const Duration(minutes: 5), link.close);
  return ref.watch(profileRepositoryProvider).getMyPosts();
}

@riverpod
Future<List<Post>> myPersonalRecords(MyPersonalRecordsRef ref) {
  final link = ref.keepAlive();
  Timer(const Duration(minutes: 5), link.close);
  return ref.watch(profileRepositoryProvider).getMyPersonalRecords();
}

@riverpod
Future<UserProfile> userProfile(UserProfileRef ref, String userId) async {
  final link = ref.keepAlive();
  Timer(const Duration(minutes: 3), link.close);
  // userPosts는 이미 Riverpod이 캐싱 — posts DB 호출 1회로 통계+목록 모두 처리
  final posts = await ref.watch(userPostsProvider(userId).future);
  return ref.watch(profileRepositoryProvider).buildUserProfileFromPosts(userId, posts);
}

@riverpod
Future<List<Post>> userPosts(UserPostsRef ref, String userId) {
  final link = ref.keepAlive();
  Timer(const Duration(minutes: 5), link.close);
  return ref.watch(profileRepositoryProvider).getUserPosts(userId);
}
