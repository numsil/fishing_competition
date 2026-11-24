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

    // 리그 알림 3종은 모두 리그 상세로 간다. target_id = league_id.
    test('league_invite → /league/detail/{id}', () {
      expect(routeFromNotification('league_invite', uuid),
          '/league/detail/$uuid');
    });
    test('league_start → /league/detail/{id}', () {
      expect(routeFromNotification('league_start', uuid),
          '/league/detail/$uuid');
    });
    test('league_approved → /league/detail/{id}', () {
      expect(routeFromNotification('league_approved', uuid),
          '/league/detail/$uuid');
    });

    // target_id 가 없으면 보낼 곳이 없다. 라우팅하지 않는다 (알림함에 남는다).
    test('리그 알림에 target_id 가 없으면 null', () {
      expect(routeFromNotification('league_invite', null), isNull);
      expect(routeFromNotification('league_start', null), isNull);
      expect(routeFromNotification('league_approved', null), isNull);
    });
  });
}
