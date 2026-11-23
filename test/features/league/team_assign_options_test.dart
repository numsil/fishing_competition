import 'package:flutter_test/flutter_test.dart';
import 'package:fishing_competition/features/league/data/league_repository.dart';
import 'package:fishing_competition/features/league/data/team_assign_options.dart';

LeagueRankEntry p(String userId, {int count = 0}) => LeagueRankEntry(
      userId: userId,
      username: userId,
      bestLength: null,
      totalLength: 0,
      totalCount: count,
      totalScore: 0,
      bestScore: 0,
      fishType: '배스',
      isLunker: false,
    );

void main() {
  group('memberAddCandidates — 기본은 미배정만, 검색하면 넓어진다', () {
    final participants = [p('무배정1'), p('무배정2'), p('A소속'), p('B소속'), p('내팀원')];
    const teamIdByUserId = <String, String?>{
      '무배정1': null,
      '무배정2': null,
      'A소속': 'tA',
      'B소속': 'tB',
      '내팀원': 'tMine',
    };

    test('검색어가 없으면 미배정자만 보여준다', () {
      // 전체 명단을 기본으로 깔면 `전체 선택` 이 "모두 이 팀으로"가 되어
      // 되돌릴 수 없는 일괄 이동이 한 번의 탭으로 일어난다.
      final r = memberAddCandidates(
        participants: participants,
        teamIdByUserId: teamIdByUserId,
        thisTeamId: 'tMine',
        query: '',
      );
      expect(r.map((e) => e.userId), ['무배정1', '무배정2']);
    });

    test('검색하면 다른 팀 소속도 결과에 나온다', () {
      final r = memberAddCandidates(
        participants: participants,
        teamIdByUserId: teamIdByUserId,
        thisTeamId: 'tMine',
        query: '소속',
      );
      expect(r.map((e) => e.userId), ['A소속', 'B소속']);
    });

    test('검색해도 이 팀 멤버는 후보에 넣지 않는다', () {
      final r = memberAddCandidates(
        participants: participants,
        teamIdByUserId: teamIdByUserId,
        thisTeamId: 'tMine',
        query: '내팀',
      );
      expect(r, isEmpty);
    });

    test('검색은 대소문자를 무시한다', () {
      final r = memberAddCandidates(
        participants: [p('Bass'), p('carp')],
        teamIdByUserId: const {'Bass': null, 'carp': null},
        thisTeamId: 'tMine',
        query: 'BA',
      );
      expect(r.map((e) => e.userId), ['Bass']);
    });

    test('미배정자가 없으면 검색 전에는 빈 목록이다', () {
      final r = memberAddCandidates(
        participants: [p('A소속')],
        teamIdByUserId: const {'A소속': 'tA'},
        thisTeamId: 'tMine',
        query: '',
      );
      expect(r, isEmpty);
    });
  });

  group('canPickTeam — 단건 이동에서 고를 수 있는 팀인가', () {
    test('정원이 남으면 고를 수 있다', () {
      expect(
          canPickTeam(isCurrentTeam: false, capacity: 5, memberCount: 4),
          isTrue);
    });

    test('정원이 찬 팀은 고를 수 없다', () {
      // 서버가 TEAM_FULL 로 거부하고 UI 는 "방금 정원이 찼습니다" 를 띄운다.
      // 시트를 열기 전부터 꽉 차 있었으므로 "방금"이 거짓말이 된다.
      expect(
          canPickTeam(isCurrentTeam: false, capacity: 5, memberCount: 5),
          isFalse);
      expect(
          canPickTeam(isCurrentTeam: false, capacity: 3, memberCount: 6),
          isFalse);
    });

    test('무제한이면 항상 고를 수 있다', () {
      expect(
          canPickTeam(isCurrentTeam: false, capacity: 0, memberCount: 999),
          isTrue);
    });

    test('현재 소속 팀은 꽉 차 있어도 고를 수 있다', () {
      // 이동이 없는 멱등 선택이고, 서버도 본인을 빼고 세어 통과시킨다.
      expect(
          canPickTeam(isCurrentTeam: true, capacity: 5, memberCount: 5),
          isTrue);
    });
  });

  group('undoFailureMessage — 되돌리기 실패 문구', () {
    test('정원 때문에 막히면 정원을 올리라고 알려준다', () {
      // "다른 팀을 골라주세요" 는 되돌리기에서 따를 수 없는 지시다.
      // 되돌리기는 팀을 고르는 동작이 아니다.
      final m = undoFailureMessage(
          Exception('PostgrestException(message: TEAM_FULL)'));
      expect(m, isNotNull);
      expect(m, contains('정원'));
      expect(m, isNot(contains('다른 팀을 골라')));
    });

    test('정원 문제가 아니면 null 을 돌려 기본 문구를 쓰게 한다', () {
      expect(
          undoFailureMessage(
              Exception('PostgrestException(message: TEAM_NOT_IN_LEAGUE)')),
          isNull);
      expect(undoFailureMessage(Exception('SocketException')), isNull);
    });
  });

  group('canClearCapacityDraft — 낙관적 값을 언제 버려도 되는가', () {
    test('서버 값이 아직 따라오지 않았으면 draft 를 유지한다', () {
      // 실기기에서 잡힌 버그다. 저장 직후 draft 를 비우면 재조회가 끝나기
      // 전까지 이전 서버 값(5)이 한 프레임 보여서 6 → 5 → 6 으로 깜빡인다.
      expect(canClearCapacityDraft(draft: 6, serverCapacity: 5), isFalse);
    });

    test('서버 값이 draft 와 같아지면 버려도 된다', () {
      expect(canClearCapacityDraft(draft: 6, serverCapacity: 6), isTrue);
    });

    test('draft 가 없으면 비울 것도 없다', () {
      expect(canClearCapacityDraft(draft: null, serverCapacity: 5), isTrue);
    });

    test('0(무제한)도 일반 값과 똑같이 비교한다', () {
      expect(canClearCapacityDraft(draft: 0, serverCapacity: 5), isFalse);
      expect(canClearCapacityDraft(draft: 0, serverCapacity: 0), isTrue);
    });
  });
}
