import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../feed/data/post_model.dart';
import '../../../core/utils/score_calculator.dart';
import 'league_model.dart';

part 'league_repository.g.dart';

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
        .select('*, league_participants(id), users!host_id(username, avatar_url)')
        .eq('id', id)
        .single();
    final pCount = (data['league_participants'] as List?)?.length ?? 0;
    final hostUsername = (data['users'] as Map?)?['username'] as String? ?? '';
    final hostAvatarUrl = (data['users'] as Map?)?['avatar_url'] as String?;
    return League.fromJson(data).copyWith(
      participantsCount: pCount,
      hostUsername: hostUsername,
      hostAvatarUrl: hostAvatarUrl,
    );
  }

  Future<List<League>> getLeagues() async {
    final response = await _supabase
        .from('leagues')
        .select('id, host_id, title, short_description, location, status, start_time, end_time, entry_fee, max_participants, created_at, league_participants(id), users!host_id(username)')
        .order('created_at', ascending: false);

    return response.map((data) {
      int pCount = 0;
      if (data['league_participants'] != null) {
        final participants = data['league_participants'] as List;
        pCount = participants.length;
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
    // 1. 리그 룰 + catch_limit 조회 (컬럼 미존재 시 기본값 사용)
    String rule = '최대어';
    int catchLimit = 1;
    try {
      final leagueData = await _supabase
          .from('leagues')
          .select('rule, catch_limit')
          .eq('id', leagueId)
          .single();
      rule = leagueData['rule'] as String? ?? '최대어';
      catchLimit = (leagueData['catch_limit'] as num?)?.toInt() ?? 1;
    } catch (_) {}

    // 2. 참가자 목록 + 유저 정보
    final participants = await _supabase
        .from('league_participants')
        .select('user_id, users(username, avatar_url)')
        .eq('league_id', leagueId);

    // 3. 해당 리그 게시물
    final posts = await _supabase
        .from('posts')
        .select('user_id, length, weight, score, fish_type, is_lunker')
        .eq('league_id', leagueId)
        .eq('is_deleted', false);

    // 4. 유저별 데이터 구성
    final Map<String, String> userNames = {};
    final Map<String, String?> userAvatars = {};
    final Map<String, List<double>> userMeasures = {};
    final Map<String, List<int>> userScores = {};
    final Map<String, String> userFishType = {};
    final Map<String, bool> userLunker = {};

    for (final p in participants) {
      final uid = p['user_id'] as String;
      userNames[uid] = (p['users'] as Map?)?['username'] as String? ?? '알 수 없음';
      userAvatars[uid] = (p['users'] as Map?)?['avatar_url'] as String?;
      userMeasures[uid] = [];
      userScores[uid] = [];
      userFishType[uid] = '배스';
      userLunker[uid] = false;
    }

    for (final post in posts) {
      final uid = post['user_id'] as String;
      if (!userMeasures.containsKey(uid)) continue;
      if (post['fish_type'] != null) userFishType[uid] = post['fish_type'] as String;
      if (post['is_lunker'] == true) userLunker[uid] = true;

      // DB에 저장된 score 사용, 없으면 length로 재계산 (기존 데이터 호환)
      final rawScore = post['score'] as int?;
      final length = post['length'] != null ? (post['length'] as num).toDouble() : null;
      final weight = post['weight'] != null ? (post['weight'] as num).toDouble() : null;
      final score = rawScore ?? calculateFishScore(length);
      userScores[uid]!.add(score);

      final double? measure = rule == '무게' ? weight : length;
      if (measure != null) userMeasures[uid]!.add(measure);
    }

    // 5. 유저별 집계
    final entries = userNames.keys.map((uid) {
      final scores = List<int>.from(userScores[uid] ?? [])
        ..sort((a, b) => b.compareTo(a));
      final measures = List<double>.from(userMeasures[uid] ?? [])
        ..sort((a, b) => b.compareTo(a));

      final int totalScore;
      final int bestScore;
      final double? bestLength;
      final int count = scores.length;

      if (rule == '마릿수') {
        totalScore = count * 10; // 마릿수 룰: 1마리당 10점
        bestScore = scores.isNotEmpty ? scores.first : 0;
        bestLength = measures.isNotEmpty ? measures.first : null;
      } else {
        // 상위 catchLimit개 score 합산
        final topN = catchLimit > 0 && scores.length > catchLimit
            ? scores.take(catchLimit).toList()
            : scores;
        totalScore = topN.fold(0, (s, v) => s + v);
        bestScore = scores.isNotEmpty ? scores.first : 0;
        bestLength = measures.isNotEmpty ? measures.first : null;
      }

      // totalLength는 UI 표시용 합산 길이 (기존 호환)
      final topMeasures = catchLimit > 0 && measures.length > catchLimit
          ? measures.take(catchLimit).toList()
          : measures;
      final totalLength = topMeasures.fold(0.0, (s, v) => s + v);

      return LeagueRankEntry(
        userId: uid,
        username: userNames[uid]!,
        avatarUrl: userAvatars[uid],
        bestLength: bestLength,
        totalLength: totalLength,
        totalCount: count,
        totalScore: totalScore,
        bestScore: bestScore,
        fishType: userFishType[uid] ?? '배스',
        isLunker: userLunker[uid] ?? false,
      );
    }).toList();

    // 6. 점수 기준 정렬 (동점 시 마릿수 → 최고점수 순)
    entries.sort((a, b) {
      if (a.totalScore != b.totalScore) return b.totalScore.compareTo(a.totalScore);
      if (a.totalCount != b.totalCount) return b.totalCount.compareTo(a.totalCount);
      return b.bestScore.compareTo(a.bestScore);
    });

    return entries;
  }

  // ── 특정 참가자의 조과 목록 ──────────────────────────────────
  Future<List<Post>> getUserLeaguePosts(String leagueId, String userId) async {
    final data = await _supabase
        .from('posts')
        .select('*, users(username, avatar_url)')
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
    // 리그 소속 posts 먼저 삭제 (league_id SET NULL 방지)
    await _supabase.from('posts').delete().eq('league_id', leagueId);
    await _supabase.from('leagues').delete().eq('id', leagueId);
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

  // ── 순위 보너스 계산 및 저장 ─────────────────────────────────
  Future<void> saveRankBonuses(String leagueId) async {
    final results = await Future.wait([
      getLeagueRanking(leagueId),
      getLeague(leagueId),
    ]);
    final rankings = results[0] as List<LeagueRankEntry>;
    final league   = results[1] as League;
    final n        = league.participantsCount;
    final now      = DateTime.now().toUtc().toIso8601String();

    for (int i = 0; i < rankings.length; i++) {
      final bonus = _rankBonus(i + 1, n);
      if (bonus <= 0) continue;
      await _supabase
          .from('league_participants')
          .update({'rank_bonus': bonus, 'rank_bonus_earned_at': now})
          .eq('league_id', leagueId)
          .eq('user_id', rankings[i].userId);
    }
  }

  int _rankBonus(int rank, int participantCount) {
    final int base;
    if (participantCount <= 6)       base = 10;
    else if (participantCount <= 12) base = 24;
    else if (participantCount <= 19) base = 40;
    else                             base = 60;

    final double m;
    if (rank == 1)       m = 1.00;
    else if (rank == 2)  m = 0.60;
    else if (rank == 3)  m = 0.40;
    else if (rank <= 5)  m = 0.20;
    else if (rank <= 10) m = 0.10;
    else                 m = 0.05;

    return (participantCount * base * m).round();
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
Future<List<League>> leagues(LeaguesRef ref) {
  final link = ref.keepAlive();
  Timer(const Duration(minutes: 5), link.close);
  return ref.watch(leagueRepositoryProvider).getLeagues();
}

@riverpod
Future<List<League>> myJoinedLeagues(MyJoinedLeaguesRef ref) {
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
final leagueUserPostsProvider = FutureProvider.family<List<Post>, (String, String)>(
  (ref, params) {
    final (leagueId, userId) = params;
    return ref.watch(leagueRepositoryProvider).getUserLeaguePosts(leagueId, userId);
  },
);

// 코드 생성 없이 수동 정의
final leaguePendingProvider = FutureProvider.family<List<LeaguePendingEntry>, String>(
  (ref, leagueId) => ref.watch(leagueRepositoryProvider).getPendingParticipants(leagueId),
);

final leagueDetailProvider = FutureProvider.family<League, String>(
  (ref, id) {
    final link = ref.keepAlive();
    Timer(const Duration(minutes: 5), link.close);
    return ref.watch(leagueRepositoryProvider).getLeague(id);
  },
);
