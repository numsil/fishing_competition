// 참가자가 팀을 직접 만들 때의 규칙. 순수 함수만 둔다.
//
// 팀 개수에 상한이 없으면 20명 리그에서 20명이 각자 1인 팀을 만들어
// 팀 순위가 개인 순위와 똑같아진다. 상한은 `create_my_league_team` RPC 가
// 최종 판정하고(동시 생성 때문에), 이 파일은 **같은 규칙**으로 버튼을
// 보여줄지 결정한다. 두 곳이 어긋나면 버튼이 거짓말을 한다.

/// 참가자가 만들 수 있는 팀의 최대 개수. `0` 은 상한 없음.
///
/// `올림(최대 참가자 ÷ 팀당 정원)`. 내림이면 자리가 모자라 어느 팀에도
/// 못 들어가는 참가자가 생긴다 (22명/정원 5 → 4팀 = 20자리).
///
/// 정원이 무제한이면 한 팀에 전원이 들어갈 수 있어서 역산할 근거가 없다.
int maxTeamCount({required int maxParticipants, required int capacity}) {
  if (capacity <= 0 || maxParticipants <= 0) return 0;
  return (maxParticipants + capacity - 1) ~/ capacity;
}

/// `팀 만들기` 를 할 수 있는가.
///
/// [maxTeams] 는 [maxTeamCount] 의 결과 (`0` = 상한 없음).
/// 승인 대기자에게는 보여주지 않는다 — RPC 가 `NOT_PARTICIPANT` 로 거부하므로
/// 버튼이 있으면 눌러야만 알 수 있는 거짓말이 된다.
bool canCreateTeam({
  required bool isSelfPick,
  required bool isApprovedParticipant,
  required int teamCount,
  required int maxTeams,
}) {
  if (!isSelfPick || !isApprovedParticipant) return false;
  return maxTeams == 0 || teamCount < maxTeams;
}

/// 팀 생성 실패 문구.
///
/// 원인별로 따를 수 있는 다음 행동이 다르다. 하나로 뭉치면 이름만 바꾸면
/// 되는 경우에도 사용자가 포기한다.
String teamCreateErrorMessage(Object error) {
  final s = error.toString();
  if (s.contains('TEAM_LIMIT_REACHED')) {
    return '팀을 더 만들 수 없습니다. 정원에 맞는 팀 수가 이미 다 찼습니다.';
  }
  if (s.contains('league_teams_league_id_name_key')) {
    return '같은 이름의 팀이 이미 있습니다. 다른 이름을 써주세요.';
  }
  if (s.contains('league_teams_name_not_blank') ||
      s.contains('TEAM_NAME_BLANK')) {
    return '팀 이름을 입력해주세요.';
  }
  if (s.contains('TEAM_NAME_TOO_LONG')) {
    return '팀 이름이 너무 깁니다.';
  }
  if (s.contains('SELF_PICK_DISABLED')) {
    return '호스트가 팀 선택 방식을 바꿨습니다. 팀은 호스트가 배정합니다.';
  }
  if (s.contains('NOT_PARTICIPANT')) {
    return '참가가 승인된 뒤에 팀을 만들 수 있습니다.';
  }
  return '팀 생성 실패: $error';
}
