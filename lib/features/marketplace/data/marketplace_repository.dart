import 'dart:io';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/image_compress.dart';
import 'marketplace_model.dart';

part 'marketplace_repository.g.dart';

const int kMarketplacePageSize = 20;

class MarketplaceRepository {
  final SupabaseClient _supabase;
  MarketplaceRepository(this._supabase);

  Future<List<MarketplaceItem>> getItems({
    int limit = kMarketplacePageSize,
    DateTime? before,
    String? category,
  }) async {
    var query = _supabase
        .from('marketplace_items')
        .select('id, user_id, title, description, price, image_urls, category, status, location, created_at, users(username, user_key, avatar_url)')
        .eq('is_deleted', false);

    if (category != null) query = query.eq('category', category);
    if (before != null) query = query.lt('created_at', before.toUtc().toIso8601String());

    final response = await query
        .order('created_at', ascending: false)
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

    final response = await _supabase
        .from('marketplace_items')
        .select('id, user_id, title, description, price, image_urls, category, status, location, created_at, users(username, user_key, avatar_url)')
        .eq('user_id', uid)
        .eq('is_deleted', false)
        .order('created_at', ascending: false);

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
    }

    await _supabase.from('marketplace_items').insert({
      'user_id': uid,
      'title': title,
      'description': description,
      'price': price,
      'image_urls': urls,
      'category': category,
      'location': location,
    });
  }

  Future<void> updateStatus(String itemId, String status) async {
    await _supabase
        .from('marketplace_items')
        .update({'status': status})
        .eq('id', itemId);
  }

  Future<void> deleteItem(String itemId) async {
    await _supabase
        .from('marketplace_items')
        .update({'is_deleted': true})
        .eq('id', itemId);
  }
}

@riverpod
MarketplaceRepository marketplaceRepository(MarketplaceRepositoryRef ref) {
  return MarketplaceRepository(Supabase.instance.client);
}

@riverpod
Future<List<MarketplaceItem>> marketplaceItems(MarketplaceItemsRef ref) async {
  return ref.read(marketplaceRepositoryProvider).getItems();
}

@riverpod
Future<List<MarketplaceItem>> myMarketplaceItems(MyMarketplaceItemsRef ref) async {
  return ref.read(marketplaceRepositoryProvider).getMyItems();
}
