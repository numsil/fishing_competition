import 'package:flutter_test/flutter_test.dart';
import 'package:fishing_competition/features/league/data/catch_limit_options.dart';

void main() {
  group('showSingleCatchChip — 중복 규칙은 고를 수 없게 한다', () {
    test('합산 길이에서는 1마리 칩을 숨긴다', () {
      // `합산 길이 + 1마리` 는 `최대어` 와 완전히 같은 규칙이다.
      // 같은 결과를 내는 선택지가 둘이면 호스트가 둘을 다르다고 믿는다.
      expect(showSingleCatchChip(rule: '합산 길이', storedLimit: null), isFalse);
      expect(showSingleCatchChip(rule: '합산 길이', storedLimit: 3), isFalse);
    });

    test('무게는 1마리를 남겨둔다', () {
      // `최대무게` 칩이 없어서 `무게 + 1마리` 가 최대무게로 가는 유일한 길이다.
      expect(showSingleCatchChip(rule: '무게', storedLimit: null), isTrue);
    });

    test('이미 그 조합으로 저장된 리그는 칩을 그대로 보여준다', () {
      // 숨기면 수정 화면을 열고 저장만 눌러도 규칙이 조용히 바뀐다.
      expect(showSingleCatchChip(rule: '합산 길이', storedLimit: 1), isTrue);
    });
  });

  group('minCatchLimit — 직접 입력으로 중복 규칙에 들어가는 뒷문을 막는다', () {
    test('합산 길이는 2마리부터', () {
      // 칩만 숨기면 `직접 입력` 에 1 을 쳐서 같은 조합으로 들어갈 수 있다.
      expect(minCatchLimit(rule: '합산 길이'), 2);
    });

    test('나머지 룰은 1마리부터', () {
      expect(minCatchLimit(rule: '무게'), 1);
      expect(minCatchLimit(rule: '최대어'), 1);
      expect(minCatchLimit(rule: '마릿수'), 1);
    });
  });

  group('catchLimitAfterRuleChange — 룰을 바꿨을 때의 마릿수', () {
    test('마릿수는 제한이 의미 없으므로 전체(0)', () {
      expect(catchLimitAfterRuleChange(rule: '마릿수', current: 5), 0);
    });

    test('최대어는 항상 1마리', () {
      expect(catchLimitAfterRuleChange(rule: '최대어', current: 5), 1);
    });

    test('합산 길이로 오면 1마리·전체를 3마리로 올린다', () {
      // 1마리는 최대어와 중복이고, 전체(0)는 마릿수에서 넘어온 값이다.
      expect(catchLimitAfterRuleChange(rule: '합산 길이', current: 1), 3);
      expect(catchLimitAfterRuleChange(rule: '합산 길이', current: 0), 3);
    });

    test('합산 길이에서 이미 고른 2마리 이상은 건드리지 않는다', () {
      expect(catchLimitAfterRuleChange(rule: '합산 길이', current: 5), 5);
      expect(catchLimitAfterRuleChange(rule: '합산 길이', current: 2), 2);
    });

    test('무게는 전체(0)만 1마리로 되돌린다', () {
      expect(catchLimitAfterRuleChange(rule: '무게', current: 0), 1);
      expect(catchLimitAfterRuleChange(rule: '무게', current: 1), 1);
      expect(catchLimitAfterRuleChange(rule: '무게', current: 5), 5);
    });
  });
}
