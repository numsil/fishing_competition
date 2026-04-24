import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_compress/video_compress.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_svg.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../feed/data/feed_repository.dart';
import '../../../league/data/league_repository.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  int _step = 0;
  XFile? _selectedFile;
  bool _isVideo = false;
  Uint8List? _thumbnailBytes;
  bool _generatingThumb = false;

  Future<void> _onMediaSelected(XFile file, bool isVideo) async {
    if (isVideo) {
      setState(() => _generatingThumb = true);
      final bytes = await VideoCompress.getByteThumbnail(file.path, quality: 80);
      if (!mounted) return;
      setState(() {
        _selectedFile = file;
        _isVideo = true;
        _thumbnailBytes = bytes;
        _generatingThumb = false;
        _step = 1;
      });
    } else {
      setState(() {
        _selectedFile = file;
        _isVideo = false;
        _thumbnailBytes = null;
        _step = 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_generatingThumb) {
      final accent = isDark ? AppColors.neonGreen : AppColors.navy;
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: isDark ? AppColors.darkBg : Colors.black,
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: accent),
                const SizedBox(height: 16),
                const Text('동영상 처리 중...', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ),
      );
    }

    return _step == 0
        ? _MediaPickerStep(isDark: isDark, onMediaSelected: _onMediaSelected)
        : _CaptionStep(
            isDark: isDark,
            selectedFile: _selectedFile!,
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
  final Future<void> Function(XFile, bool isVideo) onMediaSelected;

  @override
  State<_MediaPickerStep> createState() => _MediaPickerStepState();
}

class _MediaPickerStepState extends State<_MediaPickerStep> {
  final _picker = ImagePicker();
  bool _videoMode = false;

  Future<void> _pickFromGallery() async {
    try {
      if (_videoMode) {
        final video = await _picker.pickVideo(source: ImageSource.gallery);
        if (video != null) await widget.onMediaSelected(video, true);
      } else {
        final image = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 80,
          maxWidth: 1080,
          maxHeight: 1080,
        );
        if (image != null) await widget.onMediaSelected(image, false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('사진 보관함에 접근할 수 없습니다. 설정에서 권한을 허용해주세요.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _pickFromCamera() async {
    try {
      if (_videoMode) {
        final video = await _picker.pickVideo(source: ImageSource.camera);
        if (video != null) await widget.onMediaSelected(video, true);
      } else {
        final image = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 80,
          maxWidth: 1080,
          maxHeight: 1080,
        );
        if (image != null) await widget.onMediaSelected(image, false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('카메라에 접근할 수 없습니다. 설정에서 권한을 허용해주세요.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
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
        body: SafeArea(
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
                          : '갤러리에서 선택하거나 카메라로 촬영하세요',
                      style: TextStyle(color: sub, fontSize: 13),
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
    required this.selectedFile,
    required this.isVideo,
    required this.thumbnailBytes,
    required this.onBack,
  });
  final bool isDark;
  final XFile selectedFile;
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
  String _fish = '배스';
  String? _selectedLeagueId;
  bool _sharing = false;
  double _compressProgress = 0.0;
  dynamic _compressSub;

  static const _fishList = ['배스', '배스(스몰)', '쏘가리', '붕어', '잉어', '기타'];

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

  Future<void> _share() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }

    setState(() { _sharing = true; _compressProgress = 0.0; });

    try {
      File? compressedVideo;

      if (widget.isVideo) {
        _compressSub = VideoCompress.compressProgress$.subscribe((progress) {
          if (mounted) setState(() => _compressProgress = progress / 100.0);
        });

        final info = await VideoCompress.compressVideo(
          widget.selectedFile.path,
          quality: VideoQuality.MediumQuality,
          deleteOrigin: false,
          includeAudio: true,
        );

        _compressSub?.unsubscribe();
        _compressSub = null;
        compressedVideo = info?.file;
      }

      final lengthVal = double.tryParse(_lengthCtrl.text.trim());
      final weightVal = double.tryParse(_weightCtrl.text.trim());

      await ref.read(feedRepositoryProvider).createPost(
        userId: user.id,
        imageFile: widget.isVideo ? null : File(widget.selectedFile.path),
        videoFile: compressedVideo,
        videoThumbnailBytes: widget.thumbnailBytes,
        caption: _captionCtrl.text.trim().isEmpty ? null : _captionCtrl.text.trim(),
        fishType: _fish,
        location: _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
        leagueId: _selectedLeagueId,
        length: lengthVal,
        weight: weightVal,
      );

      ref.invalidate(feedPostsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _compressSub?.unsubscribe();
      _compressSub = null;
      if (mounted) {
        setState(() => _sharing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('업로드 실패: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildPreview() {
    if (widget.isVideo && widget.thumbnailBytes != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(widget.thumbnailBytes!, fit: BoxFit.cover),
          const Center(
            child: Icon(Icons.play_circle_outline_rounded, color: Colors.white, size: 36),
          ),
        ],
      );
    }
    return Image.file(File(widget.selectedFile.path), fit: BoxFit.cover);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final accent = isDark ? AppColors.neonGreen : AppColors.navy;
    final bg = isDark ? AppColors.darkBg : Colors.white;
    final sub = isDark ? const Color(0xFF8E8E8E) : const Color(0xFF737373);
    final divColor = isDark ? const Color(0xFF262626) : const Color(0xFFEEEEEE);
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: _sharing ? null : widget.onBack,
          icon: Icon(Icons.arrow_back_ios_rounded, color: textColor, size: 20),
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
            // ── 압축 진행률 (동영상만) ──
            if (_sharing && widget.isVideo)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _compressProgress < 1.0
                              ? '동영상 압축 중... ${(_compressProgress * 100).toInt()}%'
                              : '업로드 중...',
                          style: TextStyle(fontSize: 12, color: accent),
                        ),
                      ],
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

            // ── 썸네일 + 캡션 ──
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      width: 72, height: 72,
                      child: _buildPreview(),
                    ),
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

            // ── 어종 선택 ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('어종', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textColor)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _fishList.map((f) {
                      final selected = _fish == f;
                      return GestureDetector(
                        onTap: () => setState(() => _fish = f),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: selected ? accent : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected
                                  ? accent
                                  : (isDark ? const Color(0xFF333333) : const Color(0xFFDDDDDD)),
                            ),
                          ),
                          child: Text(
                            f,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: selected ? (isDark ? Colors.black : Colors.white) : sub,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

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
