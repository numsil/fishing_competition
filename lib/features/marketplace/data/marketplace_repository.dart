import 'dart:async';
import 'dart:io';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/image_compress.dart';
import '../../../core/utils/storage_cleanup.dart';
import 'marketplace_model.dart';

part 'marketplace_repository.g.dart';

const int kMarketplacePageSize = 20;

/// updateItem에 넘기는 이미지 입력. 수정 화면에서는 이미 업로드된 기존 URL과
/// 새로 고른 로컬 파일이 섞이므로, 순서를 유지한 채 두 종류를 함께 표현한다.
sealed class MarketplaceImageInput {
  const MarketplaceImageInput();
}

/// 이미 업로드되어 image_urls에 들어있는 기존 이미지
class ExistingImageUrl extends MarketplaceImageInput {
  final String url;
  const ExistingImageUrl(this.url);
}

/// 새로 추가된 로컬 파일 (업로드 필요)
class NewImageFile extends MarketplaceImageInput {
  final File file;
  const NewImageFile(this.file);
}

class MarketplaceRepository {
  final SupabaseClient _supabase;
  MarketplaceRepository(this._supabase);

  Future<List<MarketplaceItem>> getItems({
    int limit = kMarketplacePageSize,
    DateTime? before,
    String? beforeId,
    String? category,
    String? search,
    String? tradeType,
  }) async {
    var query = _supabase
        .from('marketplace_items')
        .select('id, user_id, title, description, price, image_urls, category, status, trade_type, location, created_at, bumped_at, users(username, avatar_url)')
        .eq('is_deleted', false);

    if (tradeType != null) query = query.eq('trade_type', tradeType);
    if (category != null) query = query.eq('category', category);
    if (search != null && search.trim().isNotEmpty) {
      // PostgREST or 필터가 깨지는 특수문자 제거 후 제목·설명 부분일치 검색
      final s = search.trim().replaceAll(RegExp(r'[,()*%]'), ' ').trim();
      if (s.isNotEmpty) {
        query = query.or('title.ilike.*$s*,description.ilike.*$s*');
      }
    }
    if (before != null) {
      final c = before.toUtc().toIso8601String();
      // keyset (bumped_at, id) 복합 커서: 끌어올리기 반영 정렬, 경계 누락 없음
      if (beforeId != null) {
        query = query.or('bumped_at.lt.$c,and(bumped_at.eq.$c,id.lt.$beforeId)');
      } else {
        query = query.lt('bumped_at', c);
      }
    }

    final response = await query
        .order('bumped_at', ascending: false)
        .order('id', ascending: false)
        .limit(limit);

    return (response as List).map((data) {
      final item = MarketplaceItem.fromJson(data as Map<String, dynamic>);
      final u = data['users'];
      return item.copyWith(
        username: (u is Map ? u['username'] : null) ?? 'Unknown',
        userKey: (u is Map ? u['user_key'] : null) ?? '',
        avatarUrl: (u is Map ? u['avatar_url'] : null) ?? '',
      );
    }).toList();
  }

  Future<List<MarketplaceItem>> getMyItems() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return [];
    return getUserItems(uid);
  }

  /// 특정 유저가 등록한 중고거래 목록 (프로필에서 사용)
  Future<List<MarketplaceItem>> getUserItems(String userId) async {
    final response = await _supabase
        .from('marketplace_items')
        .select('id, user_id, title, description, price, image_urls, category, status, trade_type, location, created_at, bumped_at, users(username, avatar_url)')
        .eq('user_id', userId)
        .eq('is_deleted', false)
        .order('created_at', ascending: false)
        .limit(100);

    return (response as List).map((data) {
      final item = MarketplaceItem.fromJson(data as Map<String, dynamic>);
      final u = data['users'];
      return item.copyWith(
        username: (u is Map ? u['username'] : null) ?? 'Unknown',
        userKey: (u is Map ? u['user_key'] : null) ?? '',
        avatarUrl: (u is Map ? u['avatar_url'] : null) ?? '',
      );
    }).toList();
  }

  Future<void> createItem({
    required String title,
    String? description,
    required int price,
    required List<File> imageFiles,
    required String category,
    String? location,
    String tradeType = 'sell',
  }) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) throw Exception('Not logged in');

    final ts = DateTime.now().millisecondsSinceEpoch;
    final urls = <String>[];
    for (int i = 0; i < imageFiles.length; i++) {
      final compressed = await compressForUpload(imageFiles[i]);
      final path = 'marketplace/${uid}_${ts}_$i.jpg';
      await _supabase.storage.from('post_images').upload(
        path,
        compressed,
        fileOptions: const FileOptions(contentType: 'image/jpeg', cacheControl: '31536000'),
      );
      urls.add(_supabase.storage.from('post_images').getPublicUrl(path));
      // 업로드 후 로컬 압축본 정리 (디스크 누수 방지)
      try {
        await compressed.delete();
      } catch (_) {}
    }

    await _supabase.from('marketplace_items').insert({
      'user_id': uid,
      'title': title,
      'description': description,
      'price': price,
      'image_urls': urls,
      'category': category,
      'trade_type': tradeType,
      'location': location,
    });
  }

  Future<void> updateStatus(String itemId, String status) async {
    await _supabase
        .from('marketplace_items')
        .update({'status': status})
        .eq('id', itemId);
  }

  /// 매물 수정. 이미지는 [images] 순서(첫 항목 = 대표)를 그대로 유지하며,
  /// 새 파일은 압축·업로드하고 기존 URL은 그대로 재사용한다.
  /// [originalUrls]와 비교해 이번 수정에서 빠진 기존 이미지는 스토리지에서 정리한다.
  Future<void> updateItem({
    required String itemId,
    required String title,
    String? description,
    required int price,
    required List<MarketplaceImageInput> images,
    required List<String> originalUrls,
    required String category,
    String? location,
    String tradeType = 'sell',
  }) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) throw Exception('Not logged in');

    // 순서를 유지한 채 최종 image_urls 재구성 (새 파일만 업로드)
    final ts = DateTime.now().millisecondsSinceEpoch;
    final finalUrls = <String>[];
    int newIdx = 0;
    for (final img in images) {
      switch (img) {
        case ExistingImageUrl(:final url):
          finalUrls.add(url);
        case NewImageFile(:final file):
          final compressed = await compressForUpload(file);
          final path = 'marketplace/${uid}_${ts}_$newIdx.jpg';
          await _supabase.storage.from('post_images').upload(
            path,
            compressed,
            fileOptions: const FileOptions(contentType: 'image/jpeg', cacheControl: '31536000'),
          );
          finalUrls.add(_supabase.storage.from('post_images').getPublicUrl(path));
          // 업로드 후 로컬 압축본 정리 (디스크 누수 방지)
          try {
            await compressed.delete();
          } catch (_) {}
          newIdx++;
      }
    }

    // 행 수정 (RLS: 본인 행만 update 가능)
    await _supabase.from('marketplace_items').update({
      'title': title,
      'description': description,
      'price': price,
      'image_urls': finalUrls,
      'category': category,
      'trade_type': tradeType,
      'location': location,
    }).eq('id', itemId);

    // 이번 수정에서 제거된 기존 이미지 스토리지 best-effort 정리
    final kept = finalUrls.toSet();
    final removed = originalUrls.where((u) => !kept.contains(u));
    final paths = <String>{};
    for (final u in removed) {
      final p = extractStoragePath(u, 'post_images');
      if (p != null) paths.add(p);
    }
    if (paths.isNotEmpty) {
      try {
        await _supabase.storage.from('post_images').remove(paths.toList());
      } catch (_) {/* swallow */}
    }
  }

  /// 끌어올리기: bumped_at을 현재 시각으로 갱신 → 목록 최상단으로.
  Future<void> bumpItem(String itemId) async {
    await _supabase
        .from('marketplace_items')
        .update({'bumped_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', itemId);
  }

  Future<void> deleteItem(String itemId) async {
    // 스토리지 이미지 정리를 위해 먼저 이미지 URL 조회 (필요 컬럼만)
    final row = await _supabase
        .from('marketplace_items')
        .select('image_urls')
        .eq('id', itemId)
        .maybeSingle();

    // 행 하드 삭제 (RLS: 본인 행만 delete 가능)
    await _supabase.from('marketplace_items').delete().eq('id', itemId);

    // 스토리지 이미지 best-effort 정리 (마켓 이미지는 post_images 버킷)
    final urls = (row?['image_urls'] as List?)?.cast<String>();
    if (urls != null && urls.isNotEmpty) {
      final paths = <String>{};
      for (final u in urls) {
        final p = extractStoragePath(u, 'post_images');
        if (p != null) paths.add(p);
      }
      if (paths.isNotEmpty) {
        try {
          await _supabase.storage.from('post_images').remove(paths.toList());
        } catch (_) {/* swallow */}
      }
    }
  }
}

@riverpod
MarketplaceRepository marketplaceRepository(MarketplaceRepositoryRef ref) {
  return MarketplaceRepository(Supabase.instance.client);
}

// 중고거래 목록: 서버 검색·카테고리 필터 + 커서 페이지네이션
@riverpod
class MarketplaceList extends _$MarketplaceList {
  bool _hasMore = true;
  bool _loading = false;
  DateTime? _lastCreatedAt;
  String? _lastId;
  String _category = '전체';
  String _search = '';
  String _tradeType = 'all'; // all | sell | buy

  bool get hasMore => _hasMore;

  @override
  Future<List<MarketplaceItem>> build() async {
    // 리스트 5분 TTL 캐시 (피드 패턴과 동일)
    final link = ref.keepAlive();
    Timer(const Duration(minutes: 5), link.close);
    return _fetch(reset: true);
  }

  Future<List<MarketplaceItem>> _fetch({required bool reset}) async {
    final items = await ref.read(marketplaceRepositoryProvider).getItems(
          limit: kMarketplacePageSize,
          before: reset ? null : _lastCreatedAt,
          beforeId: reset ? null : _lastId,
          category: _category == '전체' ? null : _category,
          search: _search.trim().isEmpty ? null : _search.trim(),
          tradeType: _tradeType == 'all' ? null : _tradeType,
        );
    _hasMore = items.length >= kMarketplacePageSize;
    if (items.isNotEmpty) {
      // 정렬 기준(bumped_at) 커서. 값이 없으면 createdAt로 대체.
      _lastCreatedAt = items.last.bumpedAt ?? items.last.createdAt;
      _lastId = items.last.id;
    }
    return items;
  }

  // 카테고리/검색어/거래유형 변경 시 처음부터 다시 조회
  Future<void> setFilter({
    required String category,
    required String search,
    String tradeType = 'all',
  }) async {
    if (category == _category && search == _search && tradeType == _tradeType) {
      return;
    }
    _category = category;
    _search = search;
    _tradeType = tradeType;
    _hasMore = true;
    _lastCreatedAt = null;
    _lastId = null;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch(reset: true));
  }

  Future<void> loadMore() async {
    if (_loading || !_hasMore) return;
    final current = state.valueOrNull;
    if (current == null) return;
    _loading = true;
    try {
      final more = await _fetch(reset: false);
      state = AsyncData([...current, ...more]);
    } finally {
      _loading = false;
    }
  }

  Future<void> refresh() async {
    _hasMore = true;
    _lastCreatedAt = null;
    _lastId = null;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch(reset: true));
  }
}

@riverpod
Future<List<MarketplaceItem>> myMarketplaceItems(MyMarketplaceItemsRef ref) async {
  // 내 매물 목록도 5분 TTL 캐시
  final link = ref.keepAlive();
  Timer(const Duration(minutes: 5), link.close);
  return ref.read(marketplaceRepositoryProvider).getMyItems();
}

// 특정 유저의 매물 목록 (프로필). 5분 TTL 캐시.
@riverpod
Future<List<MarketplaceItem>> userMarketplaceItems(
    UserMarketplaceItemsRef ref, String userId) async {
  final link = ref.keepAlive();
  Timer(const Duration(minutes: 5), link.close);
  return ref.read(marketplaceRepositoryProvider).getUserItems(userId);
}
