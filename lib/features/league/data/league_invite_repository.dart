import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../dm/data/dm_repository.dart';

part 'league_invite_repository.g.dart';

class LeagueInviteUserHit {
  const LeagueInviteUserHit({
    required this.id,
    required this.username,
    required this.userKey,
    this.avatarUrl,
  });
  final String id;
  final String username;
  final String userKey;
  final String? avatarUrl;
}

class LeagueInvite {
  const LeagueInvite({
    required this.id,
    required this.leagueId,
    required this.inviterId,
    required this.inviteeId,
    required this.status,
    required this.createdAt,
    this.respondedAt,
    this.leagueTitle,
    this.inviterUsername,
    this.inviterUserKey,
    this.inviterAvatarUrl,
    this.inviteeUsername,
    this.inviteeUserKey,
    this.inviteeAvatarUrl,
  });

  final String id;
  final String leagueId;
  final String inviterId;
  final String inviteeId;
  final String status; // pending | accepted | declined | canceled
  final DateTime createdAt;
  final DateTime? respondedAt;

  // 조인 데이터
  final String? leagueTitle;
  final String? inviterUsername;
  final String? inviterUserKey;
  final String? inviterAvatarUrl;
  final String? inviteeUsername;
  final String? inviteeUserKey;
  final String? inviteeAvatarUrl;
}

class LeagueInviteRepository {
  LeagueInviteRepository(this._supabase, this._dm);

  final SupabaseClient _supabase;
  final DmRepository _dm;

  String? get _myId => _supabase.auth.currentUser?.id;

  // ── user_key 검색 ────────────────────────────────────
  /// `@` 접두/공백 무시, 정확 매칭(대소문자 구분). 본인은 결과에서 제외.
  Future<LeagueInviteUserHit?> findUserByKey(String input) async {
    final myId = _myId;
    var key = input.trim();
    if (key.startsWith('@')) key = key.substring(1).trim();
    if (key.isEmpty) return null;

    final row = await _supabase
        .from('users')
        .select('id, username, user_key, avatar_url, status, is_deleted')
        .eq('user_key', key)
        .maybeSingle();

    if (row == null) return null;
    if (row['is_deleted'] == true) return null;
    if (row['status'] != 'active') return null;
    if (myId != null && row['id'] == myId) return null;

    return LeagueInviteUserHit(
      id: row['id'] as String,
      username: row['username'] as String? ?? '',
      userKey: row['user_key'] as String? ?? '',
      avatarUrl: row['avatar_url'] as String?,
    );
  }

  // ── 초대 생성 (RPC + DM 자동 발송) ───────────────────
  Future<String> inviteUser({
    required String leagueId,
    required String leagueTitle,
    required String inviteeId,
    required String inviterUsername,
  }) async {
    final inviteId = await _supabase.rpc(
      'create_league_invite',
      params: {'p_league_id': leagueId, 'p_invitee_id': inviteeId},
    ) as String;

    // DM 발송은 best-effort — 실패해도 초대 자체는 성공으로 간주
    try {
      final convId = await _dm.getOrCreateConversation(inviteeId);
      final msg =
          '$inviterUsername님이 \'$leagueTitle\' 리그에 초대했어요.\nhuk:///league/detail/$leagueId';
      await _dm.sendMessage(convId, msg);
    } catch (_) {
      // 무시
    }

    return inviteId;
  }

  // ── 초대 취소 (호스트) ───────────────────────────────
  Future<void> cancelInvite(String inviteId) async {
    await _supabase.rpc('cancel_league_invite',
        params: {'p_invite_id': inviteId});
  }

  // ── 초대 응답 (invitee) ──────────────────────────────
  Future<void> respondInvite(String inviteId, {required bool accept}) async {
    await _supabase.rpc('respond_league_invite',
        params: {'p_invite_id': inviteId, 'p_accept': accept});
  }

  // ── 보낸 초대 목록 (호스트 시점) ─────────────────────
  /// 기본: pending만. 전체 보려면 onlyPending=false.
  Future<List<LeagueInvite>> getSentInvites(
    String leagueId, {
    bool onlyPending = true,
  }) async {
    var q = _supabase
        .from('league_invites')
        .select(
          'id, league_id, inviter_id, invitee_id, status, created_at, responded_at, '
          'invitee:users!invitee_id(username, user_key, avatar_url)',
        )
        .eq('league_id', leagueId);
    if (onlyPending) q = q.eq('status', 'pending');

    final rows = await q.order('created_at', ascending: false);
    return rows.map((r) {
      final u = r['invitee'] as Map?;
      return LeagueInvite(
        id: r['id'] as String,
        leagueId: r['league_id'] as String,
        inviterId: r['inviter_id'] as String,
        inviteeId: r['invitee_id'] as String,
        status: r['status'] as String,
        createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
        respondedAt: r['responded_at'] == null
            ? null
            : DateTime.parse(r['responded_at'] as String).toLocal(),
        inviteeUsername: u?['username'] as String?,
        inviteeUserKey: u?['user_key'] as String?,
        inviteeAvatarUrl: u?['avatar_url'] as String?,
      );
    }).toList();
  }

  // ── 받은 초대 목록 (invitee 시점, pending만) ─────────
  Future<List<LeagueInvite>> getReceivedInvites() async {
    final myId = _myId;
    if (myId == null) return [];

    final rows = await _supabase
        .from('league_invites')
        .select(
          'id, league_id, inviter_id, invitee_id, status, created_at, responded_at, '
          'inviter:users!inviter_id(username, user_key, avatar_url), '
          'leagues!league_id(title, status)',
        )
        .eq('invitee_id', myId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);

    return rows
        .where((r) {
          final lg = r['leagues'] as Map?;
          final ls = lg?['status'] as String?;
          return ls == 'recruiting' || ls == 'in_progress';
        })
        .map((r) {
      final u = r['inviter'] as Map?;
      final lg = r['leagues'] as Map?;
      return LeagueInvite(
        id: r['id'] as String,
        leagueId: r['league_id'] as String,
        inviterId: r['inviter_id'] as String,
        inviteeId: r['invitee_id'] as String,
        status: r['status'] as String,
        createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
        respondedAt: r['responded_at'] == null
            ? null
            : DateTime.parse(r['responded_at'] as String).toLocal(),
        leagueTitle: lg?['title'] as String?,
        inviterUsername: u?['username'] as String?,
        inviterUserKey: u?['user_key'] as String?,
        inviterAvatarUrl: u?['avatar_url'] as String?,
      );
    }).toList();
  }

  // ── 특정 리그에 대한 내 pending 초대 1건 ─────────────
  Future<LeagueInvite?> getMyPendingInviteFor(String leagueId) async {
    final myId = _myId;
    if (myId == null) return null;

    final row = await _supabase
        .from('league_invites')
        .select('id, league_id, inviter_id, invitee_id, status, created_at, responded_at')
        .eq('league_id', leagueId)
        .eq('invitee_id', myId)
        .eq('status', 'pending')
        .maybeSingle();
    if (row == null) return null;
    return LeagueInvite(
      id: row['id'] as String,
      leagueId: row['league_id'] as String,
      inviterId: row['inviter_id'] as String,
      inviteeId: row['invitee_id'] as String,
      status: row['status'] as String,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      respondedAt: row['responded_at'] == null
          ? null
          : DateTime.parse(row['responded_at'] as String).toLocal(),
    );
  }
}

@riverpod
LeagueInviteRepository leagueInviteRepository(LeagueInviteRepositoryRef ref) {
  return LeagueInviteRepository(
    Supabase.instance.client,
    ref.watch(dmRepositoryProvider),
  );
}

@riverpod
Future<List<LeagueInvite>> sentLeagueInvites(
  SentLeagueInvitesRef ref,
  String leagueId,
) {
  final link = ref.keepAlive();
  Timer(const Duration(minutes: 3), link.close);
  return ref.watch(leagueInviteRepositoryProvider).getSentInvites(leagueId);
}

@riverpod
Future<List<LeagueInvite>> receivedLeagueInvites(
  ReceivedLeagueInvitesRef ref,
) {
  final link = ref.keepAlive();
  Timer(const Duration(minutes: 3), link.close);
  return ref.watch(leagueInviteRepositoryProvider).getReceivedInvites();
}

@riverpod
Future<LeagueInvite?> myPendingInviteForLeague(
  MyPendingInviteForLeagueRef ref,
  String leagueId,
) {
  final link = ref.keepAlive();
  Timer(const Duration(minutes: 3), link.close);
  return ref
      .watch(leagueInviteRepositoryProvider)
      .getMyPendingInviteFor(leagueId);
}
