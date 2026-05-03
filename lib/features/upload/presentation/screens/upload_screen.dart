import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_compress/video_compress.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_svg.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../feed/data/feed_repository.dart';
import '../../../league/data/league_repository.dart';
import '../../../profile/data/profile_repository.dart';
import '../../../../core/utils/image_compress.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/extensions/theme_extensions.dart';

const int _kMaxImages = 5;

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  int _step = 0;
  List<XFile> _selectedImages = [];
  XFile? _selectedVideo;
  bool _isVideo = false;
  Uint8List? _thumbnailBytes;
  bool _generatingThumb = false;

  Future<void> _onMediaSelected(List<XFile> files, bool isVideo) async {
    if (isVideo) {
      final file = files.first;
      setState(() => _generatingThumb = true);
      final bytes = await VideoCompress.getByteThumbnail(file.path, quality: 80);
      if (!mounted) return;
      setState(() {
        _selectedVideo = file;
        _selectedImages = [];
        _isVideo = true;
        _thumbnailBytes = bytes;
        _generatingThumb = false;
        _step = 1;
      });
    } else {
      setState(() {
        _selectedImages = files;
        _selectedVideo = null;
        _isVideo = false;
        _thumbnailBytes = null;
        _step = 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_generatingThumb) {
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
        ? _MediaPickerStep(isDark: context.isDark, onMediaSelected: _onMediaSelected)
        : _CaptionStep(
            isDark: context.isDark,
            imageFiles: _isVideo ? [] : _selectedImages,
            videoFile: _isVideo ? _selectedVideo : null,
            isVideo: _isVideo,
            thumbnailBytes: _thumbnailBytes,
            onBack: () => setState(() => _step = 0),
          );
  }
}

// ── Step 1: 미디어 선택 ───────────────────────────────────
class _MediaPickerStep extends StatefulWidget {
  const _MediaPickerStep({required this.isDark, required this.onMediaSelected});
  final bool isDark;
  final Future<void> Function(List<XFile> files, bool isVideo) onMediaSelected;

  @override
  State<_MediaPickerStep> createState() => _MediaPickerStepState();
}

class _MediaPickerStepState extends State<_MediaPickerStep> {
  final _picker = ImagePicker();
  bool _videoMode = false;
  bool _loadingMedia = false;

  Future<void> _pickFromGallery() async {
    setState(() => _loadingMedia = true);
    try {
      if (_videoMode) {
        final video = await _picker.pickVideo(
          source: ImageSource.gallery,
          maxDuration: const Duration(minutes: 3),
        );
        if (video != null) await widget.onMediaSelected([video], true);
      } else {
        // 사진 최대 5장 다중 선택
        final images = await _picker.pickMultiImage(
          imageQuality: 80,
          maxWidth: 1080,
          maxHeight: 1080,
          limit: _kMaxImages,
        );
        if (images.isNotEmpty) {
          final selected = images.take(_kMaxImages).toList();
          await widget.onMediaSelected(selected, false);
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, '사진 보관함에 접근할 수 없습니다. 설정에서 권한을 허용해주세요.');
      }
    } finally {
      if (mounted) setState(() => _loadingMedia = false);
    }
  }

  Future<void> _pickFromCamera() async {
    setState(() => _loadingMedia = true);
    try {
      if (_videoMode) {
        final video = await _picker.pickVideo(
          source: ImageSource.camera,
          maxDuration: const Duration(minutes: 3),
        );
        if (video != null) await widget.onMediaSelected([video], true);
      } else {
        final image = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 80,
          maxWidth: 1080,
          maxHeight: 1080,
        );
        if (image != null) await widget.onMediaSelected([image], false);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, '카메라에 접근할 수 없습니다. 설정에서 권한을 허용해주세요.');
      }
    } finally {
      if (mounted) setState(() => _loadingMedia = false);
    }
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

                  // ── 사진/동영상 탭 ──
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
                            label: '사진',
                            selected: !_videoMode,
                            accent: accent,
                            onTap: () => setState(() => _videoMode = false),
                          ),
                          _ModeTab(
                            label: '동영상',
                            selected: _videoMode,
                            accent: accent,
                            onTap: () => setState(() => _videoMode = true),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── 중앙 안내 영역 ──
                  Expanded(
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
                            child: _videoMode
                                ? Icon(Icons.videocam_outlined, size: 48, color: Colors.white.withValues(alpha: 0.3))
                                : AppSvg(AppIcons.fish, size: 48, color: Colors.white.withValues(alpha: 0.3)),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _videoMode ? '동영상을 선택해주세요' : '사진을 선택해주세요',
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _videoMode
                              ? '갤러리에서 선택하거나 카메라로 촬영하세요'
                              : '갤러리에서 최대 \$_kMaxImages장까지 선택할 수 있습니다',
                          style: TextStyle(color: sub, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 40),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _PickButton(
                              icon: _videoMode ? Icons.video_library_outlined : Icons.collections_outlined,
                              label: '보관함',
                              accent: accent,
                              onTap: _pickFromGallery,
                            ),
                            const SizedBox(width: 20),
                            _PickButton(
                              icon: _videoMode ? Icons.videocam_outlined : Icons.camera_alt_outlined,
                              label: '카메라',
                              accent: accent,
                              onTap: _pickFromCamera,
                            ),
                          ],
                        ),
                      ],
                    ),
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
                      Text(
                        _videoMode ? '동영상 불러오는 중...' : '사진 불러오는 중...',
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
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
        width: 130,
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
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
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
    required this.imageFiles,
    required this.isVideo,
    this.videoFile,
    this.thumbnailBytes,
    required this.onBack,
  });
  final bool isDark;
  final List<XFile> imageFiles;   // 사진 모드
  final XFile? videoFile;          // 동영상 모드
  final bool isVideo;
  final Uint8List? thumbnailBytes;
  final VoidCallback onBack;

  @override
  ConsumerState<_CaptionStep> createState() => _CaptionStepState();
}

class _CaptionStepState extends ConsumerState<_CaptionStep> {
  final _captionCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _lengthCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final String _fish = '배스';
  String? _selectedLeagueId;
  bool _sharing = false;
  double _compressProgress = 0.0;
  dynamic _compressSub;

  // 사진 선택 목록 (삭제 가능)
  late List<XFile> _images;

  @override
  void initState() {
    super.initState();
    _images = List.from(widget.imageFiles);
  }

  @override
  void dispose() {
    _captionCtrl.dispose();
    _locationCtrl.dispose();
    _lengthCtrl.dispose();
    _weightCtrl.dispose();
    _compressSub?.unsubscribe();
    VideoCompress.cancelCompression();
    super.dispose();
  }

  void _removeImage(int index) {
    if (_images.length <= 1) return; // 최소 1장 유지
    setState(() => _images.removeAt(index));
  }

  Future<void> _share() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      AppSnackBar.info(context, '로그인이 필요합니다.');
      return;
    }
    if (!widget.isVideo && _images.isEmpty) {
      AppSnackBar.info(context, '사진을 최소 1장 선택해주세요.');
      return;
    }

    setState(() { _sharing = true; _compressProgress = 0.0; });

    try {
      File? compressedVideo;

      if (widget.isVideo) {
        _compressSub = VideoCompress.compressProgress$.subscribe((progress) {
          if (mounted) setState(() => _compressProgress = progress / 100.0);
        });

        MediaInfo? info;
        for (int attempt = 0; attempt < 2; attempt++) {
          info = await VideoCompress.compressVideo(
            widget.videoFile!.path,
            quality: VideoQuality.MediumQuality,
            deleteOrigin: false,
            includeAudio: true,
          );
          if (info?.file != null) break;
          await Future.delayed(const Duration(milliseconds: 800));
        }

        _compressSub?.unsubscribe();
        _compressSub = null;
        compressedVideo = info?.file;

        if (compressedVideo == null) {
          throw Exception('영상 압축에 실패했습니다. 다시 시도해주세요.');
        }
      }

      final lengthVal = double.tryParse(_lengthCtrl.text.trim());
      final weightVal = double.tryParse(_weightCtrl.text.trim());

      // 원본 파일에서 비율 계산 (압축 전 = EXIF 정상 적용)
      double? aspectRatio;
      if (!widget.isVideo && _images.isNotEmpty) {
        aspectRatio = await getAspectRatioForUpload(File(_images.first.path));
      }

      await ref.read(feedRepositoryProvider).createPost(
        userId: user.id,
        imageFiles: widget.isVideo ? null : _images.map((f) => File(f.path)).toList(),
        videoFile: compressedVideo,
        videoThumbnailBytes: widget.thumbnailBytes,
        aspectRatio: aspectRatio,
        caption: _captionCtrl.text.trim().isEmpty ? null : _captionCtrl.text.trim(),
        fishType: _fish,
        location: _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
        leagueId: _selectedLeagueId,
        length: lengthVal,
        weight: weightVal,
      );

      ref.invalidate(feedPostsProvider);
      ref.invalidate(myPostsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _compressSub?.unsubscribe();
      _compressSub = null;
      if (mounted) {
        setState(() => _sharing = false);
        final msg = e.toString().contains('413')
            ? '파일 크기가 너무 큽니다. 더 짧은 영상이나 작은 사진을 사용해주세요.'
            : '업로드 실패: $e';
        AppSnackBar.error(context, msg);
      }
    }
  }

  // 첫 번째 이미지 (또는 동영상 썸네일) 미리보기
  Widget _buildFirstThumb() {
    if (widget.isVideo && widget.thumbnailBytes != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(widget.thumbnailBytes!, fit: BoxFit.cover),
          const Center(child: Icon(Icons.play_circle_outline_rounded, color: Colors.white, size: 36)),
        ],
      );
    }
    if (_images.isNotEmpty) {
      return Image.file(File(_images.first.path), fit: BoxFit.cover);
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final accent = isDark ? AppColors.neonGreen : AppColors.navy;
    final bg = isDark ? AppColors.darkBg : Colors.white;
    final sub = isDark ? const Color(0xFF8E8E8E) : const Color(0xFF737373);
    final divColor = isDark ? const Color(0xFF262626) : const Color(0xFFEEEEEE);
    final textColor = isDark ? Colors.white : Colors.black;
    final isMulti = !widget.isVideo && _images.length > 1;

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
          '새 게시물',
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
                      '공유',
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
            if (_sharing && widget.isVideo)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _compressProgress < 1.0
                          ? '동영상 압축 중... ${(_compressProgress * 100).toInt()}%'
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
            if (_sharing && !widget.isVideo && _images.length > 1)
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

            // ── 다중 사진 선택 스트립 (2장 이상) ──
            if (isMulti) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 0, 8),
                child: Row(children: [
                  Text(
                    '선택된 사진 ${_images.length}/$_kMaxImages',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textColor),
                  ),
                  const SizedBox(width: 6),
                  Text('(길게 눌러 삭제)', style: TextStyle(fontSize: 11, color: sub)),
                ]),
              ),
              SizedBox(
                height: 96,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  itemCount: _images.length,
                  itemBuilder: (_, i) {
                    return GestureDetector(
                      onLongPress: () => _removeImage(i),
                      child: Stack(
                        children: [
                          Container(
                            width: 60,
                            height: 75,
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
                              child: Image.file(File(_images[i].path), fit: BoxFit.cover),
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
                          Positioned(
                            top: 2, right: 10,
                            child: GestureDetector(
                              onTap: () => _removeImage(i),
                              child: Container(
                                width: 18, height: 18,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close_rounded, color: Colors.white, size: 12),
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
              padding: const EdgeInsets.all(14),
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
                              '+${_images.length - 1}',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _captionCtrl,
                      maxLines: 5,
                      minLines: 3,
                      autofocus: true,
                      style: TextStyle(fontSize: 14, color: textColor),
                      decoration: InputDecoration(
                        hintText: '문구를 작성하거나 설문을 추가하세요...',
                        hintStyle: TextStyle(color: sub, fontSize: 14),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                    ),
                  ),
                ],
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
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  isDense: true,
                ),
              ),
            ),

            Divider(height: 1, color: divColor),
            const SizedBox(height: 20),

            // ── 사이즈 입력 ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('길이 (cm)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textColor)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _lengthCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(fontSize: 14, color: textColor),
                          decoration: InputDecoration(
                            hintText: '예) 42.5',
                            hintStyle: TextStyle(color: sub, fontSize: 14),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: divColor)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: divColor)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: accent)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('무게 (g)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textColor)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _weightCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(fontSize: 14, color: textColor),
                          decoration: InputDecoration(
                            hintText: '예) 980',
                            hintStyle: TextStyle(color: sub, fontSize: 14),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: divColor)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: divColor)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: accent)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            Divider(height: 1, color: divColor),

            // ── 리그 태그 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('리그 태그', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textColor)),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () => setState(() => _selectedLeagueId = null),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Icon(Icons.block_rounded, size: 14, color: _selectedLeagueId == null ? accent : sub),
                          const SizedBox(width: 10),
                          Text('없음',
                              style: TextStyle(
                                fontSize: 14,
                                color: _selectedLeagueId == null ? accent : textColor,
                                fontWeight: _selectedLeagueId == null ? FontWeight.w600 : FontWeight.w400,
                              )),
                          const Spacer(),
                          if (_selectedLeagueId == null) Icon(Icons.check_rounded, size: 18, color: accent),
                        ],
                      ),
                    ),
                  ),
                  ref.watch(leaguesProvider).when(
                    data: (leagues) => Column(
                      children: leagues
                          .where((l) => l.status == 'recruiting' || l.status == 'in_progress')
                          .map((l) {
                        final selected = _selectedLeagueId == l.id;
                        return InkWell(
                          onTap: () => setState(() => _selectedLeagueId = l.id),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              children: [
                                AppSvg(AppIcons.trophy, size: 14, color: selected ? accent : sub),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(l.title,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: selected ? accent : textColor,
                                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                                      )),
                                ),
                                if (selected) Icon(Icons.check_rounded, size: 18, color: accent),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    loading: () => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: CircularProgressIndicator(strokeWidth: 2, color: accent),
                    ),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),
            Divider(height: 1, color: divColor),

            _SettingRow(label: '사람 태그', sub: sub, textColor: textColor, divColor: divColor),
            _SettingRow(label: '공개 범위', value: '전체 공개', sub: sub, textColor: textColor, divColor: divColor),
          ],
        ),
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
