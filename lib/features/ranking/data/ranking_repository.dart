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
}

@riverpod
RankingRepository rankingRepository(RankingRepositoryRef ref) {
  return RankingRepository(Supabase.instance.client);
}

@riverpod
Future<List<RankingEntry>> topRankings(TopRankingsRef ref) {
  return ref.watch(rankingRepositoryProvider).getTopRankings();
}
