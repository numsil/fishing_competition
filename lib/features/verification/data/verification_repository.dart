import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'verification_model.dart';

part 'verification_repository.g.dart';

class VerificationRepository {
  final SupabaseClient _supabase;
  VerificationRepository(this._supabase);

  // 조과 제출 후 호출 - 인증 요청 생성 + 랜덤 10명 배정
  Future<void> createVerificationRequest(String postId, String submitterId) async {
    // 1. catch_verifications 생성
    final verif = await _supabase
        .from('catch_verifications')
        .insert({'post_id': postId, 'submitter_id': submitterId})
        .select('id')
        .single();
    final verifId = verif['id'] as String;

    // 2. 적격 유저 풀 조회 (본인 제외)
    final candidates = await _supabase
        .from('users')
        .select('id')
        .neq('id', submitterId)
        .limit(50);

    if (candidates.isEmpty) return;

    final ids = List<Map<String, dynamic>>.from(candidates);
    ids.shuffle();
    final selected = ids.take(10).toList();

    // 3. verification_votes 생성
    final votes = selected.map((u) => {
      'verification_id': verifId,
      'voter_id': u['id'],
    }).toList();
    await _supabase.from('verification_votes').insert(votes);
  }

  // 내가 투표해야 할 인증 요청 목록 (미응답만)
  Future<List<VerificationRequest>> getPendingForMe(String userId) async {
    final rows = await _supabase
        .from('verification_votes')
        .select(
          'verification_id, vote, catch_verifications!inner(id, post_id, submitter_id, status, approve_count, reject_count, created_at, posts!inner(image_url, fish_type, length, weight, location, users!inner(username, avatar_url)))'
        )
        .eq('voter_id', userId)
        .isFilter('vote', null)
        .eq('catch_verifications.status', 'pending');

    return rows.map((row) {
      final cv = row['catch_verifications'] as Map<String, dynamic>;
      final post = cv['posts'] as Map<String, dynamic>;
      final user = post['users'] as Map<String, dynamic>;
      final req = VerificationRequest.fromJson(cv);
      return req.copyWith(
        myVote: row['vote'] as String?,
        imageUrl: post['image_url'] as String? ?? '',
        submitterName: user['username'] as String? ?? '',
        submitterAvatar: user['avatar_url'] as String? ?? '',
        fishType: post['fish_type'] as String? ?? '배스',
        length: (post['length'] as num?)?.toDouble(),
        weight: (post['weight'] as num?)?.toDouble(),
        location: post['location'] as String?,
      );
    }).toList();
  }

  // 투표 제출 + 결과 자동 판정
  Future<void> submitVote(String verificationId, String voterId, String vote) async {
    // 1. 투표 기록
    await _supabase
        .from('verification_votes')
        .update({'vote': vote, 'voted_at': DateTime.now().toIso8601String()})
        .eq('verification_id', verificationId)
        .eq('voter_id', voterId);

    // 2. 현재 집계 조회
    final counts = await _supabase
        .from('verification_votes')
        .select('vote')
        .eq('verification_id', verificationId)
        .not('vote', 'is', null);

    int approveCount = 0;
    int rejectCount = 0;
    for (final row in counts) {
      if (row['vote'] == 'approve') approveCount++;
      if (row['vote'] == 'reject') rejectCount++;
    }

    // 3. catch_verifications 카운트 업데이트
    await _supabase
        .from('catch_verifications')
        .update({'approve_count': approveCount, 'reject_count': rejectCount})
        .eq('id', verificationId);

    // 4. 판정 (최소 3명 응답 필요)
    final responded = approveCount + rejectCount;
    if (responded < 3) return;

    String? newStatus;
    if (approveCount / responded >= 0.7) {
      newStatus = 'approved';
    } else if (rejectCount / responded >= 0.6) {
      newStatus = 'rejected';
    }
    if (newStatus == null) return;

    // 5. 결과 확정
    final verif = await _supabase
        .from('catch_verifications')
        .update({
          'status': newStatus,
          'resolved_at': DateTime.now().toIso8601String(),
        })
        .eq('id', verificationId)
        .select('post_id')
        .single();

    await _supabase
        .from('posts')
        .update({'review_status': newStatus})
        .eq('id', verif['post_id']);
  }

  // 내가 완료한 투표 포함 전체 목록
  Future<List<VerificationRequest>> getMyVerificationHistory(String userId) async {
    final rows = await _supabase
        .from('verification_votes')
        .select(
          'verification_id, vote, catch_verifications!inner(id, post_id, submitter_id, status, approve_count, reject_count, created_at, posts!inner(image_url, fish_type, length, weight, location, users!inner(username, avatar_url)))'
        )
        .eq('voter_id', userId)
        .order('created_at', referencedTable: 'catch_verifications', ascending: false)
        .limit(30);

    return rows.map((row) {
      final cv = row['catch_verifications'] as Map<String, dynamic>;
      final post = cv['posts'] as Map<String, dynamic>;
      final user = post['users'] as Map<String, dynamic>;
      final req = VerificationRequest.fromJson(cv);
      return req.copyWith(
        myVote: row['vote'] as String?,
        imageUrl: post['image_url'] as String? ?? '',
        submitterName: user['username'] as String? ?? '',
        submitterAvatar: user['avatar_url'] as String? ?? '',
        fishType: post['fish_type'] as String? ?? '배스',
        length: (post['length'] as num?)?.toDouble(),
        weight: (post['weight'] as num?)?.toDouble(),
        location: post['location'] as String?,
      );
    }).toList();
  }
}

@riverpod
VerificationRepository verificationRepository(VerificationRepositoryRef ref) {
  return VerificationRepository(Supabase.instance.client);
}

@riverpod
Future<List<VerificationRequest>> myPendingVerifications(
  MyPendingVerificationsRef ref,
) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return [];
  return ref.watch(verificationRepositoryProvider).getPendingForMe(userId);
}

@riverpod
Future<List<VerificationRequest>> myVerificationHistory(
  MyVerificationHistoryRef ref,
) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return [];
  return ref.watch(verificationRepositoryProvider).getMyVerificationHistory(userId);
}
