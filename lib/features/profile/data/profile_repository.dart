import 'dart:async';
import 'dart:io';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../feed/data/post_model.dart';

part 'profile_repository.g.dart';

class UserProfile {
  final String id;
  final String email;
  final String username;
  final String? avatarUrl;
  final double mannerTemperature;
  final bool isLunkerClub;
  final int postCount;
  final int lunkerCount;
  final double? maxFishLength;
  final int leagueScore;   // 리그 참가 누적 점수
  final int anglerScore;   // 개인기록 누적 점수

  UserProfile({
    required this.id,
    required this.email,
    required this.username,
    this.avatarUrl,
    required this.mannerTemperature,
    required this.isLunkerClub,
    this.postCount = 0,
    this.lunkerCount = 0,
    this.maxFishLength,
    this.leagueScore = 0,
    this.anglerScore = 0,
  });
}

class ProfileRepository {
  final SupabaseClient _supabase;

  ProfileRepository(this._supabase);

  Future<int> _fetchLeagueScore(String userId) async {
    final seasonStart = '${DateTime.now().year}-01-01T00:00:00';
    final seasonEnd   = '${DateTime.now().year + 1}-01-01T00:00:00';

    final results = await Future.wait([
      // 조과 점수
      _supabase
          .from('posts')
          .select('score')
          .eq('user_id', userId)
          .not('league_id', 'is', null)
          .gte('created_at', seasonStart)
          .lt('created_at', seasonEnd)
          .or('is_deleted.is.null,is_deleted.eq.false'),
      // 순위 보너스 (올해 종료된 리그)
      _supabase
          .from('league_participants')
          .select('rank_bonus')
          .eq('user_id', userId)
          .gte('rank_bonus_earned_at', seasonStart)
          .lt('rank_bonus_earned_at', seasonEnd),
    ]);

    final catchScore = (results[0] as List)
        .fold<int>(0, (s, r) => s + ((r['score'] as int?) ?? 0));
    final rankBonus = (results[1] as List)
        .fold<int>(0, (s, r) => s + ((r['rank_bonus'] as int?) ?? 0));
    return catchScore + rankBonus;
  }

  Future<int> _fetchAnglerScore(String userId) async {
    final seasonStart = '${DateTime.now().year}-01-01T00:00:00';
    final seasonEnd   = '${DateTime.now().year + 1}-01-01T00:00:00';
    final res = await _supabase
        .from('posts')
        .select('score')
        .eq('user_id', userId)
        .eq('is_personal_record', true)
        .gte('created_at', seasonStart)
        .lt('created_at', seasonEnd)
        .or('is_deleted.is.null,is_deleted.eq.false');
    return (res as List).fold<int>(0, (sum, row) => sum + ((row['score'] as int?) ?? 0));
  }

  /// posts는 myPostsProvider에서 이미 받아온 것을 재사용 — users만 조회
  Future<UserProfile> buildMyProfileFromPosts(List<Post> posts) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in');

    final userRes = await _supabase
        .from('users')
        .select('id, email, username, avatar_url, manner_temperature, is_lunker_club')
        .eq('id', userId)
        .single();
    final scores = await Future.wait([_fetchLeagueScore(userId), _fetchAnglerScore(userId)]);

    return _buildUserProfile(
      userRes: userRes,
      posts: posts,
      leagueScore: scores[0],
      anglerScore: scores[1],
    );
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
        .select('id, user_id, league_id, image_url, image_urls, aspect_ratio, video_url, caption, fish_type, length, weight, catch_count, is_lunker, is_personal_record, location, created_at, users(username, avatar_url)')
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
        .select('id, user_id, league_id, image_url, image_urls, aspect_ratio, video_url, caption, fish_type, length, weight, catch_count, is_lunker, is_personal_record, location, created_at, users(username, avatar_url)')
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

  /// posts는 userPostsProvider에서 이미 받아온 것을 재사용 — users만 조회
  Future<UserProfile> buildUserProfileFromPosts(String userId, List<Post> posts) async {
    final userRes = await _supabase
        .from('users')
        .select('id, email, username, avatar_url, manner_temperature, is_lunker_club')
        .eq('id', userId)
        .single();
    final scores = await Future.wait([_fetchLeagueScore(userId), _fetchAnglerScore(userId)]);

    return _buildUserProfile(
      userRes: userRes,
      posts: posts,
      emailFallback: '',
      leagueScore: scores[0],
      anglerScore: scores[1],
    );
  }

  UserProfile _buildUserProfile({
    required Map<String, dynamic> userRes,
    required List<Post> posts,
    String emailFallback = '',
    int leagueScore = 0,
    int anglerScore = 0,
  }) {
    int lunkerCount = 0;
    double? maxLen;
    for (final post in posts) {
      if (post.isLunker) lunkerCount++;
      if (post.length != null) {
        final len = post.length!;
        if (maxLen == null || len > maxLen) maxLen = len;
      }
    }
    return UserProfile(
      id: userRes['id'],
      email: userRes['email'] ?? emailFallback,
      username: userRes['username'],
      avatarUrl: userRes['avatar_url'],
      mannerTemperature: (userRes['manner_temperature'] as num).toDouble(),
      isLunkerClub: userRes['is_lunker_club'] ?? false,
      postCount: posts.length,
      lunkerCount: lunkerCount,
      maxFishLength: maxLen,
      leagueScore: leagueScore,
      anglerScore: anglerScore,
    );
  }

  Future<List<Post>> getUserPosts(String userId) async {
    final response = await _supabase
        .from('posts')
        .select(
          'id, user_id, league_id, image_url, image_urls, aspect_ratio, video_url, caption, '
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
  final link = ref.keepAlive();
  Timer(const Duration(minutes: 3), link.close);
  // myPosts는 이미 Riverpod이 캐싱 — posts DB 호출 1회로 통계+목록 모두 처리
  final posts = await ref.watch(myPostsProvider.future);
  return ref.watch(profileRepositoryProvider).buildMyProfileFromPosts(posts);
}

@riverpod
Future<List<Post>> myPosts(MyPostsRef ref) {
  return ref.watch(profileRepositoryProvider).getMyPosts();
}

@riverpod
Future<List<Post>> myPersonalRecords(MyPersonalRecordsRef ref) {
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
  return ref.watch(profileRepositoryProvider).getUserPosts(userId);
}
