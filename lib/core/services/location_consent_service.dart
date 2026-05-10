import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../extensions/theme_extensions.dart';

/// 위치정보법 §15 — 위치정보 수집 별도 동의.
/// 시스템 권한 다이얼로그와 별개로, 앱이 정확 좌표를 서버에 저장하기 전에
/// 1회 이상 명시적 동의를 받아야 한다.
class LocationConsentService {
  LocationConsentService._();

  static bool? _cached;

  /// 동의했는지 여부. DB의 users.location_agreed_at 으로 판정.
  static Future<bool> hasAgreed() async {
    if (_cached != null) return _cached!;
    final supabase = Supabase.instance.client;
    final me = supabase.auth.currentUser?.id;
    if (me == null) return false;
    final row = await supabase
        .from('users')
        .select('location_agreed_at')
        .eq('id', me)
        .maybeSingle();
    final agreed = row?['location_agreed_at'] != null;
    _cached = agreed;
    return agreed;
  }

  /// 미동의 시 다이얼로그를 띄우고 동의 받으면 DB에 시점 기록.
  /// 반환값: 최종 동의 여부 (이미 동의했으면 true).
  static Future<bool> ensureAgreed(BuildContext context) async {
    if (await hasAgreed()) return true;
    if (!context.mounted) return false;
    final ok = await _showConsentDialog(context);
    if (!ok) return false;

    final supabase = Supabase.instance.client;
    final me = supabase.auth.currentUser?.id;
    if (me == null) return false;
    await supabase.from('users').update({
      'location_agreed_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', me);
    _cached = true;
    return true;
  }

  /// 로그아웃 등 캐시 초기화 시 호출.
  static void resetCache() {
    _cached = null;
  }

  static Future<bool> _showConsentDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('위치정보 이용 동의'),
            content: SingleChildScrollView(
              child: Text(
                '''조과 기록 시 정확한 위치를 함께 저장합니다.

• 수집 항목: GPS 좌표(위도/경도), 주소
• 이용 목적: 조과 위치 표시, 게시물에 위치 정보 표시
• 보유 기간: 게시물 삭제 또는 회원 탈퇴 시까지
• 거부 시: 위치 없이 수동으로 장소를 입력할 수 있습니다

위치정보를 수집·이용하는 데 동의하십니까?''',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: context.isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('동의하지 않음'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('동의'),
              ),
            ],
          ),
        ) ??
        false;
  }
}
