import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
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
  XFile? _selectedImage;

  void _onImageSelected(XFile image) {
    setState(() {
      _selectedImage = image;
      _step = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _step == 0
        ? _PhotoPickerStep(
            isDark: isDark,
            onImageSelected: _onImageSelected,
          )
        : _CaptionStep(
            isDark: isDark,
            selectedImage: _selectedImage!,
            onBack: () => setState(() => _step = 0),
          );
  }
}

// ── Step 1: 사진 선택 ─────────────────────────────────────
class _PhotoPickerStep extends StatefulWidget {
  const _PhotoPickerStep({
    required this.isDark,
    required this.onImageSelected,
  });
  final bool isDark;
  final ValueChanged<XFile> onImageSelected;

  @override
  State<_PhotoPickerStep> createState() => _PhotoPickerStepState();
}

class _PhotoPickerStepState extends State<_PhotoPickerStep> {
  final _picker = ImagePicker();

  Future<void> _pickFromGallery() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1080,
        maxHeight: 1080,
      );
      if (image != null) widget.onImageSelected(image);
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
      final image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1080,
        maxHeight: 1080,
      );
      if (image != null) widget.onImageSelected(image);
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
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
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
                        child: AppSvg(
                          AppIcons.fish,
                          size: 48,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '사진을 선택해주세요',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '갤러리에서 선택하거나 카메라로 촬영하세요',
                      style: TextStyle(color: sub, fontSize: 13),
                    ),
                    const SizedBox(height: 40),
                    // ── 버튼 ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _PickButton(
                          icon: Icons.collections_outlined,
                          label: '사진 보관함',
                          accent: accent,
                          onTap: _pickFromGallery,
                        ),
                        const SizedBox(width: 20),
                        _PickButton(
                          icon: Icons.camera_alt_outlined,
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

class _PickButton extends StatelessWidget {
  const _PickButton({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });
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
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
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
    required this.selectedImage,
    required this.onBack,
  });
  final bool isDark;
  final XFile selectedImage;
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

  static const _fishList = ['배스', '배스(스몰)', '쏘가리', '붕어', '잉어', '기타'];

  @override
  void dispose() {
    _captionCtrl.dispose();
    _locationCtrl.dispose();
    _lengthCtrl.dispose();
    _weightCtrl.dispose();
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

    setState(() => _sharing = true);

    try {
      final lengthVal = double.tryParse(_lengthCtrl.text.trim());
      final weightVal = double.tryParse(_weightCtrl.text.trim());

      await ref.read(feedRepositoryProvider).createPost(
        userId: user.id,
        imageFile: File(widget.selectedImage.path),
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
          onPressed: widget.onBack,
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
            // ── 썸네일 + 캡션 ──
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 선택된 실제 이미지 썸네일
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.file(
                      File(widget.selectedImage.path),
                      width: 72, height: 72,
                      fit: BoxFit.cover,
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
                              color: selected
                                  ? (isDark ? Colors.black : Colors.white)
                                  : sub,
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
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: divColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: divColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: accent),
                            ),
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
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: divColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: divColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: accent),
                            ),
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

            // ── 리그 태그 (DB에서 가져오기) ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('리그 태그', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textColor)),
                  const SizedBox(height: 10),
                  // 없음 옵션
                  InkWell(
                    onTap: () => setState(() => _selectedLeagueId = null),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Icon(Icons.block_rounded, size: 14,
                              color: _selectedLeagueId == null ? accent : sub),
                          const SizedBox(width: 10),
                          Text('없음',
                              style: TextStyle(
                                fontSize: 14,
                                color: _selectedLeagueId == null ? accent : textColor,
                                fontWeight: _selectedLeagueId == null ? FontWeight.w600 : FontWeight.w400,
                              )),
                          const Spacer(),
                          if (_selectedLeagueId == null)
                            Icon(Icons.check_rounded, size: 18, color: accent),
                        ],
                      ),
                    ),
                  ),
                  // DB 리그 목록
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

            _SettingRow(
              label: '사람 태그',
              sub: sub, textColor: textColor, divColor: divColor,
            ),
            _SettingRow(
              label: '공개 범위',
              value: '전체 공개',
              sub: sub, textColor: textColor, divColor: divColor,
            ),
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
