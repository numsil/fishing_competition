import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../league/data/league_model.dart';

part 'my_league_repository.g.dart';

class SeasonStats {
  final int? bestRank;
  final double? maxFishLength;

  const SeasonStats({this.bestRank, this.maxFishLength});
}

class MyLeagueRepository {
  final SupabaseClient _supabase;

  MyLeagueRepository(this._supabase);

  Future<Map<String, List<League>>> getMyLeagues() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in');

    // 1. Hosted leagues
    final hostedRes = await _supabase
        .from('leagues')
        .select('id, host_id, title, location, status, start_time, end_time, max_participants, created_at, league_participants(id)')
        .eq('host_id', userId)
        .order('created_at', ascending: false);

    // 2. Participated leagues
    final participatedRes = await _supabase
        .from('league_participants')
        .select('leagues(id, host_id, title, location, status, start_time, end_time, max_participants, created_at, league_participants(id))')
        .eq('user_id', userId)
        .order('joined_at', ascending: false);

    final hosted = hostedRes.map((data) => _mapLeague(data)).toList();

    final participated = participatedRes.map((data) {
      final leagueData = data['leagues'] as Map<String, dynamic>;
      return _mapLeague(leagueData);
    }).toList();

    return {
      'hosted': hosted,
      'participated': participated,
    };
  }

  Future<SeasonStats> getSeasonStats() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in');

    // 1. 최대어 - 리그 게시물 중 최대 length (단일 쿼리)
    final fishRes = await _supabase
        .from('posts')
        .select('length')
        .eq('user_id', userId)
        .not('league_id', 'is', null)
        .eq('is_deleted', false)
        .not('length', 'is', null)
        .order('length', ascending: false)
        .limit(1);

    double? maxLength;
    if (fishRes.isNotEmpty && fishRes[0]['length'] != null) {
      maxLength = (fishRes[0]['length'] as num).toDouble();
    }

    // 2. 최고 순위 - 참여한 모든 리그에서 계산
    final participatedRes = await _supabase
        .from('league_participants')
        .select('league_id, leagues(rule, catch_limit)')
        .eq('user_id', userId);

    if (participatedRes.isEmpty) {
      return SeasonStats(maxFishLength: maxLength);
    }

    final leagueIds = participatedRes.map((p) => p['league_id'] as String).toList();

    // 모든 리그 게시물 한 번에 조회
    List<dynamic> allPosts;
    try {
      allPosts = await _supabase
          .from('posts')
          .select('user_id, league_id, length, weight')
          .inFilter('league_id', leagueIds)
          .eq('is_deleted', false);
    } catch (_) {
      allPosts = await _supabase
          .from('posts')
          .select('user_id, league_id, length')
          .inFilter('league_id', leagueIds)
          .eq('is_deleted', false);
    }

    // 모든 리그 참가자 한 번에 조회
    final allParticipants = await _supabase
        .from('league_participants')
        .select('user_id, league_id')
        .inFilter('league_id', leagueIds);

    // 리그별 rule/catch_limit 맵
    final Map<String, Map<String, dynamic>> leagueRules = {};
    for (final p in participatedRes) {
      final lid = p['league_id'] as String;
      final leagueData = p['leagues'] as Map<String, dynamic>?;
      leagueRules[lid] = {
        'rule': leagueData?['rule'] as String? ?? '최대어',
        'catchLimit': (leagueData?['catch_limit'] as num?)?.toInt() ?? 1,
      };
    }

    // 리그별 참가자 목록
    final Map<String, Set<String>> leagueParticipants = {};
    for (final p in allParticipants) {
      final lid = p['league_id'] as String;
      leagueParticipants.putIfAbsent(lid, () => {}).add(p['user_id'] as String);
    }

    // 리그별 유저별 측정값
    final Map<String, Map<String, List<double>>> leagueUserMeasures = {};
    for (final lid in leagueIds) {
      leagueUserMeasures[lid] = {};
      for (final uid in leagueParticipants[lid] ?? <String>{}) {
        leagueUserMeasures[lid]![uid] = [];
      }
    }

    for (final post in allPosts) {
      final lid = post['league_id'] as String;
      final uid = post['user_id'] as String;
      if (leagueUserMeasures[lid] == null) continue;
      if (!leagueUserMeasures[lid]!.containsKey(uid)) continue;

      final rule = leagueRules[lid]?['rule'] as String? ?? '최대어';
      final double? measure;
      if (rule == '무게') {
        measure = post['weight'] != null ? (post['weight'] as num).toDouble() : null;
      } else {
        measure = post['length'] != null ? (post['length'] as num).toDouble() : null;
      }
      if (measure != null) leagueUserMeasures[lid]![uid]!.add(measure);
    }

    // 각 리그에서 유저 순위 계산 후 최고 순위 도출
    int? bestRank;
    for (final lid in leagueIds) {
      final rule = leagueRules[lid]?['rule'] as String? ?? '최대어';
      final catchLimit = leagueRules[lid]?['catchLimit'] as int? ?? 1;
      final userMeasures = leagueUserMeasures[lid] ?? {};

      double _score(List<double> measures) {
        final sorted = List<double>.from(measures)..sort((a, b) => b.compareTo(a));
        if (rule == '마릿수') return sorted.length.toDouble();
        final topN = catchLimit > 0 && sorted.length > catchLimit
            ? sorted.take(catchLimit).toList()
            : sorted;
        return topN.fold(0.0, (s, v) => s + v);
      }

      final myScore = _score(userMeasures[userId] ?? []);
      final rank = userMeasures.values.where((m) => _score(m) > myScore).length + 1;

      if (bestRank == null || rank < bestRank) {
        bestRank = rank;
      }
    }

    return SeasonStats(bestRank: bestRank, maxFishLength: maxLength);
  }

  League _mapLeague(Map<String, dynamic> data) {
    int pCount = 0;
    if (data['league_participants'] != null) {
      pCount = (data['league_participants'] as List).length;
    }
    return League.fromJson(data).copyWith(participantsCount: pCount);
  }
}

@riverpod
MyLeagueRepository myLeagueRepository(MyLeagueRepositoryRef ref) {
  return MyLeagueRepository(Supabase.instance.client);
}

@riverpod
Future<Map<String, List<League>>> myLeagues(MyLeaguesRef ref) {
  return ref.watch(myLeagueRepositoryProvider).getMyLeagues();
}

@riverpod
Future<SeasonStats> mySeasonStats(MySeasonStatsRef ref) {
  return ref.watch(myLeagueRepositoryProvider).getSeasonStats();
}
