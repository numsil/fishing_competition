import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'report_repository.g.dart';

class AlreadyReportedException implements Exception {
  const AlreadyReportedException();
}

class NotAuthenticatedException implements Exception {
  const NotAuthenticatedException();
}

class ReportRepository {
  final SupabaseClient _supabase;
  ReportRepository(this._supabase);

  Future<void> reportPost({
    required String postId,
    required String reason,
  }) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) throw const NotAuthenticatedException();

    final existing = await _supabase
        .from('reports')
        .select('id')
        .eq('post_id', postId)
        .eq('reporter_id', uid)
        .eq('status', 'pending')
        .limit(1)
        .maybeSingle();

    if (existing != null) {
      throw const AlreadyReportedException();
    }

    await _supabase.from('reports').insert({
      'post_id': postId,
      'reporter_id': uid,
      'reason': reason,
    });
  }

  Future<void> reportComment({
    required String commentId,
    String? postId,
    required String reason,
  }) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) throw const NotAuthenticatedException();

    final existing = await _supabase
        .from('reports')
        .select('id')
        .eq('comment_id', commentId)
        .eq('reporter_id', uid)
        .eq('status', 'pending')
        .limit(1)
        .maybeSingle();

    if (existing != null) {
      throw const AlreadyReportedException();
    }

    await _supabase.from('reports').insert({
      'comment_id': commentId,
      if (postId != null) 'post_id': postId,
      'reporter_id': uid,
      'reason': reason,
    });
  }
}

@riverpod
ReportRepository reportRepository(ReportRepositoryRef ref) {
  return ReportRepository(Supabase.instance.client);
}
