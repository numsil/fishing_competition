import 'package:flutter_test/flutter_test.dart';
import 'package:fishing_competition/core/utils/entry_fee.dart';

void main() {
  group('formatEntryFee — 참가비 표기는 한 곳에서만 만든다', () {
    test('0원은 무료로 쓴다', () {
      expect(formatEntryFee(0), '무료');
    });

    test('천 단위 구분자를 넣고 원을 붙인다', () {
      expect(formatEntryFee(20000), '20,000원');
      expect(formatEntryFee(5000), '5,000원');
    });

    test('천 단위로 자르지 않는다', () {
      // 대회 관리 화면이 `fee ~/ 1000` 으로 찍어서 20,000원이 "20천원" 으로,
      // 15,500원이 "15천원" 으로, 500원이 "0천원" 으로 보였다.
      expect(formatEntryFee(15500), '15,500원');
      expect(formatEntryFee(500), '500원');
      expect(formatEntryFee(999), '999원');
    });

    test('무료 문구는 화면마다 다를 수 있다', () {
      // 리그 목록 카드는 "무료 참가" 로 쓴다. 이 차이 때문에 포맷을 따로
      // 들고 가면 "20천원" 같은 버그가 또 갈라져 나온다.
      expect(formatEntryFee(0, freeLabel: '무료 참가'), '무료 참가');
      expect(formatEntryFee(20000, freeLabel: '무료 참가'), '20,000원');
    });

    test('백만 단위도 구분자가 유지된다', () {
      expect(formatEntryFee(1000000), '1,000,000원');
    });

    test('음수는 들어올 수 없지만 들어와도 무료로 처리하지 않는다', () {
      // 0 과 구분되어야 잘못된 값이 "무료" 로 숨지 않는다.
      expect(formatEntryFee(-1), '-1원');
    });
  });
}
