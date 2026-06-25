import 'package:flutter_test/flutter_test.dart';
import 'package:fishing_competition/features/notifications/data/notification_model.dart';

void main() {
  test('AppNotification.fromJson parses joined actor', () {
    final json = {
      'id': 'n1',
      'type': 'comment',
      'actor_id': 'a1',
      'target_id': 'p1',
      'body': '좋은 사진이네요',
      'is_read': false,
      'created_at': '2026-06-24T00:00:00Z',
      'actor': {'username': 'angler', 'avatar_url': null},
    };
    final n = AppNotification.fromJson(json);
    expect(n.id, 'n1');
    expect(n.type, 'comment');
    expect(n.actorUsername, 'angler');
    expect(n.targetId, 'p1');
    expect(n.isRead, false);
  });
}
