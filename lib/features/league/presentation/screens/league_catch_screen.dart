import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../feed/data/feed_repository.dart';
import '../../../profile/data/profile_repository.dart';
import '../../data/league_model.dart';
import '../../data/league_repository.dart';

class LeagueCatchScreen extends ConsumerStatefulWidget {
  const LeagueCatchScreen({super.key, required this.league});
  final League league;

  @override
  ConsumerState<LeagueCatchScreen> createState() => _LeagueCatchScreenState();
}

class _LeagueCatchScreenState extends ConsumerState<LeagueCatchScreen> {
  File? _image;
  late String _fishType;
  final _lengthCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _countCtrl  = TextEditingController(text: '1');
  final _captionCtrl = TextEditingController();
  bool _submitting = false;

  List<String> get _fishOptions {
    final opts = widget.league.fishTypes
        .split(',')
        .map((f) => f.trim())
        .where((f) => f.isNotEmpty)
        .toList();
    return opts.isEmpty ? ['배스'] : opts;
  }

  @override
  void initState() {
    super.initState();
    _fishType = _fishOptions.first;
  }

  @override
  void dispose() {
    _lengthCtrl.dispose();
    _weightCtrl.dispose();
    _countCtrl.dispose();
    _captionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 85, maxWidth: 1280);
    if (picked != null) setState(() => _image = File(picked.path));
  }

  void _showImagePicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(width: 36, height: 4,
              decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF444444) : const Color(0xFFCCCCCC),
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.camera_alt_rounded),
            title: const Text('카메라로 촬영', style: TextStyle(fontWeight: FontWeight.w600)),
            onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded),
            title: const Text('갤러리에서 선택', style: TextStyle(fontWeight: FontWeight.w600)),
            onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Future<void> _submit() async {
    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진을 등록해주세요'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    final length = double.tryParse(_lengthCtrl.text.trim());
    final count = int.tryParse(_countCtrl.text.trim()) ?? 1;
    if (count < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('마릿수를 확인해주세요'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _submitting = true);
    try {
      await ref.read(feedRepositoryProvider).createPost(
        userId: user.id,
        imageFile: _image!,
        leagueId: widget.league.id,
        fishType: _fishType,
        length: length,
        weight: double.tryParse(_weightCtrl.text.trim()),
        catchCount: count,
        caption: _captionCtrl.text.trim().isEmpty ? null : _captionCtrl.text.trim(),
      );
      ref.invalidate(leagueRankingProvider(widget.league.id));
      ref.invalidate(feedPostsProvider);
      ref.invalidate(myPostsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('조과가 등록되었습니다! 🎣'),
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
          SnackBar(content: Text('등록 실패: $e'), backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating),
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
                      child: CircularProgressIndicator(strokeWidth: 2, color: accent))
                  : Text('등록', style: TextStyle(
                      color: accent, fontWeight: FontWeight.w800, fontSize: 15)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        children: [

          // ── 사진 영역 ─────────────────────────────────
          GestureDetector(
            onTap: _showImagePicker,
            child: Container(
              height: 240,
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
                        bottom: 10, right: 10,
                        child: GestureDetector(
                          onTap: _showImagePicker,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text('변경', style: TextStyle(color: Colors.white,
                                  fontSize: 12, fontWeight: FontWeight.w600)),
                            ]),
                          ),
                        ),
                      ),
                    ])
                  : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(LucideIcons.camera, size: 28, color: accent),
                      ),
                      const SizedBox(height: 12),
                      Text('사진 촬영 / 갤러리 선택',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: accent)),
                      const SizedBox(height: 4),
                      Text('조과 사진을 등록해주세요',
                          style: TextStyle(fontSize: 12, color: sub)),
                    ]),
            ),
          ),
          const SizedBox(height: 20),

          // ── 어종 선택 ─────────────────────────────────
          _Label(text: '어종', accent: accent),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _fishOptions.map((fish) {
              final sel = _fishType == fish;
              return GestureDetector(
                onTap: () => setState(() => _fishType = fish),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? accent.withValues(alpha: 0.15) : cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: sel ? accent : divColor),
                  ),
                  child: Text(fish,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                        color: sel ? accent : sub,
                      )),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // ── 길이 / 무게 / 마릿수 ──────────────────────
          Row(children: [
            Expanded(
              child: _NumberField(
                label: '길이 (cm)',
                controller: _lengthCtrl,
                hint: '예) 42.5',
                suffix: 'cm',
                accent: accent,
                cardBg: cardBg,
                divColor: divColor,
                decimal: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _NumberField(
                label: '무게 (g)',
                controller: _weightCtrl,
                hint: '예) 1250',
                suffix: 'g',
                accent: accent,
                cardBg: cardBg,
                divColor: divColor,
                decimal: true,
              ),
            ),
          ]),
          const SizedBox(height: 16),

          _Label(text: '마릿수', accent: accent),
          const SizedBox(height: 8),
          // 마릿수 스테퍼
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: divColor),
            ),
            child: Row(children: [
              _StepBtn(
                icon: Icons.remove_rounded,
                onTap: () {
                  final cur = int.tryParse(_countCtrl.text) ?? 1;
                  if (cur > 1) _countCtrl.text = '${cur - 1}';
                },
                accent: accent,
              ),
              Expanded(
                child: TextField(
                  controller: _countCtrl,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    suffixText: '마리',
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              _StepBtn(
                icon: Icons.add_rounded,
                onTap: () {
                  final cur = int.tryParse(_countCtrl.text) ?? 1;
                  _countCtrl.text = '${cur + 1}';
                },
                accent: accent,
              ),
            ]),
          ),
          const SizedBox(height: 20),

          // ── 메모 ──────────────────────────────────────
          _Label(text: '메모 (선택)', accent: accent),
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
                hintText: '조과 상황, 사용한 루어 등을 입력하세요\n#해시태그도 추가할 수 있어요',
                hintStyle: TextStyle(color: sub, fontSize: 13),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── 런커 안내 ─────────────────────────────────
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
                  style: TextStyle(fontSize: 12, color: AppColors.gold, fontWeight: FontWeight.w600)),
            ]),
          ),
        ],
      ),

      // ── 하단 등록 버튼 ────────────────────────────────
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(LucideIcons.fish),
              label: Text(_submitting ? '등록 중...' : '조과 등록하기',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
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

// ── 라벨 ─────────────────────────────────────────────────
class _Label extends StatelessWidget {
  const _Label({required this.text, required this.accent});
  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 3, height: 14,
          decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 6),
      Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
    ]);
  }
}

// ── 숫자 입력 필드 ──────────────────────────────────────
class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.label,
    required this.controller,
    required this.hint,
    required this.suffix,
    required this.accent,
    required this.cardBg,
    required this.divColor,
    this.decimal = false,
  });
  final String label, hint, suffix;
  final TextEditingController controller;
  final Color accent, cardBg, divColor;
  final bool decimal;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Label(text: label, accent: accent),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: divColor),
        ),
        child: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: decimal
              ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]
              : [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            suffixText: suffix,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ),
    ]);
  }
}

// ── 스테퍼 버튼 ─────────────────────────────────────────
class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.onTap, required this.accent});
  final IconData icon;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: accent),
      ),
    );
  }
}
