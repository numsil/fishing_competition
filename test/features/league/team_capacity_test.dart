import 'package:flutter_test/flutter_test.dart';
import 'package:fishing_competition/features/league/data/team_capacity.dart';

void main() {
  group('isTeamFull / remainingSlots', () {
    test('정원 0 은 무제한이다', () {
      expect(isTeamFull(capacity: 0, memberCount: 999), isFalse);
      expect(remainingSlots(capacity: 0, memberCount: 999), -1);
    });

    test('정원에 도달하면 꽉 찬 것이다', () {
      expect(isTeamFull(capacity: 5, memberCount: 4), isFalse);
      expect(isTeamFull(capacity: 5, memberCount: 5), isTrue);
      expect(remainingSlots(capacity: 5, memberCount: 3), 2);
      expect(remainingSlots(capacity: 5, memberCount: 5), 0);
    });

    test('정원을 낮춰 초과한 팀은 남은 자리가 음수가 아니라 0 이다', () {
      // 호스트가 정원을 5 → 3 으로 낮춘 경우. "-3자리 남음" 이 떠선 안 된다.
      expect(remainingSlots(capacity: 3, memberCount: 6), 0);
      expect(isTeamFull(capacity: 3, memberCount: 6), isTrue);
      expect(isOverCapacity(capacity: 3, memberCount: 6), isTrue);
      expect(isOverCapacity(capacity: 3, memberCount: 3), isFalse);
      expect(isOverCapacity(capacity: 0, memberCount: 999), isFalse);
    });
  });

  group('capacityLabel', () {
    test('무제한이면 인원만 보여준다', () {
      expect(capacityLabel(capacity: 0, memberCount: 4), '4명');
    });

    test('정원이 있으면 사용/정원으로 보여준다', () {
      expect(capacityLabel(capacity: 5, memberCount: 3), '3 / 5');
      expect(capacityLabel(capacity: 5, memberCount: 6), '6 / 5');
    });
  });

  group('shuffleFitsCapacity', () {
    test('무제한이면 항상 통과', () {
      expect(shuffleFitsCapacity(approvedCount: 100, teamCount: 1, capacity: 0),
          isTrue);
    });

    test('총 자리수가 참가자보다 적으면 실패', () {
      // 15명, 3팀, 정원 3 → 9자리 < 15명
      expect(shuffleFitsCapacity(approvedCount: 15, teamCount: 3, capacity: 3),
          isFalse);
      expect(shuffleFitsCapacity(approvedCount: 15, teamCount: 3, capacity: 5),
          isTrue);
    });

    test('팀이 0개면 실패 (0자리)', () {
      expect(shuffleFitsCapacity(approvedCount: 1, teamCount: 0, capacity: 5),
          isFalse);
    });
  });

  group('assignmentsFitCapacity — SQL 의 "적용 후 상태" 규칙과 1:1', () {
    test('무제한이면 항상 통과', () {
      expect(
          assignmentsFitCapacity(
            before: {'a': null, 'b': null, 'c': null},
            incoming: {'a': 't1', 'b': 't1', 'c': 't1'},
            capacity: 0,
          ),
          isTrue);
    });

    test('개별로는 통과해도 합치면 정원을 넘으면 실패', () {
      // t1 에 이미 3명, 정원 5. 3명을 더 넣으면 6명.
      expect(
          assignmentsFitCapacity(
            before: {
              'x': 't1',
              'y': 't1',
              'z': 't1',
              'a': null,
              'b': null,
              'c': null
            },
            incoming: {'a': 't1', 'b': 't1', 'c': 't1'},
            capacity: 5,
          ),
          isFalse);
    });

    test('정원에 딱 맞으면 통과', () {
      expect(
          assignmentsFitCapacity(
            before: {'x': 't1', 'y': 't1', 'z': 't1', 'a': null, 'b': null},
            incoming: {'a': 't1', 'b': 't1'},
            capacity: 5,
          ),
          isTrue);
    });

    test('초과 팀에서 사람이 빠지는 배정은 허용된다', () {
      // 정원을 3으로 낮춰 t1 이 5명(초과). 1명을 빼면 4명 — 여전히 초과지만 줄었다.
      // 이걸 막으면 호스트가 초과 상태를 복구할 수 없다.
      expect(
          assignmentsFitCapacity(
            before: {'a': 't1', 'b': 't1', 'c': 't1', 'd': 't1', 'e': 't1'},
            incoming: {'a': null},
            capacity: 3,
          ),
          isTrue);
    });

    test('손대지 않은 초과 팀 형제가 있어도 다른 팀에서 빼는 배정은 허용된다', () {
      // prod 실측으로 잡은 버그다. 정원을 3으로 낮추면 t1/t2/t3 이 동시에 5명(초과)이
      // 된다. t1 에서 1명을 빼는 배정에서, 적용 전=적용 후(5명)인 t2/t3 가 `>=` 조건에
      // 걸려 TEAM_FULL 로 거부됐다. 규칙은 "이 배정이 그 팀을 더 나쁘게 만들었는가"다.
      expect(
          assignmentsFitCapacity(
            before: {
              'a1': 't1', 'a2': 't1', 'a3': 't1', 'a4': 't1', 'a5': 't1',
              'b1': 't2', 'b2': 't2', 'b3': 't2', 'b4': 't2', 'b5': 't2',
              'c1': 't3', 'c2': 't3', 'c3': 't3', 'c4': 't3', 'c5': 't3',
            },
            incoming: {'a1': null},
            capacity: 3,
          ),
          isTrue);
    });

    test('초과 팀에 더 넣는 배정은 거부된다', () {
      expect(
          assignmentsFitCapacity(
            before: {'a': 't1', 'b': 't1', 'c': 't1', 'd': 't1', 'z': null},
            incoming: {'z': 't1'},
            capacity: 3,
          ),
          isFalse);
    });

    test('초과 팀을 그대로 두는 배정(다른 팀 건드리기)은 통과', () {
      expect(
          assignmentsFitCapacity(
            before: {'a': 't1', 'b': 't1', 'c': 't1', 'd': 't1', 'z': null},
            incoming: {'z': 't2'},
            capacity: 3,
          ),
          isTrue);
    });

    test('미배정으로 보내는 것은 정원과 무관하게 통과', () {
      expect(
          assignmentsFitCapacity(
            before: {'a': 't1'},
            incoming: {'a': null},
            capacity: 1,
          ),
          isTrue);
    });

    test('incoming 에 없는 사람은 before 값을 유지한다', () {
      // t1 에 정원(2)만큼 있고, 건드리지 않는 배정은 통과해야 한다.
      expect(
          assignmentsFitCapacity(
            before: {'a': 't1', 'b': 't1', 'z': null},
            incoming: {'z': 't2'},
            capacity: 2,
          ),
          isTrue);
    });

    test('incoming 의 null 은 "미배정으로" 이고 키 없음과 구별된다', () {
      // 키가 있고 값이 null = 명시적 미배정 지시. 키가 없으면 before 유지.
      // 둘을 구별하지 못하면(예: COALESCE) 미배정 지시가 무시된다.
      expect(
          assignmentsFitCapacity(
            before: {'a': 't1', 'b': 't1'},
            incoming: {'a': null, 'b': null},
            capacity: 1,
          ),
          isTrue);
      expect(
          assignmentsFitCapacity(
            before: {'a': 't1', 'b': 't1'},
            incoming: const {},
            capacity: 1,
          ),
          isTrue); // 아무것도 안 바꾸므로 더 나빠지지 않음
    });
  });
}
