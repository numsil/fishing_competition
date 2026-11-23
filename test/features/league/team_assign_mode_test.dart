import 'package:flutter_test/flutter_test.dart';
import 'package:fishing_competition/features/league/data/league_model.dart';
import 'package:fishing_competition/features/league/data/league_team_model.dart';

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
}
