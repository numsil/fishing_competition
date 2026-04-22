import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../league/data/league_model.dart';

part 'my_league_repository.g.dart';

class MyLeagueRepository {
  final SupabaseClient _supabase;

  MyLeagueRepository(this._supabase);

  Future<Map<String, List<League>>> getMyLeagues() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in');

    // 1. Hosted leagues
    final hostedRes = await _supabase
        .from('leagues')
        .select('*, league_participants(id)')
        .eq('host_id', userId)
        .order('created_at', ascending: false);

    // 2. Participated leagues
    final participatedRes = await _supabase
        .from('league_participants')
        .select('leagues(*, league_participants(id))')
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
