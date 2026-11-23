// 리그 상세 화면의 탭 구성 규칙.
//
// 탭 목록과 TabController 길이, TabBarView 의 children 이 서로 어긋나면
// 화면이 즉시 크래시한다. 그래서 세 곳이 **같은 리스트 하나**를 쓰도록
// 여기서 순서까지 정하고, 조건은 이 파일에서만 판단한다.

/// 리그 상세의 탭 종류. 리스트의 순서가 화면의 순서다.
enum LeagueDetailTab { team, participants, review, info }

/// 모집중인 리그의 참가자 명단을 볼 수 있는가.
///
/// 신청하지 않은 사람에게는 명단을 열지 않는다. 승인 대기는 포함한다 —
/// 자기가 들어갈 리그에 누가 있는지 보고 취소를 판단할 수 있어야 한다.
/// 거절·강퇴(`rejected`)는 신청한 적이 있어도 제외한다.
bool canSeeParticipantList({required String? myStatus, required bool isHost}) =>
    isHost || myStatus == 'pending' || myStatus == 'approved';

/// 이 리그 상세에 띄울 탭. 빈 리스트면 탭 없이 `대회 정보` 한 장만 그린다.
///
/// 진행중·종료된 리그는 지금까지처럼 누구에게나 탭을 준다. 모집중은
/// [canSeeParticipantList] 를 통과한 사람에게만 준다.
List<LeagueDetailTab> leagueDetailTabs({
  required String status,
  required bool isTeamMode,
  required bool isHost,
  required String? myStatus,
}) {
  final started = status == 'in_progress' || status == 'completed';
  final preStart = status == 'recruiting' &&
      canSeeParticipantList(myStatus: myStatus, isHost: isHost);
  if (!started && !preStart) return const [];

  return [
    if (isTeamMode) LeagueDetailTab.team,
    LeagueDetailTab.participants,
    // 심사할 조과는 리그가 돌아가는 동안에만 생긴다.
    if (isHost && status == 'in_progress') LeagueDetailTab.review,
    LeagueDetailTab.info,
  ];
}

/// 탭에 붙일 이름. 모집중에는 조과가 0이므로 "순위" 라고 부르지 않는다.
String leagueDetailTabLabel(LeagueDetailTab tab, String status) {
  final preStart = status == 'recruiting';
  switch (tab) {
    case LeagueDetailTab.team:
      return preStart ? '팀' : '팀 순위';
    case LeagueDetailTab.participants:
      if (preStart) return '참가자';
      return status == 'completed' ? '최종 순위' : '실시간 순위';
    case LeagueDetailTab.review:
      return '심사';
    case LeagueDetailTab.info:
      return '대회 정보';
  }
}
