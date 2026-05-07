import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/data/auth_repository.dart';
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
        .select('id, host_id, title, location, status, start_time, end_time, max_participants, created_at, league_participants(count)')
        .eq('host_id', userId)
        .order('created_at', ascending: false);

    // 2. Participated leagues
    final participatedRes = await _supabase
        .from('league_participants')
        .select('leagues(id, host_id, title, location, status, start_time, end_time, max_participants, created_at, league_participants(count))')
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

    final res = await _supabase.rpc(
      'get_user_season_stats',
      params: {'p_user_id': userId},
    ) as List;

    if (res.isEmpty) return const SeasonStats();

    final row = res.first as Map<String, dynamic>;
    return SeasonStats(
      bestRank: (row['best_rank'] as num?)?.toInt(),
      maxFishLength: (row['max_fish_length'] as num?)?.toDouble(),
    );
  }

  League _mapLeague(Map<String, dynamic> data) {
    int pCount = 0;
    final lp = data['league_participants'];
    if (lp is List && lp.isNotEmpty) {
      pCount = (lp[0] as Map)['count'] as int? ?? 0;
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
  // 로그인/로그아웃 시만 재빌드 (TOKEN_REFRESHED는 무시)
  ref.watch(authStateProvider.select(
    (async) => async.valueOrNull?.session?.user.id,
  ));
  final link = ref.keepAlive();
  Timer(const Duration(minutes: 5), link.close);
  return ref.watch(myLeagueRepositoryProvider).getMyLeagues();
}

@riverpod
Future<SeasonStats> mySeasonStats(MySeasonStatsRef ref) {
  ref.watch(authStateProvider.select(
    (async) => async.valueOrNull?.session?.user.id,
  ));
  final link = ref.keepAlive();
  Timer(const Duration(minutes: 3), link.close);
  return ref.watch(myLeagueRepositoryProvider).getSeasonStats();
}
