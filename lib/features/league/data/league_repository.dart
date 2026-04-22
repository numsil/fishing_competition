import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'league_model.dart';

part 'league_repository.g.dart';

class LeagueRepository {
  final SupabaseClient _supabase;

  LeagueRepository(this._supabase);

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
}

@riverpod
LeagueRepository leagueRepository(LeagueRepositoryRef ref) {
  return LeagueRepository(Supabase.instance.client);
}

@riverpod
Future<List<League>> leagues(LeaguesRef ref) {
  return ref.watch(leagueRepositoryProvider).getLeagues();
}
