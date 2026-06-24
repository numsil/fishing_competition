import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_compress/video_compress.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../feed/data/feed_repository.dart';
import '../../../feed/data/post_model.dart';
import '../../../profile/data/profile_repository.dart';
import '../../../../core/utils/image_compress.dart';
import '../../../../core/utils/banned_error_handler.dart';
import '../../../../core/utils/youtube_url_parser.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/extensions/theme_extensions.dart';

const int _kMaxMedia = 5;

enum _UploadMode { media, url }

/// 업로드 화면 내부에서 사용하는 선택 미디어 항목
class _PickedItem {
  final String type; // 'image' | 'video'
  final XFile file;
  final Uint8List? thumbnailBytes; // 동영상만
  _PickedItem({required this.type, required this.file, this.thumbnailBytes});

  bool get isVideo => type == 'video';
  bool get isImage => type == 'image';
}

bool _isVideoPath(String path) {
  final lower = path.toLowerCase();
  return lower.endsWith('.mp4') ||
      lower.endsWith('.mov') ||
      lower.endsWith('.m4v') ||
      lower.endsWith('.avi') ||
      lower.endsWith('.mkv') ||
      lower.endsWith('.webm') ||
      lower.endsWith('.3gp');
}

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key, this.editPost});
  final Post? editPost;

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  int _step = 0;
  List<_PickedItem> _selectedMedia = [];
  bool _isYoutube = false;
  String? _youtubeUrl;
  String? _youtubeVideoId;
  bool _processingMedia = false;

  @override
  void initState() {
    super.initState();
    if (widget.editPost != null) _step = 1; // edit 모드: 미디어 선택 스킵
  }

  Future<void> _onMediaPicked(List<_PickedItem> items) async {
    if (items.isEmpty) return;
    setState(() {
      _selectedMedia = items.take(_kMaxMedia).toList();
      _isYoutube = false;
      _youtubeUrl = null;
      _youtubeVideoId = null;
      _step = 1;
    });
  }

  void _onYoutubeSelected(String url, String videoId) {
    setState(() {
      _youtubeUrl = url;
      _youtubeVideoId = videoId;
      _selectedMedia = [];
      _isYoutube = true;
      _step = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_processingMedia) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: context.isDark ? AppColors.darkBg : Colors.black,
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: context.accentColor),
                const SizedBox(height: 16),
                const Text('동영상 처리 중...', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ),
      );
    }

    return _step == 0
        ? _MediaPickerStep(
            isDark: context.isDark,
            onMediaPicked: _onMediaPicked,
            onYoutubeSelected: _onYoutubeSelected,
            onProcessing: (v) => setState(() => _processingMedia = v),
          )
        : _CaptionStep(
            isDark: context.isDark,
            media: _isYoutube ? const [] : _selectedMedia,
            isYoutube: _isYoutube,
            youtubeUrl: _youtubeUrl,
            youtubeVideoId: _youtubeVideoId,
            onBack: widget.editPost != null
                ? () => Navigator.of(context).pop()
                : () => setState(() => _step = 0),
            editPost: widget.editPost,
          );
  }
}

// ── Step 1: 미디어 선택 ───────────────────────────────────
class _MediaPickerStep extends StatefulWidget {
  const _MediaPickerStep({
    required this.isDark,
    required this.onMediaPicked,
    required this.onYoutubeSelected,
    required this.onProcessing,
  });
  final bool isDark;
  final Future<void> Function(List<_PickedItem> items) onMediaPicked;
  final void Function(String url, String videoId) onYoutubeSelected;
  final void Function(bool) onProcessing;

  @override
  State<_MediaPickerStep> createState() => _MediaPickerStepState();
}

class _MediaPickerStepState extends State<_MediaPickerStep> {
  final _picker = ImagePicker();
  _UploadMode _mode = _UploadMode.media;
  bool _loadingMedia = false;
  final _urlCtrl = TextEditingController();

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  void _submitYoutubeUrl() {
    final raw = _urlCtrl.text.trim();
    final id = extractYoutubeId(raw);
    if (id == null) {
      AppSnackBar.error(context, '올바른 유튜브 링크가 아닙니다.');
      return;
    }
    widget.onYoutubeSelected(raw, id);
  }

  /// 동영상 XFile들에 대해 썸네일 생성하여 _PickedItem 리스트 완성
  Future<List<_PickedItem>> _buildItems(List<XFile> picked) async {
    final items = <_PickedItem>[];
    for (final f in picked) {
      if (_isVideoPath(f.path)) {
        final bytes = await VideoCompress.getByteThumbnail(f.path, quality: 80);
        items.add(_PickedItem(type: 'video', file: f, thumbnailBytes: bytes));
      } else {
        items.add(_PickedItem(type: 'image', file: f));
      }
    }
    return items;
  }

  Future<void> _pickFromGallery() async {
    setState(() => _loadingMedia = true);
    try {
      // 사진 + 동영상 혼합 선택 (image_picker 1.0+)
      final picked = await _picker.pickMultipleMedia(
        imageQuality: 80,
        maxWidth: 1080,
        maxHeight: 1080,
        limit: _kMaxMedia,
      );
      if (picked.isEmpty) return;
      final limited = picked.take(_kMaxMedia).toList();
      final hasVideo = limited.any((f) => _isVideoPath(f.path));
      if (hasVideo) widget.onProcessing(true);
      final items = await _buildItems(limited);
      widget.onProcessing(false);
      await widget.onMediaPicked(items);
    } catch (e) {
      widget.onProcessing(false);
      if (mounted) {
        AppSnackBar.error(context, '미디어 보관함에 접근할 수 없습니다. 설정에서 권한을 허용해주세요.');
      }
    } finally {
      if (mounted) setState(() => _loadingMedia = false);
    }
  }

  Future<void> _pickPhotoFromCamera() async {
    setState(() => _loadingMedia = true);
    try {
      final image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1080,
        maxHeight: 1080,
      );
      if (image == null) return;
      await widget.onMediaPicked([_PickedItem(type: 'image', file: image)]);
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, '카메라에 접근할 수 없습니다. 설정에서 권한을 허용해주세요.');
      }
    } finally {
      if (mounted) setState(() => _loadingMedia = false);
    }
  }

  Future<void> _pickVideoFromCamera() async {
    setState(() => _loadingMedia = true);
    try {
      final video = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 3),
      );
      if (video == null) return;
      widget.onProcessing(true);
      final items = await _buildItems([video]);
      widget.onProcessing(false);
      await widget.onMediaPicked(items);
    } catch (e) {
      widget.onProcessing(false);
      if (mounted) {
        AppSnackBar.error(context, '카메라에 접근할 수 없습니다. 설정에서 권한을 허용해주세요.');
      }
    } finally {
      if (mounted) setState(() => _loadingMedia = false);
    }
  }

  Widget _buildMediaBody(Color accent, Color sub) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: SvgPicture.asset(
              'assets/images/nakstar.svg',
              width: 56,
              colorFilter: ColorFilter.mode(
                  Colors.white.withValues(alpha: 0.3), BlendMode.srcIn),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          '미디어를 선택해주세요',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          '사진/동영상 합쳐서 최대 $_kMaxMedia개까지 선택할 수 있습니다',
          style: TextStyle(color: sub, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            _PickButton(
              icon: Icons.collections_outlined,
              label: '보관함',
              accent: accent,
              onTap: _pickFromGallery,
            ),
            _PickButton(
              icon: Icons.camera_alt_outlined,
              label: '사진 촬영',
              accent: accent,
              onTap: _pickPhotoFromCamera,
            ),
            _PickButton(
              icon: Icons.videocam_outlined,
              label: '동영상 촬영',
              accent: accent,
              onTap: _pickVideoFromCamera,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUrlBody(Color accent, Color sub) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(LucideIcons.youtube, size: 48, color: Colors.white.withValues(alpha: 0.3)),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '유튜브 링크를 붙여넣으세요',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'youtube.com/watch?v=... / youtu.be/... / shorts 모두 지원',
            style: TextStyle(color: sub, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          TextField(
            controller: _urlCtrl,
            autocorrect: false,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submitYoutubeUrl(),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'https://youtu.be/…',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 14),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              prefixIcon: Icon(LucideIcons.link, color: Colors.white.withValues(alpha: 0.4), size: 18),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: _submitYoutubeUrl,
              child: const Text('다음', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bg = isDark ? AppColors.darkBg : Colors.black;
    final accent = isDark ? AppColors.neonGreen : AppColors.navy;
    final sub = Colors.white.withValues(alpha: 0.5);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: bg,
        body: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  // ── 상단 바 ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                          padding: EdgeInsets.zero,
                        ),
                        const Expanded(
                          child: Text(
                            '새 게시물',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),

                  // ── 미디어/URL 탭 ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          _ModeTab(
                            label: '미디어',
                            selected: _mode == _UploadMode.media,
                            accent: accent,
                            onTap: () => setState(() => _mode = _UploadMode.media),
                          ),
                          _ModeTab(
                            label: 'URL',
                            selected: _mode == _UploadMode.url,
                            accent: accent,
                            onTap: () => setState(() => _mode = _UploadMode.url),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── 중앙 안내 영역 ──
                  Expanded(
                    child: _mode == _UploadMode.url
                        ? _buildUrlBody(accent, sub)
                        : _buildMediaBody(accent, sub),
                  ),
                ],
              ),
            ),
            // ── 미디어 로딩 오버레이 ──
            if (_loadingMedia)
              Container(
                color: Colors.black.withValues(alpha: 0.7),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: accent),
                      const SizedBox(height: 16),
                      const Text(
                        '미디어 불러오는 중...',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({required this.label, required this.selected, required this.accent, required this.onTap});
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 40,
          decoration: BoxDecoration(
            color: selected ? accent : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.black : Colors.white.withValues(alpha: 0.6),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PickButton extends StatelessWidget {
  const _PickButton({required this.icon, required this.label, required this.accent, required this.onTap});
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 110,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: accent, size: 32),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ── Step 2: 캡션 작성 ─────────────────────────────────────
class _CaptionStep extends ConsumerStatefulWidget {
  const _CaptionStep({
    required this.isDark,
    required this.media,
    required this.isYoutube,
    this.youtubeUrl,
    this.youtubeVideoId,
    required this.onBack,
    this.editPost,
  });
  final bool isDark;
  final List<_PickedItem> media;
  final bool isYoutube;
  final String? youtubeUrl;
  final String? youtubeVideoId;
  final VoidCallback onBack;
  final Post? editPost;

  /// edit 모드 + 기존 게시물이 유튜브 게시물인지
  bool get isEditingYoutube =>
      editPost?.youtubeUrl != null && editPost!.youtubeUrl!.isNotEmpty;

  @override
  ConsumerState<_CaptionStep> createState() => _CaptionStepState();
}

class _CaptionStepState extends ConsumerState<_CaptionStep> {
  final _captionCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();
  final String _fish = '배스';
  bool _sharing = false;
  double _compressProgress = 0.0;
  int _compressIndex = 0; // 압축 중인 동영상 인덱스 (1-based)
  int _videoCount = 0;
  dynamic _compressSub;

  late List<_PickedItem> _items;
  bool _imageReplaced = false; // edit 모드에서 이미지를 교체했는지
  final _picker = ImagePicker();
  bool _addingMedia = false; // 추가 선택 중복 탭 방지

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.media);

    final post = widget.editPost;
    if (post != null) {
      // caption과 hashtag 분리
      final raw = post.caption ?? '';
      final parts = raw.split('\n\n');
      final tags = parts.where((p) => p.trim().startsWith('#')).join('\n\n');
      final text = parts.where((p) => !p.trim().startsWith('#')).join('\n\n');
      _captionCtrl.text = text;
      _tagCtrl.text = tags;
      _locationCtrl.text = post.location ?? '';
    }
  }

  @override
  void dispose() {
    _captionCtrl.dispose();
    _locationCtrl.dispose();
    _tagCtrl.dispose();
    _compressSub?.unsubscribe();
    VideoCompress.cancelCompression();
    super.dispose();
  }

  void _removeItem(int index) {
    if (_items.length <= 1) return; // 최소 1개 유지
    setState(() => _items.removeAt(index));
  }

  /// 보관함에서 미디어를 추가로 선택해 기존 목록에 누적 (사진+동영상 혼합)
  Future<void> _addMedia() async {
    if (_addingMedia || _items.length >= _kMaxMedia) return;
    final remaining = _kMaxMedia - _items.length;
    setState(() => _addingMedia = true);
    try {
      final picked = await _picker.pickMultipleMedia(
        imageQuality: 80,
        maxWidth: 1080,
        maxHeight: 1080,
        limit: remaining,
      );
      if (picked.isEmpty) return;
      // 이미 담긴 경로는 제외 (ReorderableListView 키 중복 방지)
      final existing = _items.map((e) => e.file.path).toSet();
      final added = <_PickedItem>[];
      for (final f in picked) {
        if (_items.length + added.length >= _kMaxMedia) break;
        if (existing.contains(f.path)) continue;
        existing.add(f.path);
        if (_isVideoPath(f.path)) {
          final bytes = await VideoCompress.getByteThumbnail(f.path, quality: 80);
          added.add(_PickedItem(type: 'video', file: f, thumbnailBytes: bytes));
        } else {
          added.add(_PickedItem(type: 'image', file: f));
        }
      }
      if (!mounted || added.isEmpty) return;
      setState(() => _items.addAll(added));
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, '미디어 보관함에 접근할 수 없습니다. 설정에서 권한을 허용해주세요.');
      }
    } finally {
      if (mounted) setState(() => _addingMedia = false);
    }
  }

  Future<void> _saveEdit() async {
    final post = widget.editPost!;
    setState(() { _sharing = true; });
    try {
      final rawCaption = _captionCtrl.text.trim();
      final rawTags = _tagCtrl.text.trim();
      final combinedCaption = [
        if (rawCaption.isNotEmpty) rawCaption,
        if (rawTags.isNotEmpty) rawTags,
      ].join('\n\n');

      // edit 모드는 사진 교체만 지원 (동영상/혼합 교체는 미지원)
      final imageFilesForEdit = _imageReplaced && _items.isNotEmpty
          ? _items.where((m) => m.isImage).map((m) => File(m.file.path)).toList()
          : null;

      await ref.read(feedRepositoryProvider).updatePost(
        postId: post.id,
        newImageFiles: imageFilesForEdit,
        caption: combinedCaption.isEmpty ? null : combinedCaption,
        location: _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
      );

      ref.invalidate(feedPostsProvider);
      ref.invalidate(myPostsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (await handleIfBanned(e)) return;
      if (mounted) {
        setState(() => _sharing = false);
        AppSnackBar.error(context, '수정 실패: $e');
      }
    }
  }

  Future<void> _share() async {
    // edit 모드
    if (widget.editPost != null) {
      await _saveEdit();
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) {
      AppSnackBar.warning(context, '로그인이 필요합니다.');
      return;
    }
    if (!widget.isYoutube && _items.isEmpty) {
      AppSnackBar.warning(context, '미디어를 최소 1개 선택해주세요.');
      return;
    }

    final videos = _items.where((m) => m.isVideo).toList();
    setState(() {
      _sharing = true;
      _compressProgress = 0.0;
      _compressIndex = 0;
      _videoCount = videos.length;
    });

    try {
      // 유튜브 링크 게시물 ─ 업로드 단계 없이 바로 createPost
      if (widget.isYoutube) {
        final rawCaption = _captionCtrl.text.trim();
        final rawTags = _tagCtrl.text.trim();
        final combinedCaption = [
          if (rawCaption.isNotEmpty) rawCaption,
          if (rawTags.isNotEmpty) rawTags,
        ].join('\n\n');

        await ref.read(feedRepositoryProvider).createPost(
          userId: user.id,
          youtubeUrl: widget.youtubeUrl,
          youtubeThumbnailUrl: widget.youtubeVideoId != null
              ? youtubeThumbnailUrl(widget.youtubeVideoId!)
              : null,
          aspectRatio: 16 / 9,
          caption: combinedCaption.isEmpty ? null : combinedCaption,
          fishType: _fish,
          location: _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
          leagueId: null,
        );

        ref.invalidate(feedPostsProvider);
        ref.invalidate(myPostsProvider);
        if (mounted) Navigator.of(context).pop();
        return;
      }

      // 미디어 압축 및 PickedMedia 리스트 구성
      final pickedList = <PickedMedia>[];
      int videoIdx = 0;
      for (final item in _items) {
        if (item.isImage) {
          final ar = await getAspectRatioForUpload(File(item.file.path));
          pickedList.add(PickedMedia(
            type: 'image',
            file: File(item.file.path),
            aspectRatio: ar,
          ));
        } else {
          // 동영상 압축
          videoIdx++;
          setState(() {
            _compressIndex = videoIdx;
            _compressProgress = 0.0;
          });
          _compressSub = VideoCompress.compressProgress$.subscribe((progress) {
            if (mounted) setState(() => _compressProgress = progress / 100.0);
          });
          MediaInfo? info;
          for (int attempt = 0; attempt < 2; attempt++) {
            info = await VideoCompress.compressVideo(
              item.file.path,
              quality: VideoQuality.MediumQuality,
              deleteOrigin: false,
              includeAudio: true,
            );
            if (info?.file != null) break;
            await Future.delayed(const Duration(milliseconds: 800));
          }
          _compressSub?.unsubscribe();
          _compressSub = null;
          final compressed = info?.file;
          if (compressed == null) {
            throw Exception('영상 압축에 실패했습니다. 다시 시도해주세요.');
          }
          double? ar;
          if (item.thumbnailBytes != null) {
            final dec = await decodeImageFromList(item.thumbnailBytes!);
            ar = dec.width / dec.height;
          }
          pickedList.add(PickedMedia(
            type: 'video',
            file: compressed,
            thumbnailBytes: item.thumbnailBytes,
            aspectRatio: ar,
          ));
        }
      }

      // 첫 미디어 기준 aspect_ratio (피드 카드 레이아웃에 사용)
      final firstAr = pickedList.first.aspectRatio;

      final rawCaption = _captionCtrl.text.trim();
      final rawTags = _tagCtrl.text.trim();
      final combinedCaption = [
        if (rawCaption.isNotEmpty) rawCaption,
        if (rawTags.isNotEmpty) rawTags,
      ].join('\n\n');

      await ref.read(feedRepositoryProvider).createPost(
        userId: user.id,
        mediaFiles: pickedList,
        aspectRatio: firstAr,
        caption: combinedCaption.isEmpty ? null : combinedCaption,
        fishType: _fish,
        location: _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
        leagueId: null,
      );

      ref.invalidate(feedPostsProvider);
      ref.invalidate(myPostsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _compressSub?.unsubscribe();
      _compressSub = null;
      if (await handleIfBanned(e)) return;
      if (mounted) {
        setState(() => _sharing = false);
        final msg = e.toString().contains('413')
            ? '파일 크기가 너무 큽니다. 더 짧은 영상이나 작은 사진을 사용해주세요.'
            : '업로드 실패: $e';
        AppSnackBar.error(context, msg);
      }
    }
  }

  // 로컬 이미지 풀스크린 다이얼로그
  void _openLocalFullscreen(BuildContext context, _PickedItem item, Color accent) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      builder: (_) => _LocalImageFullscreen(file: File(item.file.path)),
    );
  }

  // 미디어 한 항목 썸네일
  Widget _thumbFor(_PickedItem item) {
    if (item.isVideo) {
      if (item.thumbnailBytes != null) {
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(item.thumbnailBytes!, fit: BoxFit.cover),
            const Center(
              child: Icon(Icons.play_circle_outline_rounded, color: Colors.white, size: 28),
            ),
          ],
        );
      }
      return Container(color: Colors.black);
    }
    return Image.file(File(item.file.path), fit: BoxFit.cover);
  }

  // 첫 번째 미디어(또는 유튜브 썸네일) 미리보기
  Widget _buildFirstThumb() {
    if (widget.isYoutube && widget.youtubeVideoId != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: youtubeThumbnailUrl(widget.youtubeVideoId!),
            fit: BoxFit.cover,
          ),
          Container(color: Colors.black.withValues(alpha: 0.25)),
          const Center(
            child: Icon(LucideIcons.youtube, color: Colors.white, size: 28),
          ),
        ],
      );
    }
    // edit 모드: 기존 게시물의 첫 이미지/썸네일 표시
    if (widget.editPost != null && _items.isEmpty) {
      final url = widget.editPost!.imageUrls?.firstOrNull
          ?? widget.editPost!.imageUrl;
      return CachedNetworkImage(imageUrl: url, fit: BoxFit.cover);
    }
    if (_items.isNotEmpty) return _thumbFor(_items.first);
    return const SizedBox.shrink();
  }

  Future<void> _replaceImages() async {
    // edit 모드: 사진 교체만 지원 (다중 이미지)
    final picked = await ImagePicker().pickMultiImage(
      imageQuality: 80,
      maxWidth: 1080,
      maxHeight: 1080,
      limit: _kMaxMedia,
    );
    if (picked.isNotEmpty && mounted) {
      setState(() {
        _items = picked
            .take(_kMaxMedia)
            .map((f) => _PickedItem(type: 'image', file: f))
            .toList();
        _imageReplaced = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final accent = isDark ? AppColors.neonGreen : AppColors.navy;
    final bg = isDark ? AppColors.darkBg : Colors.white;
    final sub = isDark ? const Color(0xFF8E8E8E) : const Color(0xFF737373);
    final divColor = isDark ? const Color(0xFF262626) : const Color(0xFFEEEEEE);
    final textColor = isDark ? Colors.white : Colors.black;
    final isMulti = _items.length > 1;
    final hasAnyVideo = _items.any((m) => m.isVideo);
    // 새 게시물 작성 시: 미디어가 1개 이상이고 최대치 미만이면 "추가" 가능
    final canAddMore =
        widget.editPost == null && _items.isNotEmpty && _items.length < _kMaxMedia;
    final hasOnlyImagesEditable =
        widget.editPost != null && !widget.isEditingYoutube && widget.editPost!.videoUrl == null;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: _sharing ? null : widget.onBack,
          icon: Icon(LucideIcons.chevronLeft, color: textColor, size: 24),
        ),
        title: Text(
          widget.editPost != null ? '게시물 수정' : '새 게시물',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textColor),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _sharing ? null : _share,
              child: _sharing
                  ? SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: accent),
                    )
                  : Text(
                      widget.editPost != null ? '저장' : '공유',
                      style: TextStyle(color: accent, fontSize: 16, fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 40),
          children: [
            // ── 업로드 진행 표시 ──
            if (_sharing && hasAnyVideo)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _compressProgress < 1.0 && _compressIndex > 0
                          ? '동영상 $_compressIndex/$_videoCount 압축 중... ${(_compressProgress * 100).toInt()}%'
                          : '업로드 중...',
                      style: TextStyle(fontSize: 12, color: accent),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _compressProgress < 1.0 ? _compressProgress : null,
                        backgroundColor: divColor,
                        color: accent,
                        minHeight: 4,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            if (_sharing && !hasAnyVideo && _items.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('사진 업로드 중...', style: TextStyle(fontSize: 12, color: accent)),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        backgroundColor: divColor,
                        color: accent,
                        minHeight: 4,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),

            // ── 다중 미디어 스트립 (2개 이상이거나, 추가 가능 시) ──
            if (isMulti || canAddMore) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 0, 8),
                child: Row(children: [
                  Text(
                    '선택된 미디어 ${_items.length}/$_kMaxMedia',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textColor),
                  ),
                  const SizedBox(width: 6),
                  Text('(드래그로 순서 변경 · X로 삭제 · 탭하면 크게)', style: TextStyle(fontSize: 11, color: sub)),
                ]),
              ),
              SizedBox(
                height: 146,
                child: ReorderableListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  buildDefaultDragHandles: true,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      // "추가" 타일은 실제 미디어 범위 밖이므로 제외
                      if (oldIndex >= _items.length || newIndex > _items.length) return;
                      if (newIndex > oldIndex) newIndex--;
                      final it = _items.removeAt(oldIndex);
                      _items.insert(newIndex, it);
                    });
                  },
                  itemCount: _items.length + (canAddMore ? 1 : 0),
                  itemBuilder: (_, i) {
                    // 마지막: "+ 추가" 타일
                    if (i == _items.length) {
                      return GestureDetector(
                        key: const ValueKey('__add_tile__'),
                        onTap: _addingMedia ? null : _addMedia,
                        child: Container(
                          width: 110,
                          height: 130,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: divColor),
                          ),
                          child: _addingMedia
                              ? Center(
                                  child: SizedBox(
                                    width: 18, height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: accent),
                                  ),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_rounded, color: sub, size: 22),
                                    const SizedBox(height: 4),
                                    Text('추가', style: TextStyle(fontSize: 10, color: sub)),
                                  ],
                                ),
                        ),
                      );
                    }
                    final item = _items[i];
                    return GestureDetector(
                      key: ValueKey(item.file.path),
                      onTap: item.isImage
                          ? () => _openLocalFullscreen(context, item, accent)
                          : null,
                      child: Stack(
                        children: [
                          Container(
                            width: 110,
                            height: 130,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: i == 0 ? accent : divColor,
                                width: i == 0 ? 2 : 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(7),
                              child: _thumbFor(item),
                            ),
                          ),
                          if (i == 0)
                            Positioned(
                              bottom: 4, left: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: accent,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('대표', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.black)),
                              ),
                            ),
                          if (item.isVideo)
                            Positioned(
                              top: 2, left: 10,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Icon(Icons.videocam, color: Colors.white, size: 12),
                              ),
                            ),
                          Positioned(
                            top: 4, right: 12,
                            child: GestureDetector(
                              onTap: () => _removeItem(i),
                              child: Container(
                                width: 28, height: 28,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Divider(height: 1, color: divColor),
            ],

            // ── 첫 번째 썸네일 + 캡션 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          width: 72, height: 72,
                          child: _buildFirstThumb(),
                        ),
                      ),
                      if (isMulti)
                        Positioned(
                          bottom: 4, right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '+${_items.length - 1}',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      // edit 모드: 사진 교체 오버레이 (유튜브/영상 게시물은 제외)
                      if (hasOnlyImagesEditable)
                        Positioned.fill(
                          child: GestureDetector(
                            onTap: _replaceImages,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: TextField(
                controller: _captionCtrl,
                maxLines: null,
                minLines: 6,
                autofocus: true,
                style: TextStyle(fontSize: 15, color: textColor),
                decoration: InputDecoration(
                  hintText: '문구를 작성하세요...',
                  hintStyle: TextStyle(color: sub, fontSize: 15),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  isDense: false,
                ),
              ),
            ),

            Divider(height: 1, color: divColor),

            // ── 위치 추가 ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: _locationCtrl,
                style: TextStyle(fontSize: 14, color: textColor),
                decoration: InputDecoration(
                  hintText: '위치 추가',
                  hintStyle: TextStyle(color: sub, fontSize: 14),
                  border: InputBorder.none,
                  suffixIcon: Icon(Icons.location_on_outlined, color: sub, size: 20),
                  contentPadding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
                  isDense: true,
                ),
              ),
            ),

            Divider(height: 1, color: divColor),

            // ── 태그 ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: _tagCtrl,
                style: TextStyle(fontSize: 14, color: textColor),
                decoration: InputDecoration(
                  hintText: '#배스 #낚시 #충주호',
                  hintStyle: TextStyle(color: sub, fontSize: 14),
                  border: InputBorder.none,
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 0, right: 8),
                    child: Text('#', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: sub)),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                  contentPadding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
                  isDense: true,
                ),
              ),
            ),

            Divider(height: 1, color: divColor),
            _SettingRow(label: '공개 범위', value: '전체 공개', sub: sub, textColor: textColor, divColor: divColor),
          ],
        ),
      ),
    );
  }
}

/// 로컬 파일 이미지를 풀스크린으로 띄우는 단순 다이얼로그 위젯
class _LocalImageFullscreen extends StatelessWidget {
  const _LocalImageFullscreen({required this.file});
  final File file;

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          InteractiveViewer(
            minScale: 0.8,
            maxScale: 5.0,
            child: Center(
              child: Image.file(file, fit: BoxFit.contain),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.label,
    required this.sub,
    required this.textColor,
    required this.divColor,
    this.value,
  });
  final String label;
  final String? value;
  final Color sub, textColor, divColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Text(label, style: TextStyle(fontSize: 14, color: textColor)),
              const Spacer(),
              if (value != null) Text(value!, style: TextStyle(fontSize: 14, color: sub)),
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: sub),
            ],
          ),
        ),
        Divider(height: 1, color: divColor),
      ],
    );
  }
}
