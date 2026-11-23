/// 새 팀에 줄 `sort_order`. 기존 최대값 + 1.
///
/// 팀 개수를 쓰면 중간 팀을 삭제한 뒤 추가할 때 남은 팀과 값이 겹친다.
int nextTeamSortOrder(List<LeagueTeam> teams) {
  var max = -1;
  for (final t in teams) {
    if (t.sortOrder > max) max = t.sortOrder;
  }
  return max + 1;
}

/// 리그 팀 (팀전 전용).
///
/// 점수는 담지 않는다. 팀 점수는 팀원 각자의 개인 점수 합이므로
/// `buildTeamRanking` 이 순위 결과와 이 모델을 합쳐 계산한다.
class LeagueTeam {
  const LeagueTeam({
    required this.id,
    required this.leagueId,
    required this.name,
    required this.sortOrder,
    this.color,
    this.memberUserIds = const [],
  });

  final String id;
  final String leagueId;
  final String name;
  final String? color;
  final int sortOrder;

  /// 이 팀에 배정된 참가자 user_id 목록 (승인 여부와 무관하게 DB 그대로).
  final List<String> memberUserIds;

  factory LeagueTeam.fromRow(Map<String, dynamic> row) {
    final members = (row['league_participants'] as List?) ?? const [];
    return LeagueTeam(
      id: row['id'] as String,
      leagueId: row['league_id'] as String,
      name: row['name'] as String,
      color: row['color'] as String?,
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
      memberUserIds: members
          .map((m) => (m as Map<String, dynamic>)['user_id'] as String)
          .toList(growable: false),
    );
  }
}

/// 한 사람의 팀 배정 1건. `assign_league_teams` RPC 의 입력 원소이고,
/// `shuffle_league_teams` 가 돌려주는 스냅샷의 원소이기도 하다.
///
/// `teamId == null` 은 "미배정"이다.
class TeamAssignment {
  const TeamAssignment({required this.userId, this.teamId});

  final String userId;
  final String? teamId;

  Map<String, dynamic> toJson() => {'user_id': userId, 'team_id': teamId};

  factory TeamAssignment.fromJson(Map<String, dynamic> json) => TeamAssignment(
        userId: json['user_id'] as String,
        teamId: json['team_id'] as String?,
      );
}
