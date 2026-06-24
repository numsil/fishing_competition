import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/extensions/theme_extensions.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../data/marketplace_repository.dart';

const _categories = ['낚시대', '릴', '루어', '소품', '기타'];

class MarketplaceUploadScreen extends ConsumerStatefulWidget {
  const MarketplaceUploadScreen({super.key});

  @override
  ConsumerState<MarketplaceUploadScreen> createState() => _MarketplaceUploadScreenState();
}

class _MarketplaceUploadScreenState extends ConsumerState<MarketplaceUploadScreen> {
  final _titleCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  String _category = '기타';
  final List<File> _images = [];
  bool _loading = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _priceCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(limit: 5);
    if (picked.isEmpty) return;
    setState(() {
      _images.clear();
      _images.addAll(picked.map((x) => File(x.path)));
    });
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final priceText = _priceCtrl.text.trim().replaceAll(',', '');
    final price = int.tryParse(priceText) ?? 0;

    if (title.isEmpty) {
      AppSnackBar.info(context, '제목을 입력해주세요.');
      return;
    }
    if (_images.isEmpty) {
      AppSnackBar.info(context, '사진을 1장 이상 추가해주세요.');
      return;
    }
    if (price <= 0) {
      AppSnackBar.info(context, '가격을 입력해주세요.');
      return;
    }

    setState(() => _loading = true);
    try {
      await ref.read(marketplaceRepositoryProvider).createItem(
        title: title,
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        price: price,
        imageFiles: _images,
        category: _category,
        location: _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
      );
      ref.invalidate(marketplaceItemsProvider);
      if (mounted) {
        AppSnackBar.success(context, '등록됐습니다!');
        context.pop();
      }
    } catch (e) {
      if (mounted) AppSnackBar.error(context, '등록 실패: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Scaffold(
      appBar: AppBar(title: const Text('중고거래 등록')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 사진 개수
            Row(
              children: [
                const Icon(LucideIcons.image, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  '사진 ${_images.length}/5',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _images.isEmpty
                        ? Colors.grey
                        : (isDark ? Colors.white : Colors.black87),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 사진 추가
            GestureDetector(
              onTap: _pickImages,
              child: Container(
                height: 100,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF333333) : const Color(0xFFDDDDDD)),
                ),
                child: _images.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.camera, color: Colors.grey),
                            SizedBox(height: 4),
                            Text('사진 추가 (최대 5장)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.all(8),
                        itemCount: _images.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) => ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(_images[i], width: 80, height: 80, fit: BoxFit.cover),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // 제목
            AppTextField(controller: _titleCtrl, hint: '제목'),
            const SizedBox(height: 12),

            // 가격
            AppTextField(
              controller: _priceCtrl,
              hint: '가격 (원)',
              keyboardType: TextInputType.number,
              inputFormatters: [_ThousandsFormatter()],
            ),
            const SizedBox(height: 12),

            // 카테고리
            DropdownButtonFormField<String>(
              value: _category,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _category = v ?? '기타'),
            ),
            const SizedBox(height: 12),

            // 거래 지역
            AppTextField(controller: _locationCtrl, hint: '거래 지역 (선택)'),
            const SizedBox(height: 12),

            // 설명
            AppTextField(
              controller: _descCtrl,
              hint: '상품 설명',
              maxLines: 5,
            ),
            const SizedBox(height: 24),

            AppButton(
              label: '등록하기',
              onPressed: _loading ? null : _submit,
              loading: _loading,
            ),
          ],
        ),
      ),
    );
  }
}

/// 숫자 입력에 천단위 콤마를 실시간으로 넣는 포매터.
class _ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();

    final number = int.parse(digits);
    final s = number.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    final formatted = buf.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
