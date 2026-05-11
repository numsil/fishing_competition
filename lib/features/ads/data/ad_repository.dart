import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'ad_model.dart';

part 'ad_repository.g.dart';

class AdRepository {
  AdRepository(this._supabase);
  final SupabaseClient _supabase;

  /// 활성 광고 목록 (RLS가 자동으로 활성·기간·한도 필터링).
  Future<List<AdFeed>> getActiveAds() async {
    final rows = await _supabase
        .from('ad_feeds')
        .select(
          'id, title, body, image_url, image_urls, video_url, thumbnail_url, '
          'aspect_ratio, link_url, sort_order, created_at',
        )
        .eq('placement', 'feed')
        .order('sort_order', ascending: true)
        .order('created_at', ascending: false)
        .limit(20);
    return rows.map((e) => AdFeed.fromJson(e)).toList();
  }

  Future<void> recordView(String adId) async {
    try {
      await _supabase.rpc(
        'record_ad_impression',
        params: {'p_ad_id': adId, 'p_event_type': 'view'},
      );
    } catch (_) {
      // 무시 (네트워크 오류는 광고 UX에 영향 X)
    }
  }

  Future<void> recordClick(String adId) async {
    try {
      await _supabase.rpc(
        'record_ad_impression',
        params: {'p_ad_id': adId, 'p_event_type': 'click'},
      );
    } catch (_) {}
  }
}

@riverpod
AdRepository adRepository(AdRepositoryRef ref) {
  return AdRepository(Supabase.instance.client);
}

/// 피드 광고 풀. 10분 keepAlive (위젯에서 자체 셔플/회전).
@riverpod
Future<List<AdFeed>> activeFeedAds(ActiveFeedAdsRef ref) async {
  final link = ref.keepAlive();
  Timer(const Duration(minutes: 10), link.close);
  return ref.read(adRepositoryProvider).getActiveAds();
}
