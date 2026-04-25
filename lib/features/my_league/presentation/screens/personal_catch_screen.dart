import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/section_label.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../feed/data/feed_repository.dart';
import '../../../profile/data/profile_repository.dart';

class PersonalCatchScreen extends ConsumerStatefulWidget {
  const PersonalCatchScreen({super.key});

  @override
  ConsumerState<PersonalCatchScreen> createState() => _PersonalCatchScreenState();
}

class _PersonalCatchScreenState extends ConsumerState<PersonalCatchScreen> {
  File? _image;
  String _fishType = '배스';
  final _lengthCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _captionCtrl = TextEditingController();
  bool _submitting = false;

  static const _fishOptions = ['배스', '배스(스몰)', '쏘가리', '붕어', '잉어', '기타'];

  @override
  void dispose() {
    _lengthCtrl.dispose();
    _locationCtrl.dispose();
    _captionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1280,
    );
    if (picked != null) setState(() => _image = File(picked.path));
  }

  Future<void> _showSourceSheet() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.neonGreen : AppColors.navy;

    final choice = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF444444) : const Color(0xFFDDDDDD),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.camera_alt_rounded, color: accent),
              title: const Text('카메라로 촬영', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.photo_library_rounded, color: accent),
              title: const Text('갤러리에서 선택', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (choice != null) await _pickImage(choice);
  }

  Future<void> _submit() async {
    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진을 촬영해주세요'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final lengthVal = double.tryParse(_lengthCtrl.text.trim());

    setState(() => _submitting = true);
    try {
      await ref.read(feedRepositoryProvider).createPost(
        userId: user.id,
        imageFile: _image!,
        fishType: _fishType,
        length: lengthVal,
        location: _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
        caption: _captionCtrl.text.trim().isEmpty ? null : _captionCtrl.text.trim(),
        catchCount: 1,
        isPersonalRecord: true,
      );
      ref.invalidate(myPersonalRecordsProvider);
      ref.invalidate(myProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('조과가 기록되었습니다! 🎣'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('등록 실패: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.neonGreen : AppColors.navy;
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final sub = isDark ? AppColors.darkTextSub : AppColors.lightTextSub;
    final divColor = isDark ? AppColors.darkDivider : AppColors.lightDivider;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('개인 기록', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            Text('내 조과 앨범에 저장',
                style: TextStyle(fontSize: 11, color: Color(0xFF888888), fontWeight: FontWeight.w400)),
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
                      child: CircularProgressIndicator(strokeWidth: 2, color: accent))
                  : Text('등록',
                      style: TextStyle(color: accent, fontWeight: FontWeight.w800, fontSize: 15)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        children: [
          // ── 사진 촬영 영역 ──────────────────────────
          GestureDetector(
            onTap: _showSourceSheet,
            child: Container(
              height: 260,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface2 : AppColors.lightDivider,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _image == null ? divColor : accent,
                  width: _image == null ? 1 : 2,
                ),
              ),
              child: _image != null
                  ? Stack(fit: StackFit.expand, children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.file(_image!, fit: BoxFit.cover),
                      ),
                      Positioned(
                        bottom: 12, right: 12,
                        child: GestureDetector(
                          onTap: _showSourceSheet,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                              SizedBox(width: 6),
                              Text('다시 촬영',
                                  style: TextStyle(color: Colors.white,
                                      fontSize: 13, fontWeight: FontWeight.w600)),
                            ]),
                          ),
                        ),
                      ),
                    ])
                  : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(
                        width: 72, height: 72,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.camera_alt_rounded, size: 32, color: accent),
                      ),
                      const SizedBox(height: 14),
                      Text('탭하여 촬영하기',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: accent)),
                      const SizedBox(height: 4),
                      Text('잡은 물고기를 촬영하거나 갤러리에서 선택하세요',
                          style: TextStyle(fontSize: 12, color: sub)),
                    ]),
            ),
          ),
          const SizedBox(height: 24),

          // ── 어종 선택 ──────────────────────────
          SectionLabel(text: '어종', color: accent),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _fishOptions.map((fish) {
              final sel = _fishType == fish;
              return GestureDetector(
                onTap: () => setState(() => _fishType = fish),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: sel ? accent : cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: sel ? accent : divColor),
                  ),
                  child: Text(fish,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                        color: sel ? (isDark ? Colors.black : Colors.white) : sub,
                      )),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // ── 길이 입력 ──────────────────────────
          SectionLabel(text: '길이 (cm)', color: accent),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: divColor),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: TextField(
                    controller: _lengthCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                    decoration: InputDecoration(
                      hintText: '예) 42.5',
                      hintStyle: TextStyle(fontSize: 28, color: divColor, fontWeight: FontWeight.w800),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                Text('cm',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: sub)),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── 장소 ──────────────────────────
          SectionLabel(text: '장소 (선택)', color: accent),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: divColor),
            ),
            child: TextField(
              controller: _locationCtrl,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: '예) 충주호, 소양강 등',
                hintStyle: TextStyle(color: sub, fontSize: 13),
                border: InputBorder.none,
                prefixIcon: Icon(LucideIcons.mapPin, size: 18, color: sub),
                contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── 메모 ──────────────────────────
          SectionLabel(text: '메모 (선택)', color: accent),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: divColor),
            ),
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
              Expanded(
                child: Text('50cm 이상이면 자동으로 런커 배지가 부여됩니다',
                    style: TextStyle(fontSize: 12, color: AppColors.gold,
                        fontWeight: FontWeight.w600)),
              ),
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
              label: Text(_submitting ? '등록 중...' : '조과 기록하기',
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

