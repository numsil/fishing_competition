import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../feed/data/post_model.dart';
import '../../../core/utils/storage_cleanup.dart';
import 'league_model.dart';

part 'league_repository.g.dart';

const int kLeagueListPageSize = 20;

// ── 순위 항목 모델 ──────────────────────────────────────
class LeagueRankEntry {
  final String userId;
  final String username;
  final String? avatarUrl;
  final double? bestLength;   // 최대어 (cm)
  final double totalLength;   // 합산 길이 (cm)
  final int totalCount;       // 총 마릿수
  final int totalScore;       // 점수 합산
  final int bestScore;        // 단일 최고 점수
  final String fishType;
  final bool isLunker;

  const LeagueRankEntry({
    required this.userId,
    required this.username,
    this.avatarUrl,
    this.bestLength,
    required this.totalLength,
    required this.totalCount,
    required this.totalScore,
    required this.bestScore,
    required this.fishType,
    required this.isLunker,
  });
}

// ── 대기 참가자 모델 ──────────────────────────────────────
class LeaguePendingEntry {
  const LeaguePendingEntry({
    required this.userId,
    required this.username,
    required this.joinedAt,
  });
  final String userId;
  final String username;
  final DateTime joinedAt;
}

class LeagueRepository {
  final SupabaseClient _supabase;

  LeagueRepository(this._supabase);

  Future<List<String>> _uploadIntroImages(
      String hostId, List<XFile> files) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final futures = List.generate(files.length, (i) async {
      final bytes = await files[i].readAsBytes();
      final ext = files[i].path.split('.').last.toLowerCase();
      final path = 'leagues/${hostId}_${ts}_$i.$ext';
      await _supabase.storage.from('league_images').uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(
          contentType: 'image/$ext',
          upsert: false,
        ),
      );
      return _supabase.storage.from('league_images').getPublicUrl(path);
    });
    return Future.wait(futures);
  }

  Future<void> createLeague({
    required String hostId,
    required String title,
    String? description,
    String? shortDescription,
    required String location,
    double? lat,
    double? lng,
    required DateTime startTime,
    required DateTime endTime,
    int entryFee = 0,
    int maxParticipants = 100,
    String fishTypes = '배스',
    String rule = '최대어',
    int catchLimit = 1,
    String? prizeInfo,
    bool isPublic = true,
    bool allowGallery = true,
    List<XFile> introImageFiles = const [],
  }) async {
    final imageUrls = introImageFiles.isNotEmpty
        ? await _uploadIntroImages(hostId, introImageFiles)
        : <String>[];
    await _supabase.from('leagues').insert({
      'host_id': hostId,
      'title': title,
      'description': description,
      if (shortDescription != null) 'short_description': shortDescription,
      'location': location,
      'lat': lat,
      'lng': lng,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'entry_fee': entryFee,
      'max_participants': maxParticipants,
      'status': 'recruiting',
      'fish_types': fishTypes,
      'rule': rule,
      'catch_limit': catchLimit,
      'prize_info': prizeInfo,
      'is_public': isPublic,
      'allow_gallery': allowGallery,
      'intro_image_urls': imageUrls,
    });
  }

  Future<League> getLeague(String id) async {
    final data = await _supabase
        .from('leagues')
        .select(
          'id, host_id, title, description, short_description, location, '
          'lat, lng, start_time, end_time, entry_fee, max_participants, '
          'status, fish_types, rule, catch_limit, prize_info, is_public, '
          'allow_gallery, intro_image_urls, created_at, '
          'league_participants(count), users!host_id(username, avatar_url)',
        )
        .eq('id', id)
        .single();
    final lpData = data['league_participants'];
    final pCount = (lpData is List && lpData.isNotEmpty)
        ? ((lpData[0] as Map)['count'] as int? ?? 0)
        : 0;
    final hostUsername = (data['users'] as Map?)?['username'] as String? ?? '';
    final hostAvatarUrl = (data['users'] as Map?)?['avatar_url'] as String?;
    return League.fromJson(data).copyWith(
      participantsCount: pCount,
      hostUsername: hostUsername,
      hostAvatarUrl: hostAvatarUrl,
    );
  }

  Future<List<League>> getLeagues({
    int limit = kLeagueListPageSize,
    DateTime? before,
  }) async {
    var query = _supabase
        .from('leagues')
        .select('id, host_id, title, short_description, location, status, start_time, end_time, entry_fee, max_participants, created_at, league_participants(count), users!host_id(username)');

    if (before != null) {
      query = query.lt('created_at', before.toUtc().toIso8601String());
    }

    final response = await query
        .order('created_at', ascending: false)
        .limit(limit);

    return response.map((data) {
      int pCount = 0;
      final lp = data['league_participants'];
      if (lp is List && lp.isNotEmpty) {
        pCount = (lp[0] as Map)['count'] as int? ?? 0;
      }
      final hostUsername = (data['users'] as Map?)?['username'] as String? ?? '';
      final hostAvatarUrl = (data['users'] as Map?)?['avatar_url'] as String?;
      return League.fromJson(data).copyWith(participantsCount: pCount, hostUsername: hostUsername, hostAvatarUrl: hostAvatarUrl);
    }).toList();
  }

  // ── 참가 신청 ────────────────────────────────────────
  Future<void> joinLeague(String leagueId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in');
    await _supabase.from('league_participants').insert({
      'league_id': leagueId,
      'user_id': userId,
      'status': 'approved',
    });
  }

  // ── 내가 참가한 리그 목록 ──────────────────────────────
  Future<List<League>> getMyJoinedLeagues() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _supabase
        .from('league_participants')
        .select('leagues(id, host_id, title, short_description, location, status, start_time, end_time, entry_fee, max_participants, created_at)')
        .eq('user_id', userId)
        .eq('status', 'approved');

    return response
        .map((d) => d['leagues'] as Map<String, dynamic>?)
        .whereType<Map<String, dynamic>>()
        .map(League.fromJson)
        .where((l) => l.status == 'recruiting' || l.status == 'in_progress')
        .toList();
  }

  // ── 이미 참가했는지 확인 ──────────────────────────────
  Future<bool> isJoined(String leagueId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;
    final res = await _supabase
        .from('league_participants')
        .select('id')
        .eq('league_id', leagueId)
        .eq('user_id', userId)
        .maybeSingle();
    return res != null;
  }

  // ── 순위표 조회 (리그 룰 + catch_limit 기반) ──────────
  Future<List<LeagueRankEntry>> getLeagueRanking(String leagueId) async {
    final res = await _supabase.rpc(
      'get_league_ranking',
      params: {'p_league_id': leagueId},
    ) as List;

    return res.map((row) {
      final m = row as Map<String, dynamic>;
      return LeagueRankEntry(
        userId: m['user_id'] as String,
        username: m['username'] as String? ?? '알 수 없음',
        avatarUrl: m['avatar_url'] as String?,
        bestLength: (m['best_length'] as num?)?.toDouble(),
        totalLength: (m['total_length'] as num?)?.toDouble() ?? 0.0,
        totalCount: (m['total_count'] as num?)?.toInt() ?? 0,
        totalScore: (m['total_score'] as num?)?.toInt() ?? 0,
        bestScore: (m['best_score'] as num?)?.toInt() ?? 0,
        fishType: m['fish_type'] as String? ?? '배스',
        isLunker: m['is_lunker'] as bool? ?? false,
      );
    }).toList();
  }

  // ── 심사 탭용: 리그 전체 조과 최신순 ──────────────────────
  Future<List<Post>> getLeagueCatchesForReview(String leagueId) async {
    final data = await _supabase
        .from('posts')
        .select('id, user_id, league_id, image_url, image_urls, aspect_ratio, fish_type, length, weight, score, review_status, created_at, users(username, avatar_url)')
        .eq('league_id', leagueId)
        .eq('is_deleted', false)
        .order('created_at', ascending: false)
        .limit(100);

    return data.map<Post>((d) {
      final user = d['users'] as Map?;
      return Post.fromJson(d).copyWith(
        username: user?['username'] as String? ?? '알 수 없음',
        avatarUrl: user?['avatar_url'] as String? ?? '',
      );
    }).toList();
  }

  // ── 조과 보류 ──────────────────────────────────────────────
  Future<void> holdPost(String postId) async {
    await _supabase
        .from('posts')
        .update({'review_status': 'held'})
        .eq('id', postId);
  }

  // ── 보류 해지 ──────────────────────────────────────────────
  Future<void> unholdPost(String postId) async {
    await _supabase
        .from('posts')
        .update({'review_status': 'approved'})
        .eq('id', postId);
  }

  // ── 특정 참가자의 조과 목록 ──────────────────────────────────
  Future<List<Post>> getUserLeaguePosts(String leagueId, String userId) async {
    final data = await _supabase
        .from('posts')
        .select(
          'id, user_id, league_id, image_url, image_urls, aspect_ratio, '
          'video_url, caption, fish_type, length, weight, lure_type, '
          'catch_count, score, is_lunker, is_personal_record, review_status, '
          'location, created_at, users(username, avatar_url)',
        )
        .eq('league_id', leagueId)
        .eq('user_id', userId)
        .eq('is_deleted', false)
        .order('created_at', ascending: false);

    return data.map<Post>((d) {
      final user = d['users'] as Map?;
      return Post.fromJson(d).copyWith(
        username: user?['username'] as String? ?? '알 수 없음',
        avatarUrl: user?['avatar_url'] as String? ?? '',
      );
    }).toList();
  }

  // ── 대기 중 참가 신청 목록 ─────────────────────────────────
  Future<List<LeaguePendingEntry>> getPendingParticipants(String leagueId) async {
    final data = await _supabase
        .from('league_participants')
        .select('user_id, created_at, users(username)')
        .eq('league_id', leagueId)
        .eq('status', 'pending')
        .order('created_at');
    return data.map((d) => LeaguePendingEntry(
      userId: d['user_id'] as String,
      username: (d['users'] as Map?)?['username'] as String? ?? '알 수 없음',
      joinedAt: DateTime.parse(d['created_at'] as String),
    )).toList();
  }

  // ── 참가 신청 수락 ──────────────────────────────────────────
  Future<void> approveParticipant(String leagueId, String userId) async {
    await _supabase
        .from('league_participants')
        .update({'status': 'approved'})
        .eq('league_id', leagueId)
        .eq('user_id', userId);
  }

  // ── 참가자 제거 (추방 / 거절) ───────────────────────────────
  Future<void> removeParticipant(String leagueId, String userId) async {
    await _supabase
        .from('league_participants')
        .delete()
        .eq('league_id', leagueId)
        .eq('user_id', userId);
  }

  // ── 참가 취소 ──────────────────────────────────────────────
  Future<void> leaveLeague(String leagueId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in');
    await _supabase
        .from('league_participants')
        .delete()
        .eq('league_id', leagueId)
        .eq('user_id', userId);
  }

  // ── 리그 삭제 ──────────────────────────────────────────────
  Future<void> deleteLeague(String leagueId) async {
    // 1. 삭제 전에 storage path 추출용 데이터 모음
    final postsRows = await _supabase
        .from('posts')
        .select('image_url, image_urls, video_url')
        .eq('league_id', leagueId);

    final leagueRow = await _supabase
        .from('leagues')
        .select('intro_image_urls')
        .eq('id', leagueId)
        .maybeSingle();

    // 2. DB 삭제 (리그 소속 posts 먼저 — league_id FK 제약)
    await _supabase.from('posts').delete().eq('league_id', leagueId);
    await _supabase.from('leagues').delete().eq('id', leagueId);

    // 3. Storage 파일 best-effort 정리
    for (final row in postsRows) {
      final imageUrls = (row['image_urls'] as List?)?.cast<String>();
      await removePostStorageFiles(
        _supabase,
        imageUrl: row['image_url'] as String?,
        imageUrls: imageUrls,
        videoUrl: row['video_url'] as String?,
      );
    }

    if (leagueRow != null) {
      final introUrls =
          (leagueRow['intro_image_urls'] as List?)?.cast<String>();
      await removeLeagueIntroFiles(_supabase, introUrls);
    }
  }

  // ── 리그 상태 변경 ──────────────────────────────────────────
  Future<void> updateLeagueStatus(String leagueId, String status) async {
    await _supabase
        .from('leagues')
        .update({'status': status})
        .eq('id', leagueId);
    if (status == 'completed') {
      await saveRankBonuses(leagueId);
    }
  }

  // ── 순위 보너스 계산 및 저장 (RPC) ─────────────────────────
  Future<void> saveRankBonuses(String leagueId) async {
    await _supabase.rpc(
      'save_league_rank_bonuses',
      params: {'p_league_id': leagueId},
    );
  }

  // ── 리그 정보 수정 ──────────────────────────────────────────
  Future<void> updateLeague({
    required String id,
    String? title,
    String? description,
    String? shortDescription,
    bool clearShortDescription = false,
    String? location,
    double? lat,
    double? lng,
    DateTime? startTime,
    DateTime? endTime,
    String? rule,
    int? catchLimit,
    String? prizeInfo,
    int? maxParticipants,
    int? entryFee,
    bool? isPublic,
    bool? allowGallery,
    List<XFile>? newImageFiles,
    List<String>? existingImageUrls,
    String? hostId,
  }) async {
    final update = <String, dynamic>{};
    if (title != null) update['title'] = title;
    if (description != null) update['description'] = description;
    if (shortDescription != null) update['short_description'] = shortDescription;
    if (clearShortDescription) update['short_description'] = null;
    if (location != null) update['location'] = location;
    if (lat != null) update['lat'] = lat;
    if (lng != null) update['lng'] = lng;
    if (startTime != null) update['start_time'] = startTime.toIso8601String();
    if (endTime != null) update['end_time'] = endTime.toIso8601String();
    if (rule != null) update['rule'] = rule;
    if (catchLimit != null) update['catch_limit'] = catchLimit;
    if (prizeInfo != null) update['prize_info'] = prizeInfo;
    if (maxParticipants != null) update['max_participants'] = maxParticipants;
    if (entryFee != null) update['entry_fee'] = entryFee;
    if (isPublic != null) update['is_public'] = isPublic;
    if (allowGallery != null) update['allow_gallery'] = allowGallery;
    if (newImageFiles != null || existingImageUrls != null) {
      final uploaded = (newImageFiles?.isNotEmpty == true && hostId != null)
          ? await _uploadIntroImages(hostId!, newImageFiles!)
          : <String>[];
      update['intro_image_urls'] = [...?existingImageUrls, ...uploaded];
    }
    if (update.isEmpty) return;
    await _supabase.from('leagues').update(update).eq('id', id);
  }
}

@riverpod
LeagueRepository leagueRepository(LeagueRepositoryRef ref) {
  return LeagueRepository(Supabase.instance.client);
}

@riverpod
class Leagues extends _$Leagues {
  bool _hasMore = true;
  bool _loading = false;

  bool get hasMore => _hasMore;

  @override
  Future<List<League>> build() async {
    _hasMore = true;
    _loading = false;
    final link = ref.keepAlive();
    Timer(const Duration(minutes: 5), link.close);
    final first = await ref.watch(leagueRepositoryProvider)
        .getLeagues(limit: kLeagueListPageSize);
    _hasMore = first.length >= kLeagueListPageSize;
    return first;
  }

  Future<void> loadMore() async {
    if (_loading || !_hasMore) return;
    final current = state.valueOrNull;
    if (current == null || current.isEmpty) return;
    _loading = true;
    try {
      final next = await ref.read(leagueRepositoryProvider).getLeagues(
        limit: kLeagueListPageSize,
        before: current.last.createdAt,
      );
      _hasMore = next.length >= kLeagueListPageSize;
      if (next.isNotEmpty) {
        state = AsyncData([...current, ...next]);
      }
    } finally {
      _loading = false;
    }
  }
}

@riverpod
Future<List<League>> myJoinedLeagues(MyJoinedLeaguesRef ref) {
  final link = ref.keepAlive();
  Timer(const Duration(minutes: 5), link.close);
  return ref.watch(leagueRepositoryProvider).getMyJoinedLeagues();
}

@riverpod
Future<bool> isJoined(IsJoinedRef ref, String leagueId) {
  final link = ref.keepAlive();
  Timer(const Duration(minutes: 3), link.close);
  return ref.watch(leagueRepositoryProvider).isJoined(leagueId);
}

@riverpod
Future<List<LeagueRankEntry>> leagueRanking(LeagueRankingRef ref, String leagueId) {
  final link = ref.keepAlive();
  Timer(const Duration(minutes: 5), link.close);
  return ref.watch(leagueRepositoryProvider).getLeagueRanking(leagueId);
}

// 특정 참가자의 조과 목록
@riverpod
Future<List<Post>> leagueUserPosts(
  LeagueUserPostsRef ref,
  String leagueId,
  String userId,
) {
  final link = ref.keepAlive();
  Timer(const Duration(minutes: 3), link.close);
  return ref.watch(leagueRepositoryProvider).getUserLeaguePosts(leagueId, userId);
}

@riverpod
Future<List<LeaguePendingEntry>> leaguePending(
  LeaguePendingRef ref,
  String leagueId,
) {
  final link = ref.keepAlive();
  Timer(const Duration(minutes: 3), link.close);
  return ref.watch(leagueRepositoryProvider).getPendingParticipants(leagueId);
}

@riverpod
Future<League> leagueDetail(LeagueDetailRef ref, String id) {
  final link = ref.keepAlive();
  Timer(const Duration(minutes: 5), link.close);
  return ref.watch(leagueRepositoryProvider).getLeague(id);
}

// 심사 탭용: 리그 전체 조과
@riverpod
Future<List<Post>> leagueCatchesForReview(
  LeagueCatchesForReviewRef ref,
  String leagueId,
) {
  final link = ref.keepAlive();
  Timer(const Duration(minutes: 3), link.close);
  return ref.watch(leagueRepositoryProvider).getLeagueCatchesForReview(leagueId);
}
