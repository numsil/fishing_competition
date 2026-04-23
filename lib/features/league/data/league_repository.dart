import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'league_model.dart';

part 'league_repository.g.dart';

// ── 순위 항목 모델 ──────────────────────────────────────
class LeagueRankEntry {
  final String userId;
  final String username;
  final double? bestLength;   // 최대어 (cm)
  final double totalLength;   // 합산 길이 (cm)
  final int totalCount;       // 총 마릿수
  final String fishType;
  final bool isLunker;

  const LeagueRankEntry({
    required this.userId,
    required this.username,
    this.bestLength,
    required this.totalLength,
    required this.totalCount,
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

  Future<void> createLeague({
    required String hostId,
    required String title,
    String? description,
    required String location,
    double? lat,
    double? lng,
    required DateTime startTime,
    required DateTime endTime,
    int entryFee = 0,
    int maxParticipants = 100,
    String fishTypes = '배스',
    String rule = '최대어',
    String? prizeInfo,
    bool isPublic = true,
  }) async {
    await _supabase.from('leagues').insert({
      'host_id': hostId,
      'title': title,
      'description': description,
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
      'prize_info': prizeInfo,
      'is_public': isPublic,
    });
  }

  Future<League> getLeague(String id) async {
    final data = await _supabase
        .from('leagues')
        .select('*, league_participants(id)')
        .eq('id', id)
        .single();
    final pCount = (data['league_participants'] as List?)?.length ?? 0;
    return League.fromJson(data).copyWith(participantsCount: pCount);
  }

  Future<List<League>> getLeagues() async {
    final response = await _supabase
        .from('leagues')
        .select('*, league_participants(id)')
        .order('created_at', ascending: false);

    return response.map((data) {
      int pCount = 0;
      if (data['league_participants'] != null) {
        final participants = data['league_participants'] as List;
        pCount = participants.length;
      }
      return League.fromJson(data).copyWith(participantsCount: pCount);
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

  // ── 순위표 조회 (리그 룰 기반) ───────────────────────
  Future<List<LeagueRankEntry>> getLeagueRanking(String leagueId) async {
    // 1. 리그 룰 조회
    final leagueData = await _supabase
        .from('leagues')
        .select('rule')
        .eq('id', leagueId)
        .single();
    final rule = leagueData['rule'] as String? ?? '최대어';

    // 2. 참가자 목록 + 유저 정보
    final participants = await _supabase
        .from('league_participants')
        .select('user_id, users(username)')
        .eq('league_id', leagueId);

    // 3. 해당 리그 게시물 목록 (길이·마릿수 포함)
    final posts = await _supabase
        .from('posts')
        .select('user_id, length, catch_count, fish_type, is_lunker')
        .eq('league_id', leagueId);

    // 4. 참가자별 통계 집계
    final Map<String, Map<String, dynamic>> stats = {};
    for (final p in participants) {
      final uid = p['user_id'] as String;
      final username = (p['users'] as Map?)?['username'] as String? ?? '알 수 없음';
      stats[uid] = {
        'username': username,
        'bestLength': null,
        'totalLength': 0.0,
        'totalCount': 0,
        'fishType': '배스',
        'isLunker': false,
      };
    }

    for (final post in posts) {
      final uid = post['user_id'] as String;
      if (!stats.containsKey(uid)) continue;
      final s = stats[uid]!;
      final length = post['length'] != null ? (post['length'] as num).toDouble() : null;
      final count = post['catch_count'] != null ? (post['catch_count'] as num).toInt() : 1;
      s['totalCount'] = (s['totalCount'] as int) + count;
      if (post['fish_type'] != null) s['fishType'] = post['fish_type'];
      if (post['is_lunker'] == true) s['isLunker'] = true;
      if (length != null) {
        s['totalLength'] = (s['totalLength'] as double) + (length * count);
        final cur = s['bestLength'] as double?;
        if (cur == null || length > cur) s['bestLength'] = length;
      }
    }

    final entries = stats.entries.map((e) => LeagueRankEntry(
      userId: e.key,
      username: e.value['username'] as String,
      bestLength: e.value['bestLength'] as double?,
      totalLength: e.value['totalLength'] as double,
      totalCount: e.value['totalCount'] as int,
      fishType: e.value['fishType'] as String,
      isLunker: e.value['isLunker'] as bool,
    )).toList();

    // 5. 룰별 정렬
    entries.sort((a, b) {
      switch (rule) {
        case '합산 길이':
          if (a.totalLength == b.totalLength) return b.totalCount.compareTo(a.totalCount);
          return b.totalLength.compareTo(a.totalLength);
        case '마릿수':
          if (a.totalCount == b.totalCount) {
            if (a.bestLength == null) return 1;
            if (b.bestLength == null) return -1;
            return b.bestLength!.compareTo(a.bestLength!);
          }
          return b.totalCount.compareTo(a.totalCount);
        default: // 최대어, 최대어 + 마릿수
          if (a.bestLength == null && b.bestLength == null) return b.totalCount.compareTo(a.totalCount);
          if (a.bestLength == null) return 1;
          if (b.bestLength == null) return -1;
          final cmp = b.bestLength!.compareTo(a.bestLength!);
          if (cmp != 0) return cmp;
          return b.totalCount.compareTo(a.totalCount);
      }
    });

    return entries;
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

  // ── 리그 상태 변경 ──────────────────────────────────────────
  Future<void> updateLeagueStatus(String leagueId, String status) async {
    await _supabase
        .from('leagues')
        .update({'status': status})
        .eq('id', leagueId);
  }

  // ── 리그 정보 수정 ──────────────────────────────────────────
  Future<void> updateLeague({
    required String id,
    String? title,
    String? location,
    String? rule,
    String? prizeInfo,
    int? maxParticipants,
    int? entryFee,
  }) async {
    final update = <String, dynamic>{};
    if (title != null) update['title'] = title;
    if (location != null) update['location'] = location;
    if (rule != null) update['rule'] = rule;
    if (prizeInfo != null) update['prize_info'] = prizeInfo;
    if (maxParticipants != null) update['max_participants'] = maxParticipants;
    if (entryFee != null) update['entry_fee'] = entryFee;
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
  return ref.watch(leagueRepositoryProvider).getLeagues();
}

@riverpod
Future<bool> isJoined(IsJoinedRef ref, String leagueId) {
  return ref.watch(leagueRepositoryProvider).isJoined(leagueId);
}

@riverpod
Future<List<LeagueRankEntry>> leagueRanking(LeagueRankingRef ref, String leagueId) {
  return ref.watch(leagueRepositoryProvider).getLeagueRanking(leagueId);
}

// 코드 생성 없이 수동 정의
final leaguePendingProvider = FutureProvider.family<List<LeaguePendingEntry>, String>(
  (ref, leagueId) => ref.watch(leagueRepositoryProvider).getPendingParticipants(leagueId),
);
