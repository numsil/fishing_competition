import 'package:flutter_test/flutter_test.dart';
import 'package:fishing_competition/features/league/data/league_repository.dart';
import 'package:fishing_competition/features/league/data/league_team_model.dart';
import 'package:fishing_competition/features/league/data/team_ranking.dart';

LeagueRankEntry entry(
  String userId, {
  double totalLength = 0,
  int totalCount = 0,
  double? bestLength,
}) {
  return LeagueRankEntry(
    userId: userId,
    username: userId,
    bestLength: bestLength,
    totalLength: totalLength,
    totalCount: totalCount,
    totalScore: 0,
    bestScore: 0,
    fishType: '배스',
    isLunker: false,
  );
}

LeagueTeam team(String id, List<String> members, {int sortOrder = 0}) {
  return LeagueTeam(
    id: id,
    leagueId: 'L',
    name: id,
    sortOrder: sortOrder,
    memberUserIds: members,
  );
}

void main() {
  group('buildTeamRanking', () {
    test('팀 점수는 팀원 각자의 개인 점수 합이다', () {
      final result = buildTeamRanking(
        ranking: [
          entry('갑', totalLength: 203, totalCount: 4, bestLength: 92),
          entry('을', totalLength: 86, totalCount: 1, bestLength: 86),
          entry('병', totalLength: 138, totalCount: 2, bestLength: 70),
          entry('정', totalLength: 55, totalCount: 1, bestLength: 55),
          entry('무'),
        ],
        teams: [team('A', ['갑', '을', '병', '정', '무'])],
        rule: '합산 길이',
      );

      expect(result, hasLength(1));
      expect(result.first.totalMeasure, 482);
      expect(result.first.totalCount, 8);
      expect(result.first.bestMeasure, 92);
      // 조과 0마리 참가자도 인원에 포함된다
      expect(result.first.members, hasLength(5));
    });

    test('팀 점수가 높은 순으로 정렬된다', () {
      final result = buildTeamRanking(
        ranking: [
          entry('a', totalLength: 100, totalCount: 1, bestLength: 100),
          entry('b', totalLength: 300, totalCount: 2, bestLength: 160),
        ],
        teams: [team('A', ['a'], sortOrder: 0), team('B', ['b'], sortOrder: 1)],
        rule: '합산 길이',
      );

      expect(result.map((t) => t.team!.name), ['B', 'A']);
    });

    test('마릿수 룰은 totalCount 로 정렬한다', () {
      // 마릿수 룰에서는 totalLength 가 0으로 들어온다.
      // 측정값으로 정렬하면 전 팀이 동점이 되어 순위가 뒤집힌다.
      final result = buildTeamRanking(
        ranking: [
          entry('a', totalCount: 2),
          entry('b', totalCount: 7),
        ],
        teams: [team('A', ['a'], sortOrder: 0), team('B', ['b'], sortOrder: 1)],
        rule: '마릿수',
      );

      expect(result.map((t) => t.team!.name), ['B', 'A']);
      expect(result.first.totalCount, 7);
    });

    test('동점이면 최대어가 큰 팀, 그다음 조과 수가 적은 팀이 앞선다', () {
      final result = buildTeamRanking(
        ranking: [
          entry('a', totalLength: 100, totalCount: 2, bestLength: 60),
          entry('b', totalLength: 100, totalCount: 2, bestLength: 90),
          entry('c', totalLength: 100, totalCount: 4, bestLength: 90),
        ],
        teams: [
          team('A', ['a'], sortOrder: 0),
          team('B', ['b'], sortOrder: 1),
          team('C', ['c'], sortOrder: 2),
        ],
        rule: '합산 길이',
      );

      // B·C 는 점수·최대어 동일 → 조과 수 적은 B 가 앞
      expect(result.map((t) => t.team!.name), ['B', 'C', 'A']);
    });

    test('미배정 참가자는 팀 점수에 섞이지 않고 맨 끝 그룹으로 나온다', () {
      final result = buildTeamRanking(
        ranking: [
          entry('a', totalLength: 100, totalCount: 1, bestLength: 100),
          entry('solo', totalLength: 9999, totalCount: 9, bestLength: 500),
        ],
        teams: [team('A', ['a'])],
        rule: '합산 길이',
      );

      expect(result, hasLength(2));
      expect(result.first.isUnassigned, isFalse);
      expect(result.first.totalMeasure, 100);

      final last = result.last;
      expect(last.isUnassigned, isTrue);
      expect(last.team, isNull);
      expect(last.members.single.userId, 'solo');
    });

    test('팀이 없으면 전원이 미배정 한 그룹이다', () {
      final result = buildTeamRanking(
        ranking: [entry('a', totalLength: 10, totalCount: 1, bestLength: 10)],
        teams: const [],
        rule: '합산 길이',
      );

      expect(result, hasLength(1));
      expect(result.single.isUnassigned, isTrue);
    });

    test('미배정자가 없으면 미배정 그룹을 만들지 않는다', () {
      final result = buildTeamRanking(
        ranking: [entry('a', totalLength: 10, totalCount: 1, bestLength: 10)],
        teams: [team('A', ['a'])],
        rule: '합산 길이',
      );

      expect(result, hasLength(1));
      expect(result.single.isUnassigned, isFalse);
    });

    test('순위에 없는 멤버 id 는 무시한다 (탈퇴·미승인)', () {
      final result = buildTeamRanking(
        ranking: [entry('a', totalLength: 10, totalCount: 1, bestLength: 10)],
        teams: [team('A', ['a', 'ghost'])],
        rule: '합산 길이',
      );

      expect(result.single.members, hasLength(1));
      expect(result.single.totalMeasure, 10);
    });

    test('멤버는 기여가 큰 순으로 정렬된다', () {
      final result = buildTeamRanking(
        ranking: [
          entry('small', totalLength: 20, totalCount: 1, bestLength: 20),
          entry('big', totalLength: 90, totalCount: 2, bestLength: 50),
          entry('zero'),
        ],
        teams: [team('A', ['small', 'zero', 'big'])],
        rule: '합산 길이',
      );

      expect(result.single.members.map((m) => m.userId), ['big', 'small', 'zero']);
    });

    test('조과가 전혀 없는 팀전 리그도 예외 없이 0점 팀을 돌려준다', () {
      final result = buildTeamRanking(
        ranking: [entry('a'), entry('b')],
        teams: [team('A', ['a'], sortOrder: 0), team('B', ['b'], sortOrder: 1)],
        rule: '합산 길이',
      );

      expect(result, hasLength(2));
      expect(result.every((t) => t.totalMeasure == 0), isTrue);
      expect(result.every((t) => t.memberCount == 1), isTrue);
    });

    test('멤버가 0명인 팀도 순위에 남는다', () {
      final result = buildTeamRanking(
        ranking: [entry('a', totalLength: 10, totalCount: 1, bestLength: 10)],
        teams: [team('A', ['a'], sortOrder: 0), team('EMPTY', const [], sortOrder: 1)],
        rule: '합산 길이',
      );

      expect(result, hasLength(2));
      expect(result.last.team!.name, 'EMPTY');
      expect(result.last.memberCount, 0);
      expect(result.last.totalMeasure, 0);
    });

    test('무게 룰도 측정값 합산 경로를 그대로 쓴다', () {
      // get_league_ranking 이 무게(g)를 totalLength 컬럼에 담아 준다.
      final result = buildTeamRanking(
        ranking: [
          entry('a', totalLength: 1200, totalCount: 2, bestLength: 800),
          entry('b', totalLength: 3000, totalCount: 1, bestLength: 3000),
        ],
        teams: [team('A', ['a'], sortOrder: 0), team('B', ['b'], sortOrder: 1)],
        rule: '무게',
      );

      expect(result.map((t) => t.team!.name), ['B', 'A']);
      expect(result.first.totalMeasure, 3000);
    });
  });
}
