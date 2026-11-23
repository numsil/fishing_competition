import 'package:flutter_test/flutter_test.dart';
import 'package:fishing_competition/features/league/data/league_model.dart';
import 'package:fishing_competition/features/league/data/league_team_model.dart';
import 'package:fishing_competition/features/league/presentation/screens/league_team_manage_screen.dart';
import 'package:fishing_competition/features/league/presentation/widgets/league_my_team_banner.dart';

Map<String, dynamic> leagueJson(Map<String, dynamic> extra) => {
      'id': 'L',
      'host_id': 'H',
      'title': '테스트',
      'location': '백곡지',
      'start_time': '2026-11-23T00:00:00Z',
      'end_time': '2026-11-30T00:00:00Z',
      'created_at': '2026-11-22T00:00:00Z',
      ...extra,
    };

void main() {
  group('League 팀 배정 필드', () {
    test('컬럼이 없으면 host / 0 으로 떨어진다 (기존 리그 보호)', () {
      final l = League.fromJson(leagueJson({}));
      expect(l.teamAssignMode, 'host');
      expect(l.teamCapacity, 0);
      expect(l.isTeamMode, isFalse);
      expect(l.isSelfPick, isFalse);
    });

    test('team_assign_mode / team_capacity 를 읽는다', () {
      final l = League.fromJson(leagueJson({
        'is_team_mode': true,
        'team_assign_mode': 'self',
        'team_capacity': 5,
      }));
      expect(l.teamAssignMode, 'self');
      expect(l.teamCapacity, 5);
      expect(l.isSelfPick, isTrue);
    });

    test('팀전이 아니면 self 여도 isSelfPick 은 false', () {
      // 팀전을 끈 뒤 되돌릴 수 있게 team_assign_mode 는 보존된다.
      // 그 값만 보고 배너를 그리면 개인전 리그에 배너가 뜬다.
      final l = League.fromJson(leagueJson({
        'is_team_mode': false,
        'team_assign_mode': 'self',
      }));
      expect(l.isSelfPick, isFalse);
    });
  });

  group('TeamAssignment', () {
    test('미배정은 team_id null 로 직렬화된다', () {
      expect(const TeamAssignment(userId: 'u1').toJson(),
          {'user_id': 'u1', 'team_id': null});
    });

    test('RPC 가 돌려준 스냅샷을 역직렬화한다', () {
      final rows = [
        {'user_id': 'u1', 'team_id': 't1'},
        {'user_id': 'u2', 'team_id': null},
      ];
      final parsed =
          rows.map((r) => TeamAssignment.fromJson(r)).toList(growable: false);
      expect(parsed[0].teamId, 't1');
      expect(parsed[1].teamId, isNull);
    });

    test('왕복(toJson → fromJson)에서 값이 유지된다', () {
      const a = TeamAssignment(userId: 'u1', teamId: 't9');
      final b = TeamAssignment.fromJson(a.toJson());
      expect(b.userId, 'u1');
      expect(b.teamId, 't9');
    });
  });

  group('shouldDropSnapshot — 되돌리기 실패 처리', () {
    test('팀이 삭제됐으면 스냅샷을 폐기한다', () {
      // 스냅샷이 가리키는 팀이 사라졌으면 그 스냅샷은 영구히 실패한다.
      // 폐기하지 않으면 '되돌리기' 버튼이 남아 계속 같은 에러를 띄운다.
      expect(
          shouldDropSnapshot(
              Exception('PostgrestException(message: TEAM_NOT_IN_LEAGUE)')),
          isTrue);
    });

    test('참가자가 탈퇴했으면 스냅샷을 폐기한다', () {
      expect(
          shouldDropSnapshot(
              Exception('PostgrestException(message: NOT_PARTICIPANT)')),
          isTrue);
    });

    test('일시적 실패는 스냅샷을 유지해 재시도할 수 있게 한다', () {
      expect(shouldDropSnapshot(Exception('SocketException: failed')), isFalse);
      expect(
          shouldDropSnapshot(
              Exception('PostgrestException(message: TEAM_FULL)')),
          isFalse);
    });
  });

  group('shouldShowMyTeamBanner — 승인 대기도 배너를 본다', () {
    test('승인 대기 참가자에게도 보인다', () {
      // 모집중에 신청만 해둔 사람에게 아무 안내도 없으면, 리그가 시작된 뒤에야
      // 팀을 고를 수 있다는 사실을 알게 된다.
      expect(
          shouldShowMyTeamBanner(
              isSelfPick: true,
              isApprovedParticipant: false,
              isPendingParticipant: true),
          isTrue);
    });

    test('호스트 배정 리그면 대기 중이어도 안 보인다', () {
      expect(
          shouldShowMyTeamBanner(
              isSelfPick: false,
              isApprovedParticipant: false,
              isPendingParticipant: true),
          isFalse);
    });

    test('신청하지 않은 사람에게는 안 보인다', () {
      expect(
          shouldShowMyTeamBanner(
              isSelfPick: true,
              isApprovedParticipant: false,
              isPendingParticipant: false),
          isFalse);
    });
  });

  group('shouldShowMyTeamBanner — 배너 노출 규칙', () {
    test('자율 선택 + 승인 참가자일 때만 보인다', () {
      expect(
          shouldShowMyTeamBanner(isSelfPick: true, isApprovedParticipant: true),
          isTrue);
    });

    test('호스트 배정 리그에는 아예 그리지 않는다', () {
      // 누를 수 없는 버튼을 보여주는 셈이다.
      // set_my_league_team 도 SELF_PICK_DISABLED 를 던진다.
      expect(
          shouldShowMyTeamBanner(
              isSelfPick: false, isApprovedParticipant: true),
          isFalse);
    });

    test('참가자가 아니면(관전·미승인) 그리지 않는다', () {
      expect(
          shouldShowMyTeamBanner(
              isSelfPick: true, isApprovedParticipant: false),
          isFalse);
      expect(
          shouldShowMyTeamBanner(
              isSelfPick: false, isApprovedParticipant: false),
          isFalse);
    });
  });
}
