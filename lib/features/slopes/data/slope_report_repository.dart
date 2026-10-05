import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'slope_report_repository.g.dart';

class NotAuthenticatedException implements Exception {
  const NotAuthenticatedException();
}

/// 슬로프 제보/오류신고 저장 (읽기는 어드민 몫).
class SlopeReportRepository {
  final SupabaseClient _supabase;
  SlopeReportRepository(this._supabase);

  /// 새 슬로프 제보 — 목록에 없는 슬로프 위치를 알려줌.
  Future<void> submitNewSlope({
    required String name,
    required String address,
    String? content,
  }) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) throw const NotAuthenticatedException();

    await _supabase.from('slope_reports').insert({
      'type': 'new_slope',
      'reporter_id': uid,
      'slope_name': name.trim(),
      'address': address.trim(),
      if (content != null && content.trim().isNotEmpty)
        'content': content.trim(),
    });
  }

  /// 오류 신고 — 기존 슬로프의 잘못된 정보 신고.
  Future<void> submitError({
    required String slopeId,
    required String content,
  }) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) throw const NotAuthenticatedException();

    await _supabase.from('slope_reports').insert({
      'type': 'error',
      'reporter_id': uid,
      'slope_id': slopeId,
      'content': content.trim(),
    });
  }
}

@riverpod
SlopeReportRepository slopeReportRepository(SlopeReportRepositoryRef ref) {
  return SlopeReportRepository(Supabase.instance.client);
}
