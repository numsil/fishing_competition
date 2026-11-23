import 'league_repository.dart' show LeagueRankEntry;
import 'league_team_model.dart';

/// 팀 하나의 순위 행. `team == null` 이면 미배정 그룹이다.
class LeagueTeamRank {
  const LeagueTeamRank({
    required this.team,
    required this.members,
    required this.totalMeasure,
    required this.totalCount,
    required this.bestMeasure,
  });

  final LeagueTeam? team;

  /// 팀 점수 기여가 큰 순으로 정렬된 멤버 (개인 순위 그대로의 값).
  final List<LeagueRankEntry> members;

  /// 팀원 개인 점수(cm 또는 g)의 합.
  final double totalMeasure;

  /// 팀원 마릿수의 합.
  final int totalCount;

  /// 팀 내 최대어 (동점 처리용).
  final double bestMeasure;

  bool get isUnassigned => team == null;
  int get memberCount => members.length;
}

/// `get_league_ranking` 결과 순서에서 user_id → 개인 순위(1부터).
///
/// 팀 탭에서 멤버를 눌러 참가자 상세로 보낼 때 쓴다. 상세 화면은 받은 rank 를
/// 아바타 배지에 그대로 찍으므로 0 을 넘기면 "0" 배지가 보인다.
Map<String, int> rankByUserId(List<LeagueRankEntry> ranking) {
  return {
    for (var i = 0; i < ranking.length; i++) ranking[i].userId: i + 1,
  };
}

/// 개인 순위를 팀으로 묶어 팀 순위를 만든다.
///
/// 점수 규칙은 전혀 재계산하지 않는다. [ranking] 은 `get_league_ranking`
/// 결과이고, 리그의 rule/catch_limit 은 이미 그 안에서 각 개인에게 적용돼
/// 있다. 여기서 하는 일은 합산과 정렬뿐이다.
///
/// [rule] 이 '마릿수' 면 마릿수로 정렬한다. 그 룰에서는 길이·무게가 아니라
/// 마릿수가 점수이기 때문이다 (기존 `get_league_ranking` 의 개인 정렬도
/// 마릿수를 1순위로 쓴다). 참고로 마릿수 리그에서도 `totalLength` 는 0이
/// 아니라 길이 합으로 채워져 오므로, 측정값으로 정렬하면 "동점"이 되는 게
/// 아니라 "엉뚱한 기준(길이)으로 정렬"된다. prod 실측 확인함.
List<LeagueTeamRank> buildTeamRanking({
  required List<LeagueRankEntry> ranking,
  required List<LeagueTeam> teams,
  required String rule,
}) {
  final byUserId = {for (final e in ranking) e.userId: e};
  final isCountRule = rule == '마릿수';

  final assigned = <String>{};
  final rows = <LeagueTeamRank>[];

  for (final team in teams) {
    final members = <LeagueRankEntry>[];
    for (final userId in team.memberUserIds) {
      final e = byUserId[userId];
      if (e == null) continue; // 탈퇴·미승인 → 순위에 없음
      members.add(e);
      assigned.add(userId);
    }
    rows.add(_rank(team, members, isCountRule));
  }

  final leftovers = ranking.where((e) => !assigned.contains(e.userId)).toList();
  final unassigned =
      leftovers.isEmpty ? null : _rank(null, leftovers, isCountRule);

  rows.sort((a, b) {
    if (isCountRule) {
      final c = b.totalCount.compareTo(a.totalCount);
      if (c != 0) return c;
    }
    final m = b.totalMeasure.compareTo(a.totalMeasure);
    if (m != 0) return m;
    final best = b.bestMeasure.compareTo(a.bestMeasure);
    if (best != 0) return best;
    // 같은 점수라면 적은 조과로 낸 팀이 앞선다
    return a.totalCount.compareTo(b.totalCount);
  });

  return [...rows, if (unassigned != null) unassigned];
}

LeagueTeamRank _rank(
  LeagueTeam? team,
  List<LeagueRankEntry> members,
  bool isCountRule,
) {
  var measure = 0.0;
  var count = 0;
  var best = 0.0;
  for (final e in members) {
    measure += e.totalLength;
    count += e.totalCount;
    final b = e.bestLength ?? 0;
    if (b > best) best = b;
  }

  final sorted = [...members]..sort((a, b) {
    if (isCountRule) {
      final c = b.totalCount.compareTo(a.totalCount);
      if (c != 0) return c;
    }
    return b.totalLength.compareTo(a.totalLength);
  });

  return LeagueTeamRank(
    team: team,
    members: sorted,
    totalMeasure: measure,
    totalCount: count,
    bestMeasure: best,
  );
}
