import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/image_compress.dart';
import 'post_model.dart';

part 'feed_repository.g.dart';

class FeedRepository {
  final SupabaseClient _supabase;

  FeedRepository(this._supabase);

  Future<List<Post>> getPosts() async {
    final response = await _supabase
        .from('posts')
        .select('id, user_id, league_id, image_url, image_urls, aspect_ratio, video_url, caption, fish_type, length, weight, catch_count, is_lunker, is_personal_record, location, created_at, users(username, avatar_url), post_likes(count), post_comments(count)')
        .isFilter('league_id', null)
        .eq('is_personal_record', false)
        .or('is_deleted.is.null,is_deleted.eq.false')
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
        .select('id')
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

  // 리그 조과 / 개인 기록을 일반 피드에 공유
  Future<void> sharePostToFeed(Post post) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in');
    await _supabase.from('posts').insert({
      'user_id': userId,
      'image_url': post.imageUrl,
      'image_urls': post.imageUrls,
      'aspect_ratio': post.aspectRatio,
      'caption': post.caption,
      'fish_type': post.fishType,
      'lure_type': post.lureType,
      'location': post.location,
      'league_id': null,
      'is_personal_record': false,
      'length': post.length,
      'weight': post.weight,
      'catch_count': post.catchCount,
      'is_lunker': post.isLunker,
    });
  }

  Future<void> createPost({
    required String userId,
    File? imageFile,           // 단일 이미지 (리그 조과 등 하위 호환)
    List<File>? imageFiles,   // 다중 이미지 (피드 업로드)
    File? videoFile,
    Uint8List? videoThumbnailBytes,
    double? aspectRatio,
    String? caption,
    String fishType = '배스',
    String? lureType,
    String? location,
    double? lat,
    double? lng,
    String? leagueId,
    double? length,
    double? weight,
    int catchCount = 1,
    bool isPersonalRecord = false,
  }) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    String imageUrl;
    String? videoUrl;
    List<String>? imageUrls;

    if (videoFile != null) {
      if (videoThumbnailBytes != null) {
        final thumbPath = 'posts/${userId}_${ts}_thumb.jpg';
        await _supabase.storage.from('post_images').uploadBinary(
          thumbPath,
          videoThumbnailBytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: false),
        );
        imageUrl = _supabase.storage.from('post_images').getPublicUrl(thumbPath);
      } else {
        imageUrl = '';
      }

      final videoPath = 'posts/${userId}_$ts.mp4';
      await _supabase.storage.from('post_videos').upload(
        videoPath,
        videoFile,
        fileOptions: const FileOptions(contentType: 'video/mp4', upsert: false),
      );
      videoUrl = _supabase.storage.from('post_videos').getPublicUrl(videoPath);
    } else if (imageFiles != null && imageFiles.isNotEmpty) {
      final urls = <String>[];
      for (int i = 0; i < imageFiles.length; i++) {
        final compressed = await compressForUpload(imageFiles[i]);
        final storagePath = 'posts/${userId}_${ts}_$i.jpg';
        await _supabase.storage.from('post_images').upload(
          storagePath,
          compressed,
          fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: false),
        );
        urls.add(_supabase.storage.from('post_images').getPublicUrl(storagePath));
      }
      imageUrl = urls.first;
      imageUrls = urls;
    } else if (imageFile != null) {
      final compressed = await compressForUpload(imageFile);
      final storagePath = 'posts/${userId}_$ts.jpg';
      await _supabase.storage.from('post_images').upload(
        storagePath,
        compressed,
        fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: false),
      );
      imageUrl = _supabase.storage.from('post_images').getPublicUrl(storagePath);
    } else {
      throw Exception('이미지 또는 동영상을 선택해주세요');
    }

    await _supabase.from('posts').insert({
      'user_id': userId,
      'image_url': imageUrl,
      'image_urls': imageUrls,
      'aspect_ratio': aspectRatio,
      'video_url': videoUrl,
      'caption': caption,
      'fish_type': fishType,
      'lure_type': lureType,
      'location': location,
      'lat': lat,
      'lng': lng,
      'league_id': leagueId,
      'is_personal_record': isPersonalRecord,
      'is_deleted': false,
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
  final link = ref.keepAlive();
  Timer(const Duration(minutes: 5), link.close);
  return ref.watch(feedRepositoryProvider).getPosts();
}
