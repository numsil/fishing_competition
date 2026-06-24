import 'package:flutter_test/flutter_test.dart';
import 'package:fishing_competition/core/deep_link/deep_link_service.dart';

void main() {
  group('routeFromNotification', () {
    const uuid = '11111111-1111-1111-1111-111111111111';

    test('comment → /post/{id}', () {
      expect(routeFromNotification('comment', uuid), '/post/$uuid');
    });
    test('dm → /dm', () {
      expect(routeFromNotification('dm', uuid), '/dm');
    });
    test('follow → /user/{actor}', () {
      expect(routeFromNotification('follow', uuid, actorId: uuid), '/user/$uuid');
    });
    test('unknown → null', () {
      expect(routeFromNotification('bogus', uuid), isNull);
    });
  });
}
