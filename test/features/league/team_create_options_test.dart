import 'package:flutter_test/flutter_test.dart';
import 'package:fishing_competition/features/league/data/team_create_options.dart';

void main() {
  group('maxTeamCount — 정원으로 역산한 팀 수 상한', () {
    test('나누어떨어지면 그 값', () {
      expect(maxTeamCount(maxParticipants: 20, capacity: 5), 4);
    });

    test('나누어떨어지지 않으면 올림', () {
      // 22명/정원 5 → 4팀이면 20자리뿐이라 2명이 들어갈 팀이 없다.
      expect(maxTeamCount(maxParticipants: 22, capacity: 5), 5);
      expect(maxTeamCount(maxParticipants: 21, capacity: 5), 5);
    });

    test('정원 무제한(0)이면 상한 없음(0)', () {
      // 정원이 없으면 한 팀에 전원이 들어갈 수 있어서 역산할 근거가 없다.
      expect(maxTeamCount(maxParticipants: 20, capacity: 0), 0);
    });

    test('정원이 참가자보다 크면 1팀', () {
      expect(maxTeamCount(maxParticipants: 4, capacity: 10), 1);
    });

    test('정원 1명이면 참가자 수만큼', () {
      expect(maxTeamCount(maxParticipants: 6, capacity: 1), 6);
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
