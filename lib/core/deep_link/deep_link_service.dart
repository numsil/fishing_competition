import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

/// nakstar:// 커스텀 스킴 + https://nakstar.app 유니버설 링크를 수신해서
/// go_router 경로로 변환·이동시킨다.
///
/// 지원 경로 (id = UUID):
///   - https://nakstar.app/league/{id}     → /league/detail/{id}
///   - nakstar://league/{id}               → /league/detail/{id}
///   - https://nakstar.app/post/{id}       → /post/{id}
///   - nakstar://post/{id}                 → /post/{id}
///   - https://nakstar.app/user/{id}       → /user/{id}
class DeepLinkService {
  DeepLinkService(this._router);

  final GoRouter _router;
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  bool _initialHandled = false;

  Future<void> start() async {
    // 콜드 스타트: 앱이 링크로 시작된 경우 1회 처리
    if (!_initialHandled) {
      _initialHandled = true;
      try {
        final initial = await _appLinks.getInitialLink();
        if (initial != null) _handle(initial);
      } catch (e) {
        if (kDebugMode) debugPrint('[DeepLink] initial link error: $e');
      }
    }

    // 웜 스타트: 앱이 백그라운드일 때 들어온 링크
    _sub ??= _appLinks.uriLinkStream.listen(
      _handle,
      onError: (Object e) {
        if (kDebugMode) debugPrint('[DeepLink] stream error: $e');
      },
    );
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }

  void _handle(Uri uri) {
    final path = _mapToRoute(uri);
    if (kDebugMode) debugPrint('[DeepLink] $uri → $path');
    if (path == null) return;
    _router.go(path);
  }

  /// 외부 URI → 앱 내부 경로 매핑.
  /// 매핑 실패 시 null 반환 (무시).
  String? _mapToRoute(Uri uri) {
    // host 또는 path 첫 segment를 카테고리로 사용
    // nakstar://league/<id> → host='league', path='/<id>'
    // https://nakstar.app/league/<id> → host='nakstar.app', path='/league/<id>'
    final segments = <String>[];
    if (uri.scheme == 'nakstar') {
      if (uri.host.isNotEmpty) segments.add(uri.host);
      segments.addAll(uri.pathSegments.where((s) => s.isNotEmpty));
    } else if (uri.scheme == 'https' && uri.host == 'nakstar.app') {
      segments.addAll(uri.pathSegments.where((s) => s.isNotEmpty));
    } else {
      return null;
    }

    if (segments.isEmpty) return null;

    switch (segments.first) {
      case 'league':
        // /league/<id> 또는 /league/detail/<id> (구 포맷 호환)
        if (segments.length >= 2) {
          final id = segments.last;
          if (_isUuid(id)) return '/league/detail/$id';
        }
        return null;
      case 'post':
      case 'p': // 구 포맷 호환 (nakstar.app/p/<id>)
        if (segments.length >= 2) {
          final id = segments[1];
          if (_isUuid(id)) return '/post/$id';
        }
        return null;
      case 'user':
        if (segments.length >= 2) {
          final id = segments[1];
          if (_isUuid(id)) return '/user/$id';
        }
        return null;
      default:
        return null;
    }
  }

  static final _uuidRe =
      RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
  static bool _isUuid(String s) => _uuidRe.hasMatch(s);
}
