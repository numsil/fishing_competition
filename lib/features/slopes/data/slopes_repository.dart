import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'slope_model.dart';

part 'slopes_repository.g.dart';

/// Supabase `slopes` 테이블에서 슬로프 목록을 읽는다 (읽기 전용).
/// 추가/수정/삭제는 별도 관리자 웹(admin)에서 처리.
class SlopesRepository {
  final SupabaseClient _supabase;
  SlopesRepository(this._supabase);

  static const _columns =
      'id, name, address, sido, sigungu, water_body, lat, lng, thumb_url';

  Future<List<Slope>> getSlopes() async {
    final rows = await _supabase
        .from('slopes')
        .select(_columns)
        .order('sido')
        .order('sigungu')
        .order('name');
    return (rows as List)
        .map((e) => Slope.fromMap(e as Map<String, dynamic>))
        .toList();
  }
}

@riverpod
SlopesRepository slopesRepository(SlopesRepositoryRef ref) {
  return SlopesRepository(Supabase.instance.client);
}

@riverpod
Future<List<Slope>> slopes(SlopesRef ref) async {
  // 동적 데이터 → 5분 TTL 캐시 (관리자 변경 시 invalidate로 즉시 갱신)
  final link = ref.keepAlive();
  final timer = Timer(const Duration(minutes: 5), link.close);
  ref.onDispose(timer.cancel);
  return ref.watch(slopesRepositoryProvider).getSlopes();
}
