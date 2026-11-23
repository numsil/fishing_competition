import 'package:flutter_test/flutter_test.dart';
import 'package:fishing_competition/features/league/data/league_detail_tabs.dart';

void main() {
  group('canSeeParticipantList — 모집중 명단을 누가 보는가', () {
    test('신청하지 않은 사람은 못 본다', () {
      expect(canSeeParticipantList(myStatus: null, isHost: false), isFalse);
    });

    test('승인 대기도 볼 수 있다', () {
      // 자기가 들어갈 리그에 누가 있는지 보고 취소를 판단할 수 있어야 한다.
      expect(canSeeParticipantList(myStatus: 'pending', isHost: false), isTrue);
    });

    test('참가 완료는 볼 수 있다', () {
      expect(canSeeParticipantList(myStatus: 'approved', isHost: false), isTrue);
    });

    test('거절·강퇴된 사람은 못 본다', () {
      expect(canSeeParticipantList(myStatus: 'rejected', isHost: false), isFalse);
    });

    test('호스트는 신청 여부와 무관하게 본다', () {
      expect(canSeeParticipantList(myStatus: null, isHost: true), isTrue);
    });
  });

  group('leagueDetailTabs — 탭 구성', () {
    test('모집중 + 미신청이면 탭이 없다 (대회 정보 한 장)', () {
      expect(
        leagueDetailTabs(
            status: 'recruiting',
            isTeamMode: false,
            isHost: false,
            myStatus: null),
        isEmpty,
      );
    });

    test('모집중 + 개인전 참가자는 참가자/대회 정보', () {
      expect(
        leagueDetailTabs(
            status: 'recruiting',
            isTeamMode: false,
            isHost: false,
            myStatus: 'approved'),
        [LeagueDetailTab.participants, LeagueDetailTab.info],
      );
    });

    test('모집중 + 팀전 참가자는 팀/참가자/대회 정보', () {
      expect(
        leagueDetailTabs(
            status: 'recruiting',
            isTeamMode: true,
            isHost: false,
            myStatus: 'approved'),
        [
          LeagueDetailTab.team,
          LeagueDetailTab.participants,
          LeagueDetailTab.info
        ],
      );
    });

    test('모집중에는 호스트에게도 심사 탭을 주지 않는다', () {
      // 심사할 조과가 존재할 수 없다.
      expect(
        leagueDetailTabs(
            status: 'recruiting',
            isTeamMode: false,
            isHost: true,
            myStatus: null),
        [LeagueDetailTab.participants, LeagueDetailTab.info],
      );
    });

    test('진행중은 신청 여부와 무관하게 탭이 나온다 (기존 동작)', () {
      // 모집중 게이트를 진행중에 흘리면 리그가 시작된 뒤 구경하던 사람의
      // 화면에서 순위 탭이 사라진다.
      expect(
        leagueDetailTabs(
            status: 'in_progress',
            isTeamMode: false,
            isHost: false,
            myStatus: null),
        [LeagueDetailTab.participants, LeagueDetailTab.info],
      );
    });

    test('진행중 + 호스트는 심사 탭이 붙는다 (기존 동작)', () {
      expect(
        leagueDetailTabs(
            status: 'in_progress',
            isTeamMode: true,
            isHost: true,
            myStatus: 'approved'),
        [
          LeagueDetailTab.team,
          LeagueDetailTab.participants,
          LeagueDetailTab.review,
          LeagueDetailTab.info
        ],
      );
    });

    test('종료된 리그에는 호스트도 심사 탭이 없다 (기존 동작)', () {
      expect(
        leagueDetailTabs(
            status: 'completed',
            isTeamMode: false,
            isHost: true,
            myStatus: 'approved'),
        [LeagueDetailTab.participants, LeagueDetailTab.info],
      );
    });

    test('알 수 없는 상태는 탭을 만들지 않는다', () {
      expect(
        leagueDetailTabs(
            status: 'cancelled',
            isTeamMode: true,
            isHost: true,
            myStatus: 'approved'),
        isEmpty,
      );
    });
  });

  group('leagueDetailTabLabel — 상태에 따라 이름이 바뀐다', () {
    test('모집중에는 순위가 아니라 참가자·팀이다', () {
      // 조과가 0인 명단에 "실시간 순위" 라고 붙이면 1등이 없는 1등이 생긴다.
      expect(
          leagueDetailTabLabel(LeagueDetailTab.participants, 'recruiting'),
          '참가자');
      expect(leagueDetailTabLabel(LeagueDetailTab.team, 'recruiting'), '팀');
    });

    test('진행중은 실시간 순위, 종료는 최종 순위', () {
      expect(
          leagueDetailTabLabel(LeagueDetailTab.participants, 'in_progress'),
          '실시간 순위');
      expect(
          leagueDetailTabLabel(LeagueDetailTab.participants, 'completed'),
          '최종 순위');
      expect(
          leagueDetailTabLabel(LeagueDetailTab.team, 'in_progress'), '팀 순위');
    });

    test('심사·대회 정보는 상태와 무관하다', () {
      expect(leagueDetailTabLabel(LeagueDetailTab.review, 'in_progress'), '심사');
      expect(leagueDetailTabLabel(LeagueDetailTab.info, 'recruiting'), '대회 정보');
    });
  });
}
