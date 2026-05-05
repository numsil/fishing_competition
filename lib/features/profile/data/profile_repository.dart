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
  final int leagueScore;
  final int anglerScore;
  final int participationCount; // 완료된 리그 참가 수
  final int winCount;           // 우승 횟수 (rank == 1)

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
    this.participationCount = 0,
    this.winCount = 0,
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
          .eq('review_status', 'approved')
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

  Future<Map<String, int>> _fetchLeagueStats(String userId) async {
    final participatedRes = await _supabase
        .from('league_participants')
        .select('league_id, leagues(status, rule, catch_limit)')
        .eq('user_id', userId);

    final completedRows = participatedRes.where((p) {
      final league = p['leagues'] as Map<String, dynamic>?;
      return league?['status'] == 'completed';
    }).toList();

    final participationCount = completedRows.length;
    if (participationCount == 0) return {'winCount': 0, 'participationCount': 0};

    final leagueIds = completedRows.map((p) => p['league_id'] as String).toList();

    List<dynamic> allPosts;
    try {
      allPosts = await _supabase
          .from('posts')
          .select('user_id, league_id, length, weight')
          .inFilter('league_id', leagueIds)
          .or('is_deleted.is.null,is_deleted.eq.false');
    } catch (_) {
      allPosts = await _supabase
          .from('posts')
          .select('user_id, league_id, length')
          .inFilter('league_id', leagueIds)
          .or('is_deleted.is.null,is_deleted.eq.false');
    }

    final allParticipants = await _supabase
        .from('league_participants')
        .select('user_id, league_id')
        .inFilter('league_id', leagueIds);

    final Map<String, Map<String, dynamic>> leagueRules = {};
    for (final p in completedRows) {
      final lid = p['league_id'] as String;
      final d = p['leagues'] as Map<String, dynamic>?;
      leagueRules[lid] = {
        'rule': d?['rule'] as String? ?? '최대어',
        'catchLimit': (d?['catch_limit'] as num?)?.toInt() ?? 1,
      };
    }

    final Map<String, Set<String>> participantMap = {};
    for (final p in allParticipants) {
      final lid = p['league_id'] as String;
      participantMap.putIfAbsent(lid, () => {}).add(p['user_id'] as String);
    }

    final Map<String, Map<String, List<double>>> measuresMap = {};
    for (final lid in leagueIds) {
      measuresMap[lid] = {};
      for (final uid in participantMap[lid] ?? <String>{}) {
        measuresMap[lid]![uid] = [];
      }
    }

    for (final post in allPosts) {
      final lid = post['league_id'] as String;
      final uid = post['user_id'] as String;
      if (measuresMap[lid] == null || !measuresMap[lid]!.containsKey(uid)) continue;
      final rule = leagueRules[lid]?['rule'] as String? ?? '최대어';
      final double? measure;
      if (rule == '무게') {
        measure = post['weight'] != null ? (post['weight'] as num).toDouble() : null;
      } else {
        measure = post['length'] != null ? (post['length'] as num).toDouble() : null;
      }
      if (measure != null) measuresMap[lid]![uid]!.add(measure);
    }

    double calcScore(List<double> vals, String rule, int limit) {
      if (rule == '마릿수') return vals.length.toDouble();
      final sorted = List<double>.from(vals)..sort((a, b) => b.compareTo(a));
      final top = limit > 0 && sorted.length > limit ? sorted.take(limit).toList() : sorted;
      return top.fold(0.0, (s, v) => s + v);
    }

    int winCount = 0;
    for (final lid in leagueIds) {
      final rule = leagueRules[lid]?['rule'] as String? ?? '최대어';
      final limit = leagueRules[lid]?['catchLimit'] as int? ?? 1;
      final userMeasures = measuresMap[lid] ?? {};
      final myScore = calcScore(userMeasures[userId] ?? [], rule, limit);
      final rank = userMeasures.values.where((m) => calcScore(m, rule, limit) > myScore).length + 1;
      if (rank == 1) winCount++;
    }

    return {'winCount': winCount, 'participationCount': participationCount};
  }

  Future<int> _fetchAnglerScore(String userId) async {
    final seasonStart = '${DateTime.now().year}-01-01T00:00:00';
    final seasonEnd   = '${DateTime.now().year + 1}-01-01T00:00:00';
    final res = await _supabase
        .from('posts')
        .select('score')
        .eq('user_id', userId)
        .eq('is_personal_record', true)
        .eq('review_status', 'approved')
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
    final stats = await _fetchLeagueStats(userId);

    return _buildUserProfile(
      userRes: userRes,
      posts: posts,
      leagueScore: scores[0],
      anglerScore: scores[1],
      participationCount: stats['participationCount'] ?? 0,
      winCount: stats['winCount'] ?? 0,
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
        .select('id, user_id, league_id, image_url, image_urls, aspect_ratio, video_url, caption, fish_type, length, weight, catch_count, is_lunker, is_personal_record, review_status, location, created_at, users(username, avatar_url)')
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
    final stats = await _fetchLeagueStats(userId);

    return _buildUserProfile(
      userRes: userRes,
      posts: posts,
      emailFallback: '',
      leagueScore: scores[0],
      anglerScore: scores[1],
      participationCount: stats['participationCount'] ?? 0,
      winCount: stats['winCount'] ?? 0,
    );
  }

  UserProfile _buildUserProfile({
    required Map<String, dynamic> userRes,
    required List<Post> posts,
    String emailFallback = '',
    int leagueScore = 0,
    int anglerScore = 0,
    int participationCount = 0,
    int winCount = 0,
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
      participationCount: participationCount,
      winCount: winCount,
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
