import 'package:fishing_competition/features/feed/data/post_model.dart';
import 'package:fishing_competition/features/feed/presentation/utils/feed_search_utils.dart';
import 'package:flutter_test/flutter_test.dart';

Post _post({required String username, String? caption}) => Post(
      id: 'id',
      userId: 'uid',
      imageUrl: '',
      createdAt: DateTime.now(),
      username: username,
      caption: caption,
    );

void main() {
  group('extractHashtags', () {
    test('캡션에서 해시태그 추출', () {
      expect(extractHashtags('#배스 #루어낚시 좋은 날씨'), ['#배스', '#루어낚시']);
    });
    test('해시태그 없으면 빈 리스트', () {
      expect(extractHashtags('태그 없음'), []);
    });
    test('null 캡션이면 빈 리스트', () {
      expect(extractHashtags(null), []);
    });
    test('빈 문자열이면 빈 리스트', () {
      expect(extractHashtags(''), []);
    });
  });

  group('filterPosts', () {
    final posts = [
      _post(username: '김민준', caption: '#배스 #루어낚시'),
      _post(username: '이서연', caption: '#잉어'),
      _post(username: '배스왕', caption: '맑은 날'),
    ];

    test('빈 쿼리는 전체 반환', () {
      expect(filterPosts(posts, '').length, 3);
    });

    test('공백만 있는 쿼리는 전체 반환', () {
      expect(filterPosts(posts, '   ').length, 3);
    });

    test('유저명 부분 일치 필터링', () {
      final r = filterPosts(posts, '민준');
      expect(r.length, 1);
      expect(r.first.username, '김민준');
    });

    test('# 포함 태그로 필터링', () {
      expect(filterPosts(posts, '#배스').length, 1);
    });

    test('# 없이 태그로 필터링 — 태그 + 유저명 모두 매칭', () {
      // 김민준(#배스 태그) + 배스왕(유저명) 둘 다 매칭
      expect(filterPosts(posts, '배스').length, 2);
    });

    test('대소문자 무시', () {
      expect(filterPosts(posts, '서연').length, 1);
    });

    test('일치하는 결과 없으면 빈 리스트', () {
      expect(filterPosts(posts, '고등어').length, 0);
    });
  });
}
