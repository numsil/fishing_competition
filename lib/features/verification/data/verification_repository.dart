import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'verification_model.dart';

part 'verification_repository.g.dart';

class VerificationRepository {
  final SupabaseClient _supabase;
  VerificationRepository(this._supabase);

  // 조과 제출 후 호출 - 인증 요청 생성 + 랜덤 10명 배정
  Future<void> createVerificationRequest(String postId, String submitterId) async {
    // 1. catch_verifications 생성 (idempotent - 이미 존재하면 기존 ID 반환)
    final existing = await _supabase
        .from('catch_verifications')
        .select('id')
        .eq('post_id', postId)
        .maybeSingle();
    if (existing != null) return; // 이미 인증 요청이 있음

    final verif = await _supabase
        .from('catch_verifications')
        .insert({'post_id': postId, 'submitter_id': submitterId})
        .select('id')
        .single();
    final verifId = verif['id'] as String;

    // 2. 권한 부여된 verifier 전원 배정 (테스트 기간: 랜덤 유저 배정 없음)
    final verifierCandidates = await _supabase
        .from('users')
        .select('id')
        .eq('is_verifier', true)
        .neq('id', submitterId);

    final selected = List<Map<String, dynamic>>.from(verifierCandidates);
    if (selected.isEmpty) return;

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

  // 운영자용 전체 pending 인증 조회
  Future<List<VerificationRequest>> getAllPendingVerifications() async {
    final rows = await _supabase
        .from('catch_verifications')
        .select(
          'id, post_id, submitter_id, status, approve_count, reject_count, created_at, posts!inner(image_url, fish_type, length, weight, location, users!inner(username, avatar_url))'
        )
        .eq('status', 'pending')
        .order('created_at', ascending: false);

    return rows.map((cv) {
      final post = cv['posts'] as Map<String, dynamic>;
      final user = post['users'] as Map<String, dynamic>;
      return VerificationRequest.fromJson(cv).copyWith(
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

    // 4. 판정 (테스트 기간: 거절 1명이면 즉시 거절, 승인 2명이면 승인)
    String? newStatus;
    if (rejectCount >= 1) {
      newStatus = 'rejected';
    } else if (approveCount >= 2) {
      newStatus = 'approved';
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

  // 어드민 직접 승인/거부 (투표 시스템 우회)
  Future<void> adminResolveVerification(
      String verificationId, String postId, String vote) async {
    // vote: 'approve' | 'reject' → status: 'approved' | 'rejected'
    final status = vote == 'approve' ? 'approved' : 'rejected';
    await _supabase
        .from('catch_verifications')
        .update({
          'status': status,
          'resolved_at': DateTime.now().toIso8601String(),
        })
        .eq('id', verificationId);
    await _supabase
        .from('posts')
        .update({'review_status': status})
        .eq('id', postId);
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
Future<bool> isAdminUser(IsAdminUserRef ref) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return false;
  final row = await Supabase.instance.client
      .from('users')
      .select('role')
      .eq('id', userId)
      .maybeSingle();
  return row?['role'] == 'admin';
}

@riverpod
Future<List<VerificationRequest>> myPendingVerifications(
  MyPendingVerificationsRef ref,
) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return [];
  final isAdmin = await ref.read(isAdminUserProvider.future);
  if (isAdmin) {
    return ref.read(verificationRepositoryProvider).getAllPendingVerifications();
  }
  return ref.read(verificationRepositoryProvider).getPendingForMe(userId);
}

@riverpod
Future<List<VerificationRequest>> myVerificationHistory(
  MyVerificationHistoryRef ref,
) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return [];
  return ref.read(verificationRepositoryProvider).getMyVerificationHistory(userId);
}
