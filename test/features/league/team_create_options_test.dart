import 'package:flutter_test/flutter_test.dart';
import 'package:fishing_competition/features/league/data/team_create_options.dart';

void main() {
  group('maxTeamCount — 최대 참가자 절반', () {
    // 팀이 성립하려면 최소 2명이다. 그래서 상한은 올림(참가자 ÷ 팀당 정원)
    // 이 아니라 내림(참가자 ÷ 2) 이다.
    //
    // 예전 공식은 `올림(참가자 ÷ 팀당 정원)` 이었는데, 그건 "전원을 앉히려면
    // 최소 몇 팀이 필요한가" 이고 최대값이 아니다. 실기기에서 잡힌 버그:
    // 정원 12 · 참가자 12 인 리그가 상한 1팀으로 계산돼서, 첫 사람이 팀을
    // 만들면 나머지 전원이 막혔다.
    test('참가자의 절반', () {
      expect(maxTeamCount(maxParticipants: 12), 6);
      expect(maxTeamCount(maxParticipants: 20), 10);
      expect(maxTeamCount(maxParticipants: 100), 50);
    });

    test('홀수면 내림', () {
      // 15명이면 2명씩 7팀 + 1명은 어느 팀에 끼어야 한다.
      expect(maxTeamCount(maxParticipants: 15), 7);
    });

    test('팀당 정원과 무관하다', () {
      // 정원 12 는 "12명 1팀" 도 "2명 6팀" 도 유효하다. 정원으로는
      // 최대 팀 수를 역산할 수 없다.
      expect(maxTeamCount(maxParticipants: 12), 6);
    });

    test('아주 작은 리그도 최소 2팀은 만들 수 있다', () {
      // 내림만 쓰면 3명 리그가 1팀이 되어 팀전이 성립하지 않는다.
      expect(maxTeamCount(maxParticipants: 3), 2);
      expect(maxTeamCount(maxParticipants: 2), 2);
      expect(maxTeamCount(maxParticipants: 1), 2);
    });

    test('참가자 수가 없으면(0) 상한 없음(0)', () {
      // leagues.max_participants 는 DB 에서 nullable 이다. 셀 근거가 없으면
      // 막지 않는다 — 막으면 팀을 아예 만들 수 없다.
      expect(maxTeamCount(maxParticipants: 0), 0);
    });
  });

  group('canCreateTeam — 팀 만들기 버튼을 보여줄 것인가', () {
    test('자율 선택 + 승인된 참가자 + 자리 남음 → 가능', () {
      expect(
          canCreateTeam(
              isSelfPick: true,
              isApprovedParticipant: true,
              teamCount: 2,
              maxTeams: 4),
          isTrue);
    });

    test('호스트 배정 리그에서는 불가', () {
      expect(
          canCreateTeam(
              isSelfPick: false,
              isApprovedParticipant: true,
              teamCount: 0,
              maxTeams: 4),
          isFalse);
    });

    test('승인 대기·비참가자는 불가', () {
      // RPC 가 NOT_PARTICIPANT 로 거부하므로 버튼을 보여주면 거짓말이 된다.
      expect(
          canCreateTeam(
              isSelfPick: true,
              isApprovedParticipant: false,
              teamCount: 0,
              maxTeams: 4),
          isFalse);
    });

    test('상한에 도달하면 불가', () {
      expect(
          canCreateTeam(
              isSelfPick: true,
              isApprovedParticipant: true,
              teamCount: 4,
              maxTeams: 4),
          isFalse);
      // 호스트가 정원을 낮춰 상한을 넘긴 경우도 막는다.
      expect(
          canCreateTeam(
              isSelfPick: true,
              isApprovedParticipant: true,
              teamCount: 6,
              maxTeams: 4),
          isFalse);
    });

    test('상한 없음(0)이면 팀이 몇 개든 가능', () {
      expect(
          canCreateTeam(
              isSelfPick: true,
              isApprovedParticipant: true,
              teamCount: 99,
              maxTeams: 0),
          isTrue);
    });
  });

  group('teamCreateErrorMessage — 실패 문구', () {
    test('상한 초과는 상한을 알려준다', () {
      final m = teamCreateErrorMessage(
          Exception('PostgrestException(message: TEAM_LIMIT_REACHED)'));
      expect(m, contains('더 만들 수 없습니다'));
    });

    test('이름 중복은 이름을 바꾸라고 알려준다', () {
      final m = teamCreateErrorMessage(Exception(
          'PostgrestException(message: duplicate key value violates unique constraint "league_teams_league_id_name_key")'));
      expect(m, contains('같은 이름'));
    });

    test('빈 이름', () {
      final m = teamCreateErrorMessage(
          Exception('league_teams_name_not_blank'));
      expect(m, contains('팀 이름'));
    });

    test('자율 선택이 꺼졌으면 그 사실을 알려준다', () {
      // 화면을 열어둔 사이 호스트가 방식을 바꾼 경우다.
      final m = teamCreateErrorMessage(
          Exception('PostgrestException(message: SELF_PICK_DISABLED)'));
      expect(m, contains('호스트'));
    });

    test('모르는 오류는 일반 문구로 떨어진다', () {
      expect(teamCreateErrorMessage(Exception('SocketException')),
          contains('실패'));
    });
  });
}
