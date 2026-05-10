/// YouTube URL → 11자리 video ID 추출.
/// 지원 형식:
///   - https://www.youtube.com/watch?v=ID
///   - https://youtu.be/ID
///   - https://www.youtube.com/shorts/ID
///   - https://www.youtube.com/embed/ID
///   - https://m.youtube.com/...
/// 추가 쿼리 파라미터(t=, si=, list= 등)는 모두 무시.
String? extractYoutubeId(String input) {
  final raw = input.trim();
  if (raw.isEmpty) return null;

  Uri? uri;
  try {
    uri = Uri.parse(raw.contains('://') ? raw : 'https://$raw');
  } catch (_) {
    return null;
  }

  final host = uri.host.toLowerCase();
  if (host.isEmpty) return null;

  final isYoutubeHost = host == 'youtu.be' ||
      host == 'youtube.com' ||
      host.endsWith('.youtube.com');
  if (!isYoutubeHost) return null;

  String? id;

  if (host == 'youtu.be') {
    if (uri.pathSegments.isNotEmpty) id = uri.pathSegments.first;
  } else {
    // /watch?v=ID
    if (uri.pathSegments.contains('watch')) {
      id = uri.queryParameters['v'];
    }
    // /shorts/ID, /embed/ID, /v/ID
    for (final marker in ['shorts', 'embed', 'v']) {
      final i = uri.pathSegments.indexOf(marker);
      if (i >= 0 && i + 1 < uri.pathSegments.length) {
        id = uri.pathSegments[i + 1];
        break;
      }
    }
  }

  if (id == null) return null;
  // 흔히 11자리. 너무 짧거나 너무 길면 거부.
  if (id.length < 8 || id.length > 16) return null;
  if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(id)) return null;
  return id;
}

String youtubeThumbnailUrl(String videoId) =>
    'https://img.youtube.com/vi/$videoId/hqdefault.jpg';

/// URL 이 YouTube Shorts (`/shorts/{id}`) 형식인지.
/// 쇼츠는 9:16 세로 비율로 렌더해야 잘리지 않는다.
bool isYoutubeShortsUrl(String url) {
  try {
    final uri = Uri.parse(url.contains('://') ? url : 'https://$url');
    return uri.pathSegments.contains('shorts');
  } catch (_) {
    return false;
  }
}
