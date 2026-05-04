import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/section_label.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../feed/data/feed_repository.dart';
import '../../../profile/data/profile_repository.dart';
import '../../data/league_model.dart';
import '../../data/league_repository.dart';
import '../../../../core/utils/image_compress.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/extensions/theme_extensions.dart';

class LeagueCatchScreen extends ConsumerStatefulWidget {
  const LeagueCatchScreen({super.key, required this.league, this.initialImage});
  final League league;
  final File? initialImage;

  @override
  ConsumerState<LeagueCatchScreen> createState() => _LeagueCatchScreenState();
}

class _LeagueCatchScreenState extends ConsumerState<LeagueCatchScreen> {
  File? _image;
  double? _previewRatio;
  final String _fishType = '배스';
  final _measureCtrl = TextEditingController();
  final _captionCtrl = TextEditingController();
  bool _submitting = false;

  bool get _isWeightRule => widget.league.rule == '무게';

  @override
  void initState() {
    super.initState();
    if (widget.initialImage != null) {
      _image = widget.initialImage;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final ratio = await getAspectRatioForUpload(widget.initialImage!);
        if (mounted) setState(() => _previewRatio = ratio);
      });
    }
  }

  @override
  void dispose() {
    _measureCtrl.dispose();
    _captionCtrl.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1280,
    );
    if (picked != null) {
      final file = File(picked.path);
      final ratio = await getAspectRatioForUpload(file);
      if (mounted) setState(() { _image = file; _previewRatio = ratio; });
    }
  }

  Future<void> _pickFromGallery() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1280,
    );
    if (picked != null) {
      final file = File(picked.path);
      final ratio = await getAspectRatioForUpload(file);
      if (mounted) setState(() { _image = file; _previewRatio = ratio; });
    }
  }

  Future<void> _submit() async {
    if (_image == null) {
            AppSnackBar.warning(context, '사진을 촬영해주세요');
      return;
    }
    final val = double.tryParse(_measureCtrl.text.trim());
    if (val == null || val <= 0) {
            AppSnackBar.warning(context, _isWeightRule ? '무게를 입력해주세요' : '길이를 입력해주세요');
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _submitting = true);
    try {
      await ref.read(feedRepositoryProvider).createPost(
        userId: user.id,
        imageFile: _image!,
        aspectRatio: _previewRatio,
        leagueId: widget.league.id,
        fishType: _fishType,
        length: _isWeightRule ? null : val,
        weight: _isWeightRule ? val : null,
        catchCount: 1,
        caption: _captionCtrl.text.trim().isEmpty ? null : _captionCtrl.text.trim(),
      );
      ref.invalidate(leagueRankingProvider(widget.league.id));
      ref.invalidate(leagueDetailProvider(widget.league.id));
      ref.invalidate(leagueUserPostsProvider((widget.league.id, user.id)));
      ref.invalidate(feedPostsProvider);
      ref.invalidate(myPostsProvider);
      if (mounted) {
                AppSnackBar.success(context, '조과가 등록되었습니다! 🎣');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
                AppSnackBar.error(context, '등록 실패: $e');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = context.isDark ? AppColors.darkSurface : Colors.white;
    final sub = context.isDark ? AppColors.darkTextSub : AppColors.lightTextSub;
    final divColor = context.isDark ? AppColors.darkDivider : AppColors.lightDivider;

    final measureLabel = _isWeightRule ? '무게 (g)' : '길이 (cm)';
    final measureHint = _isWeightRule ? '예) 1250' : '예) 42.5';
    final measureSuffix = _isWeightRule ? 'g' : 'cm';

    return Scaffold(
      backgroundColor: context.isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        backgroundColor: context.isDark ? AppColors.darkBg : AppColors.lightBg,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('조과 등록', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            Text(widget.league.title,
                style: TextStyle(fontSize: 11, color: sub, fontWeight: FontWeight.w400)),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: context.accentColor))
                  : Text('등록', style: TextStyle(
                      color: context.accentColor, fontWeight: FontWeight.w800, fontSize: 15)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        children: [

          // ── 사진 촬영 영역 ──────────────────────────
          GestureDetector(
            onTap: _takePhoto,
            child: _image != null
                ? Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.accentColor, width: 2),
                    ),
                    child: AspectRatio(
                      aspectRatio: (_previewRatio ?? (4 / 3)).clamp(0.8, 1.91),
                      child: Stack(fit: StackFit.expand, children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Image.file(_image!, fit: BoxFit.cover),
                        ),
                        Positioned(
                          bottom: 12, right: 12,
                          child: GestureDetector(
                            onTap: _takePhoto,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                                SizedBox(width: 6),
                                Text('다시 촬영', style: TextStyle(color: Colors.white,
                                    fontSize: 13, fontWeight: FontWeight.w600)),
                              ]),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  )
                : Container(
                    height: 260,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: context.isDark ? AppColors.darkSurface2 : AppColors.lightDivider,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: divColor),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(
                        width: 72, height: 72,
                        decoration: BoxDecoration(
                          color: context.accentColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.camera_alt_rounded, size: 32, color: context.accentColor),
                      ),
                      const SizedBox(height: 14),
                      Text('탭하여 촬영하기',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.accentColor)),
                      const SizedBox(height: 4),
                      Text('잡은 물고기를 카메라로 촬영해주세요',
                          style: TextStyle(fontSize: 12, color: sub)),
                    ]),
                  ),
          ),
          const SizedBox(height: 24),

          // ── 계측값 입력 (룰에 따라 하나만) ─────────
          SectionLabel(text: measureLabel, color: context.accentColor),
          const SizedBox(height: 10),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            radius: 14,
            borderColor: divColor,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: TextField(
                    controller: _measureCtrl,
                    autofocus: false,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                    decoration: InputDecoration(
                      hintText: measureHint,
                      hintStyle: TextStyle(fontSize: 28, color: divColor, fontWeight: FontWeight.w800),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                Text(measureSuffix,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: sub)),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── 메모 ──────────────────────────────────
          SectionLabel(text: '메모 (선택)', color: context.accentColor),
          const SizedBox(height: 8),
          AppCard(
            padding: EdgeInsets.zero,
            radius: 12,
            borderColor: divColor,
            child: TextField(
              controller: _captionCtrl,
              maxLines: 3,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: '조과 상황, 사용한 루어 등을 자유롭게 입력하세요',
                hintStyle: TextStyle(color: sub, fontSize: 13),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── 런커 안내 (길이 기준 대회만) ────────────
          if (!_isWeightRule)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
              ),
              child: Row(children: [
                Icon(LucideIcons.award, size: 16, color: AppColors.gold),
                const SizedBox(width: 8),
                Text('50cm 이상이면 자동으로 런커 배지가 부여됩니다',
                    style: TextStyle(fontSize: 12, color: AppColors.gold,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
        ],
      ),

      // ── 하단 등록 버튼 ────────────────────────────
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.camera_alt_rounded, size: 22),
              label: Text(_submitting ? '등록 중...' : '조과 등록하기',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

