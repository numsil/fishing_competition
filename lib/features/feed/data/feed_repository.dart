import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/image_compress.dart';
import '../../../core/utils/score_calculator.dart';
import '../../../core/utils/storage_cleanup.dart';
import 'post_model.dart';
import '../../auth/data/auth_repository.dart';
import '../../verification/data/verification_repository.dart';

part 'feed_repository.g.dart';

const int kFeedPageSize = 20;

/// 업로드 시 사진/동영상 혼합 미디어 한 항목.
/// - image: [file]은 원본 이미지(압축은 repo에서 처리)
/// - video: [file]은 압축 완료된 mp4. [thumbnailBytes]는 썸네일 jpg 바이트.
class PickedMedia {
  final String type; // 'image' | 'video'
  final File file;
  final Uint8List? thumbnailBytes;
  final double? aspectRatio;

  const PickedMedia({
    required this.type,
    required this.file,
    this.thumbnailBytes,
    this.aspectRatio,
  });

  bool get isImage => type == 'image';
  bool get isVideo => type == 'video';
}

class FeedRepository {
  final SupabaseClient _supabase;

  FeedRepository(this._supabase);

  Future<List<Post>> getPosts({
    int limit = kFeedPageSize,
    DateTime? before,
    List<String> blockedUserIds = const [],
  }) async {
    var query = _supabase
        .from('posts')
        .select('id, user_id, league_id, image_url, image_urls, media, aspect_ratio, video_url, youtube_url, caption, fish_type, length, weight, catch_count, is_lunker, is_personal_record, review_status, location, created_at, users(username, avatar_url), post_comments(count)')
        .isFilter('league_id', null)
        .eq('is_personal_record', false)
        .or('is_deleted.is.null,is_deleted.eq.false');

    if (blockedUserIds.isNotEmpty) {
      // PostgREST not-in syntax: not.in.(uuid1,uuid2,...)
      query = query.not('user_id', 'in', '(${blockedUserIds.join(',')})');
    }

    if (before != null) {
      query = query.lt('created_at', before.toUtc().toIso8601String());
    }

    final response = await query
        .order('created_at', ascending: false)
        .limit(limit);

    return response.map((data) {
      final post = Post.fromJson(data);
      final usersData = data['users'];
      final String username = (usersData != null && usersData is Map) ? usersData['username'] ?? 'Unknown' : 'Unknown';
      final String avatarUrl = (usersData != null && usersData is Map) ? usersData['avatar_url'] ?? '' : '';

      final commentsData = data['post_comments'];
      final int comments = (commentsData is List && commentsData.isNotEmpty) ? commentsData[0]['count'] ?? 0 : 0;

      return post.copyWith(
        username: username,
        avatarUrl: avatarUrl,
        commentsCount: comments,
      );
    }).toList();
  }

  Future<void> addComment(String postId, String userId, String content) async {
    await _supabase.from('post_comments').insert({
      'post_id': postId,
      'user_id': userId,
      'content': content,
    });
  }

  Future<List<Map<String, dynamic>>> getComments(String postId) async {
    final response = await _supabase
        .from('post_comments')
        .select('id, user_id, content, created_at, users(username, avatar_url)')
        .eq('post_id', postId)
        .order('created_at', ascending: true)
        .limit(50);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> deletePost(String postId) async {
    final row = await _supabase
        .from('posts')
        .select('image_url, image_urls, video_url, media')
        .eq('id', postId)
        .maybeSingle();

    await _supabase.from('posts').delete().eq('id', postId);

    if (row != null) {
      final imageUrls = (row['image_urls'] as List?)?.cast<String>();
      await removePostStorageFiles(
        _supabase,
        imageUrl: row['image_url'] as String?,
        imageUrls: imageUrls,
        videoUrl: row['video_url'] as String?,
        media: row['media'] as List?,
      );
    }
  }

  Future<void> updatePostMeta({
    required String postId,
    String? caption,
    String? location,
  }) async {
    await _supabase.from('posts').update({
      'caption': caption?.trim().isEmpty == true ? null : caption?.trim(),
      'location': location?.trim().isEmpty == true ? null : location?.trim(),
    }).eq('id', postId);
  }

  Future<void> updatePost({
    required String postId,
    List<File>? newImageFiles,  // null이면 기존 이미지 유지
    String? caption,
    String? location,
    double? length,
    double? weight,
  }) async {
    final updates = <String, dynamic>{
      'caption': caption?.trim().isEmpty == true ? null : caption?.trim(),
      'location': location?.trim().isEmpty == true ? null : location?.trim(),
      'length': length,
      'weight': weight,
      'is_lunker': length != null && length >= 50.0,
      'score': calculateFishScore(length),
    };

    if (newImageFiles != null && newImageFiles.isNotEmpty) {
      final userId = _supabase.auth.currentUser?.id ?? '';
      final ts = DateTime.now().millisecondsSinceEpoch;
      final urls = <String>[];
      for (int i = 0; i < newImageFiles.length; i++) {
        final compressed = await compressForUpload(newImageFiles[i]);
        final storagePath = 'posts/${userId}_${ts}_$i.jpg';
        await _supabase.storage.from('post_images').upload(
          storagePath,
          compressed,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: false,
            cacheControl: '31536000',
          ),
        );
        urls.add(_supabase.storage.from('post_images').getPublicUrl(storagePath));
      }
      updates['image_url'] = urls.first;
      updates['image_urls'] = urls;
    }

    await _supabase.from('posts').update(updates).eq('id', postId);
  }

  /// 조과 앨범에서 선택한 여러 Post를 하나의 피드 포스트로 공유.
  /// 이미지는 재업로드 없이 기존 URL을 그대로 참조한다.
  Future<void> shareMultiplePostsToFeed({
    required List<Post> posts,
    String? caption,
    String? location,
    double? length,
    double? weight,
    String? leagueId,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in');
    if (posts.isEmpty) throw ArgumentError('posts must not be empty');
    final first = posts.first;
    // lure_type은 의도적으로 생략: 번들 공유는 여러 조과를 묶으므로 루어가 다를 수 있음
    await _supabase.from('posts').insert({
      'user_id': userId,
      'image_url': first.imageUrl,
      'image_urls': posts.map((p) => p.imageUrl).toList(),
      'aspect_ratio': first.aspectRatio,
      'caption': caption,
      'fish_type': first.fishType,
      'location': location,
      'league_id': leagueId,
      'is_personal_record': false,
      'is_deleted': false,
      'length': length,
      'weight': weight,
      'catch_count': posts.length,
      'is_lunker': length != null && length >= 50.0,
      'score': calculateFishScore(length),
    });
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
    List<PickedMedia>? mediaFiles, // 사진/동영상 혼합 (신규 피드 업로드)
    String? youtubeUrl,        // 유튜브 링크 게시물
    String? youtubeThumbnailUrl, // 유튜브 썸네일 (image_url 로 저장)
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
    List<Map<String, dynamic>>? mediaJson; // posts.media (jsonb)

    if (youtubeUrl != null && youtubeUrl.isNotEmpty) {
      // 유튜브 모드: 업로드 없이 썸네일 URL 만 image_url 에 저장
      imageUrl = youtubeThumbnailUrl ?? '';
    } else if (mediaFiles != null && mediaFiles.isNotEmpty) {
      // 혼합 미디어 모드: 순서대로 업로드 후 media jsonb + legacy 필드 둘 다 채움
      final media = <Map<String, dynamic>>[];
      final imgUrls = <String>[];
      String? firstVideoUrl;
      String? firstThumbOrImageUrl;
      for (int i = 0; i < mediaFiles.length; i++) {
        final m = mediaFiles[i];
        if (m.isImage) {
          final compressed = await compressForUpload(m.file);
          final storagePath = 'posts/${userId}_${ts}_$i.jpg';
          await _supabase.storage.from('post_images').upload(
            storagePath,
            compressed,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
              cacheControl: '31536000',
            ),
          );
          final url = _supabase.storage.from('post_images').getPublicUrl(storagePath);
          imgUrls.add(url);
          media.add({
            'type': 'image',
            'url': url,
            if (m.aspectRatio != null) 'aspect_ratio': m.aspectRatio,
          });
          firstThumbOrImageUrl ??= url;
        } else {
          // video
          String? thumbUrl;
          if (m.thumbnailBytes != null) {
            final thumbPath = 'posts/${userId}_${ts}_${i}_thumb.jpg';
            await _supabase.storage.from('post_images').uploadBinary(
              thumbPath,
              m.thumbnailBytes!,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: false,
                cacheControl: '31536000',
              ),
            );
            thumbUrl = _supabase.storage.from('post_images').getPublicUrl(thumbPath);
          }
          final videoPath = 'posts/${userId}_${ts}_$i.mp4';
          await _supabase.storage.from('post_videos').upload(
            videoPath,
            m.file,
            fileOptions: const FileOptions(
              contentType: 'video/mp4',
              upsert: false,
              cacheControl: '31536000',
            ),
          );
          final url = _supabase.storage.from('post_videos').getPublicUrl(videoPath);
          firstVideoUrl ??= url;
          firstThumbOrImageUrl ??= thumbUrl;
          media.add({
            'type': 'video',
            'url': url,
            if (thumbUrl != null) 'thumbnail_url': thumbUrl,
            if (m.aspectRatio != null) 'aspect_ratio': m.aspectRatio,
          });
        }
      }
      mediaJson = media;
      // legacy 호환: image_url(NOT NULL)에는 첫 미디어의 (이미지|동영상 썸네일) URL
      imageUrl = firstThumbOrImageUrl ?? '';
      // legacy: image_urls는 사진들만, video_url은 첫 동영상
      imageUrls = imgUrls.isNotEmpty ? imgUrls : null;
      videoUrl = firstVideoUrl;
    } else if (videoFile != null) {
      if (videoThumbnailBytes != null) {
        final thumbPath = 'posts/${userId}_${ts}_thumb.jpg';
        await _supabase.storage.from('post_images').uploadBinary(
          thumbPath,
          videoThumbnailBytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: false,
            cacheControl: '31536000',
          ),
        );
        imageUrl = _supabase.storage.from('post_images').getPublicUrl(thumbPath);
      } else {
        imageUrl = '';
      }

      final videoPath = 'posts/${userId}_$ts.mp4';
      await _supabase.storage.from('post_videos').upload(
        videoPath,
        videoFile,
        fileOptions: const FileOptions(
          contentType: 'video/mp4',
          upsert: false,
          cacheControl: '31536000',
        ),
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
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: false,
            cacheControl: '31536000',
          ),
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
        fileOptions: const FileOptions(
          contentType: 'image/jpeg',
          upsert: false,
          cacheControl: '31536000',
        ),
      );
      imageUrl = _supabase.storage.from('post_images').getPublicUrl(storagePath);
    } else {
      throw Exception('이미지 또는 동영상을 선택해주세요');
    }

    final inserted = await _supabase.from('posts').insert({
      'user_id': userId,
      'image_url': imageUrl,
      'image_urls': imageUrls,
      'media': mediaJson,
      'aspect_ratio': aspectRatio,
      'video_url': videoUrl,
      'youtube_url': youtubeUrl,
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
      'score': calculateFishScore(length),
      // review_status는 DB 트리거(enforce_initial_review_status)가 강제 설정
    }).select('id').single();

    // 개인기록만 인증 요청 생성
    if (isPersonalRecord) {
      final verificationRepo = VerificationRepository(_supabase);
      await verificationRepo.createVerificationRequest(
        inserted['id'] as String,
        userId,
      );
    }
  }
}

@riverpod
FeedRepository feedRepository(FeedRepositoryRef ref) {
  return FeedRepository(Supabase.instance.client);
}

@riverpod
class FeedPosts extends _$FeedPosts {
  bool _hasMore = true;
  bool _loading = false;

  bool get hasMore => _hasMore;

  @override
  Future<List<Post>> build() async {
    _hasMore = true;
    _loading = false;
    final link = ref.keepAlive();
    Timer(const Duration(minutes: 5), link.close);
    final blocked = await ref.read(authRepositoryProvider).getBlockedUserIds();
    final first = await ref.watch(feedRepositoryProvider).getPosts(
          limit: kFeedPageSize,
          blockedUserIds: blocked,
        );
    _hasMore = first.length >= kFeedPageSize;
    return first;
  }

  Future<void> loadMore() async {
    if (_loading || !_hasMore) return;
    final current = state.valueOrNull;
    if (current == null || current.isEmpty) return;
    _loading = true;
    try {
      final blocked = await ref.read(authRepositoryProvider).getBlockedUserIds();
      final next = await ref.read(feedRepositoryProvider).getPosts(
            limit: kFeedPageSize,
            before: current.last.createdAt,
            blockedUserIds: blocked,
          );
      _hasMore = next.length >= kFeedPageSize;
      if (next.isNotEmpty) {
        state = AsyncData([...current, ...next]);
      }
    } finally {
      _loading = false;
    }
  }
}
