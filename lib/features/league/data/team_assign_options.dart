import 'league_repository.dart' show LeagueRankEntry;
import 'team_capacity.dart';

/// 팀 배정 UI 가 "무엇을 고를 수 있는가"를 판단하는 순수 함수.
///
/// UI 가 직접 계산하면 서버 RPC 의 검증과 어긋나고, 어긋남을 테스트할 수
/// 없다. 정원 산술은 [team_capacity.dart] 를 재사용한다.

/// `팀원 추가` 시트의 후보 목록.
///
/// 검색어가 없으면 **미배정자만** 보여준다. 전체 명단을 기본으로 깔면
/// `전체 선택` 이 "모두 이 팀으로"가 되어, 되돌릴 수 없는 일괄 이동이
/// 한 번의 탭으로 일어난다 (이 경로에는 되돌리기가 없다).
///
/// 검색어가 있으면 다른 팀 소속까지 넓힌다 — 팀 간 이동을 같은 화면에서
/// 할 수 있어야 하기 때문이다. 어느 쪽이든 **이 팀의 현재 멤버는 제외**한다.
///
/// [teamIdByUserId] 는 `userId → teamId?` 이고 `null` 이 미배정이다.
List<LeagueRankEntry> memberAddCandidates({
  required List<LeagueRankEntry> participants,
  required Map<String, String?> teamIdByUserId,
  required String thisTeamId,
  required String query,
}) {
  final q = query.trim().toLowerCase();
  return participants.where((e) {
    if (teamIdByUserId[e.userId] == thisTeamId) return false;
    if (q.isEmpty) return teamIdByUserId[e.userId] == null;
    return e.username.toLowerCase().contains(q);
  }).toList(growable: false);
}

/// 단건 이동 시트에서 이 팀을 고를 수 있는가.
///
/// 현재 소속 팀은 정원이 차 있어도 고를 수 있다 — 이동이 없는 멱등 선택이고
/// 서버도 본인을 빼고 세어 통과시킨다. 그 외 꽉 찬 팀은 막아야 한다.
/// 막지 않으면 서버가 `TEAM_FULL` 을 던지고 UI 는 "방금 정원이 찼습니다"를
/// 띄우는데, 시트를 열기 전부터 꽉 차 있었으므로 "방금"이 거짓말이 된다.
bool canPickTeam({
  required bool isCurrentTeam,
  required int capacity,
  required int memberCount,
}) {
  if (isCurrentTeam) return true;
  return !isTeamFull(capacity: capacity, memberCount: memberCount);
}

/// 셔플 되돌리기가 실패했을 때 쓸 전용 문구. 해당 없으면 `null`.
///
/// 되돌리기는 팀을 고르는 동작이 아니므로 일반 `TEAM_FULL` 문구
/// ("다른 팀을 골라주세요")는 따를 수 없는 지시가 된다. 이 상황은
/// 셔플 후 호스트가 정원을 낮춰, 복구하면 정원을 넘는 팀이 생길 때 발생한다.
String? undoFailureMessage(Object error) {
  if (error.toString().contains('TEAM_FULL')) {
    return '정원을 낮춰서 셔플 전 배정으로 되돌릴 수 없습니다. 정원을 올린 뒤 다시 시도해주세요.';
  }
  return null;
}

/// 낙관적으로 올려둔 정원 값(draft)을 비워도 되는가.
///
/// 저장이 성공했어도 서버 값이 아직 재조회되지 않았으면 비우면 안 된다.
/// 비우는 순간 화면은 캐시에 남은 **이전** 값으로 떨어지고, 재조회가 끝나면
/// 다시 올라와서 `6 → 5 → 6` 으로 깜빡인다.
bool canClearCapacityDraft({required int? draft, required int serverCapacity}) =>
    draft == null || draft == serverCapacity;
