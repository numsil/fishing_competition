import 'dart:io';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'post_model.dart';

part 'feed_repository.g.dart';

class FeedRepository {
  final SupabaseClient _supabase;

  FeedRepository(this._supabase);

  Future<List<Post>> getPosts() async {
    final response = await _supabase
        .from('posts')
        .select('*, users(username, avatar_url), post_likes(count), post_comments(count)')
        .isFilter('league_id', null)
        .order('created_at', ascending: false);

    return response.map((data) {
      final post = Post.fromJson(data);
      final usersData = data['users'];
      final String username = (usersData != null && usersData is Map) ? usersData['username'] ?? 'Unknown' : 'Unknown';
      final String avatarUrl = (usersData != null && usersData is Map) ? usersData['avatar_url'] ?? '' : '';

      final likesData = data['post_likes'];
      final int likes = (likesData is List && likesData.isNotEmpty) ? likesData[0]['count'] ?? 0 : 0;

      final commentsData = data['post_comments'];
      final int comments = (commentsData is List && commentsData.isNotEmpty) ? commentsData[0]['count'] ?? 0 : 0;

      return post.copyWith(
        username: username,
        avatarUrl: avatarUrl,
        likesCount: likes,
        commentsCount: comments,
      );
    }).toList();
  }

  Future<void> toggleLike(String postId, String userId) async {
    final existingLike = await _supabase
        .from('post_likes')
        .select()
        .eq('post_id', postId)
        .eq('user_id', userId)
        .maybeSingle();

    if (existingLike != null) {
      await _supabase.from('post_likes').delete().eq('id', existingLike['id']);
    } else {
      await _supabase.from('post_likes').insert({
        'post_id': postId,
        'user_id': userId,
      });
    }
  }

  Future<void> addComment(String postId, String userId, String content) async {
    await _supabase.from('post_comments').insert({
      'post_id': postId,
      'user_id': userId,
      'content': content,
    });
  }

  Future<void> deletePost(String postId) async {
    await _supabase.from('posts').delete().eq('id', postId);
  }

  // 리그 조과를 일반 피드에 공유 (league_id 없는 복사본 생성)
  Future<void> sharePostToFeed(Post post) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in');
    await _supabase.from('posts').insert({
      'user_id': userId,
      'image_url': post.imageUrl,
      'caption': post.caption,
      'fish_type': post.fishType,
      'lure_type': post.lureType,
      'location': post.location,
      'league_id': null,
      'length': post.length,
      'weight': post.weight,
      'catch_count': post.catchCount,
      'is_lunker': post.isLunker,
    });
  }

  Future<void> createPost({
    required String userId,
    required File imageFile,
    String? caption,
    String fishType = '배스',
    String? lureType,
    String? location,
    String? leagueId,
    double? length,
    double? weight,
    int catchCount = 1,
  }) async {
    // 1. Supabase Storage에 이미지 업로드
    final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final storagePath = 'posts/$fileName';

    await _supabase.storage.from('post_images').upload(
      storagePath,
      imageFile,
      fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: false),
    );

    final imageUrl = _supabase.storage.from('post_images').getPublicUrl(storagePath);

    // 2. posts 테이블에 insert
    await _supabase.from('posts').insert({
      'user_id': userId,
      'image_url': imageUrl,
      'caption': caption,
      'fish_type': fishType,
      'lure_type': lureType,
      'location': location,
      'league_id': leagueId,
      'length': length,
      'weight': weight,
      'catch_count': catchCount,
      'is_lunker': length != null && length >= 50.0,
    });
  }
}

@riverpod
FeedRepository feedRepository(FeedRepositoryRef ref) {
  return FeedRepository(Supabase.instance.client);
}

@riverpod
Future<List<Post>> feedPosts(FeedPostsRef ref) {
  return ref.watch(feedRepositoryProvider).getPosts();
}
