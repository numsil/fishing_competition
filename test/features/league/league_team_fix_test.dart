import 'package:flutter_test/flutter_test.dart';
import 'package:fishing_competition/core/theme/app_colors.dart';
import 'package:fishing_competition/features/league/data/league_repository.dart';
import 'package:fishing_competition/features/league/data/league_team_model.dart';
import 'package:fishing_competition/features/league/data/team_ranking.dart';
import 'package:fishing_competition/features/league/presentation/screens/league_detail_screen.dart';

LeagueRankEntry entry(String userId) => LeagueRankEntry(
      userId: userId,
      username: userId,
      bestLength: null,
      totalLength: 0,
      totalCount: 0,
      totalScore: 0,
      bestScore: 0,
      fishType: '배스',
      isLunker: false,
    );

LeagueTeam team(String id, {String? color, int sortOrder = 0}) => LeagueTeam(
      id: id,
      leagueId: 'L',
      name: id,
      color: color,
      sortOrder: sortOrder,
    );

void main() {
  // 팀 탭을 index 0 에 끼워 넣으면서 하단 "조과 등록" 버튼 조건이
  // index == 0 으로 남아 개인 순위 탭에서 버튼이 사라진 회귀.
  group('isRankingTabIndex', () {
    test('일반 리그는 순위 탭(0)에서만 조과 버튼을 보인다', () {
      expect(isRankingTabIndex(0, isTeamMode: false), isTrue);
      expect(isRankingTabIndex(1, isTeamMode: false), isFalse);
      expect(isRankingTabIndex(2, isTeamMode: false), isFalse);
    });

    test('팀전 리그는 팀 순위(0)와 개인 순위(1) 둘 다 조과 버튼을 보인다', () {
      expect(isRankingTabIndex(0, isTeamMode: true), isTrue);
      expect(isRankingTabIndex(1, isTeamMode: true), isTrue);
      expect(isRankingTabIndex(2, isTeamMode: true), isFalse);
      expect(isRankingTabIndex(3, isTeamMode: true), isFalse);
    });
  });

  // 팀 탭에서 멤버를 눌러 참가자 상세로 갈 때 순위 배지가 0 으로 찍히던 문제.
  group('rankByUserId', () {
    test('개인 순위 순서대로 1부터 매긴다', () {
      final map = rankByUserId([entry('a'), entry('b'), entry('c')]);
      expect(map, {'a': 1, 'b': 2, 'c': 3});
    });

    test('빈 순위는 빈 맵이다', () {
      expect(rankByUserId(const []), isEmpty);
    });
  });

  // 팀을 삭제한 뒤 추가하면 기존 팀과 색/정렬이 겹쳐 호스트가 구분할 수
  // 없게 되던 문제 (teams.length 를 인덱스로 쓴 탓).
  group('nextUnusedTeamColorKey', () {
    test('아직 쓰지 않은 첫 색을 고른다', () {
      final keys = AppColors.teamColors.keys.toList();
      expect(AppColors.nextUnusedTeamColorKey(const []), keys[0]);
      expect(AppColors.nextUnusedTeamColorKey([keys[0]]), keys[1]);
    });

    test('중간 색이 비면 그 색을 재사용한다', () {
      final keys = AppColors.teamColors.keys.toList();
      // 0, 2 를 쓰는 중 → 1 이 나와야 한다 (팔레트 길이를 인덱스로 쓰면 2 가 나온다)
      expect(AppColors.nextUnusedTeamColorKey([keys[0], keys[2]]), keys[1]);
    });

    test('팔레트를 다 쓰면 처음 색으로 되돌아간다', () {
      final keys = AppColors.teamColors.keys.toList();
      expect(AppColors.nextUnusedTeamColorKey(keys), keys[0]);
    });

    test('null 과 모르는 키는 사용 중으로 세지 않는다', () {
      final keys = AppColors.teamColors.keys.toList();
      expect(AppColors.nextUnusedTeamColorKey([null, 'NOPE']), keys[0]);
    });
  });

  group('nextTeamSortOrder', () {
    test('첫 팀은 0이다', () {
      expect(nextTeamSortOrder(const []), 0);
    });

    test('가장 큰 sort_order + 1 이다', () {
      expect(
        nextTeamSortOrder([team('A', sortOrder: 0), team('C', sortOrder: 2)]),
        3,
      );
    });

    test('팀을 지워 개수가 줄어도 기존 값과 겹치지 않는다', () {
      // A(0) 삭제 후 B(1), C(2) 만 남은 상태. 개수(2)를 쓰면 C 와 겹친다.
      expect(
        nextTeamSortOrder([team('B', sortOrder: 1), team('C', sortOrder: 2)]),
        3,
      );
    });
  });
}
