import 'dart:math';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'ranking_repository.g.dart';

class RankingEntry {
  final String userId;
  final String username;
  final double length;
  final String fishType;
  final String? location;

  RankingEntry({
    required this.userId,
    required this.username,
    required this.length,
    required this.fishType,
    this.location,
  });
}

class ScoreRankingEntry {
  final String userId;
  final String username;
  final String? avatarUrl;
  final int score;

  ScoreRankingEntry({
    required this.userId,
    required this.username,
    this.avatarUrl,
    required this.score,
  });
}

class RankingRepository {
  final SupabaseClient _supabase;

  RankingRepository(this._supabase);

  Future<List<RankingEntry>> getTopRankings() async {
    final res = await _supabase
        .from('posts')
        .select('user_id, length, fish_type, location, users!inner(username)')
        .eq('is_deleted', false)
        .order('length', ascending: false)
        .limit(10);

    return res.map((data) {
      final double len = data['length'] != null ? (data['length'] as num).toDouble() : 0.0;
      return RankingEntry(
        userId: data['user_id'],
        username: data['users']['username'] ?? '알 수 없음',
        length: len,
        fishType: data['fish_type'] ?? '알 수 없음',
        location: data['location'],
      );
    }).toList();
  }

  Future<List<ScoreRankingEntry>> getLeagueScoreRanking() async {
    final results = await Future.wait([
      // 조과 점수
      _supabase
          .from('posts')
          .select('user_id, score, length, users!inner(username, avatar_url)')
          .not('league_id', 'is', null)
          .eq('is_deleted', false),
      // 순위 보너스
      _supabase
          .from('league_participants')
          .select('user_id, rank_bonus, users!inner(username, avatar_url)')
          .gt('rank_bonus', 0),
    ]);

    final userMap = <String, Map<String, dynamic>>{};
    _mergeRows(userMap, results[0] as List, scoreKey: 'score', lengthKey: 'length');
    _mergeRows(userMap, results[1] as List, scoreKey: 'rank_bonus');

    return _buildEntries(userMap);
  }

  Future<List<ScoreRankingEntry>> getPersonalScoreRanking() async {
    final res = await _supabase
        .from('posts')
        .select('user_id, score, length, users!inner(username, avatar_url)')
        .eq('is_personal_record', true)
        .eq('is_deleted', false);

    final userMap = <String, Map<String, dynamic>>{};
    _mergeRows(userMap, res as List, scoreKey: 'score', lengthKey: 'length');
    return _buildEntries(userMap);
  }

  void _mergeRows(
    Map<String, Map<String, dynamic>> userMap,
    List<dynamic> rows, {
    required String scoreKey,
    String? lengthKey,
  }) {
    for (final row in rows) {
      final uid = row['user_id'] as String;
      if (!userMap.containsKey(uid)) {
        userMap[uid] = {
          'username': (row['users'] as Map?)?['username'] ?? '알 수 없음',
          'avatar_url': (row['users'] as Map?)?['avatar_url'],
          'score': 0,
        };
      }
      final dbScore = row[scoreKey] as int?;
      final length = lengthKey != null && row[lengthKey] != null
          ? (row[lengthKey] as num).toDouble()
          : null;
      final s = (dbScore == null || dbScore == 0) && length != null
          ? _calcScore(length)
          : (dbScore ?? 0);
      userMap[uid]!['score'] = (userMap[uid]!['score'] as int) + s;
    }
  }

  List<ScoreRankingEntry> _buildEntries(Map<String, Map<String, dynamic>> userMap) {
    return userMap.entries
        .map((e) => ScoreRankingEntry(
              userId: e.key,
              username: e.value['username'] as String,
              avatarUrl: e.value['avatar_url'] as String?,
              score: e.value['score'] as int,
            ))
        .where((e) => e.score > 0)
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score))
      ..take(10);
  }

  int _calcScore(double length) {
    if (length <= 30) return 0;
    final base = pow(length, 2.5) / 800;
    final double m;
    if (length >= 60)      m = 10.0;
    else if (length >= 55) m = 7.0;
    else if (length >= 50) m = 5.0;
    else if (length >= 45) m = 3.0;
    else if (length >= 40) m = 2.0;
    else                   m = 1.5;
    return (base * m).round();
  }
}

@riverpod
RankingRepository rankingRepository(RankingRepositoryRef ref) {
  return RankingRepository(Supabase.instance.client);
}

@riverpod
Future<List<RankingEntry>> topRankings(TopRankingsRef ref) {
  return ref.watch(rankingRepositoryProvider).getTopRankings();
}

@riverpod
Future<List<ScoreRankingEntry>> leagueScoreRanking(LeagueScoreRankingRef ref) {
  return ref.watch(rankingRepositoryProvider).getLeagueScoreRanking();
}

@riverpod
Future<List<ScoreRankingEntry>> personalScoreRanking(PersonalScoreRankingRef ref) {
  return ref.watch(rankingRepositoryProvider).getPersonalScoreRanking();
}
