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

const _categories = ['낚시대', '릴', '루어/채비', '보팅', '기타'];

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

  /// 사진 추가 (최대 5장까지 append)
  Future<void> _addImages() async {
    if (_images.length >= 5) {
      AppSnackBar.info(context, '사진은 최대 5장까지 추가할 수 있습니다.');
      return;
    }
    final picker = ImagePicker();
    final remaining = 5 - _images.length;
    final picked = await picker.pickMultiImage(limit: remaining);
    if (picked.isEmpty) return;
    setState(() {
      _images.addAll(picked.map((x) => File(x.path)));
      if (_images.length > 5) _images.length = 5;
    });
  }

  void _removeImage(int index) {
    setState(() => _images.removeAt(index));
  }

  void _openFullscreen(int index) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      builder: (_) => _LocalImageFullscreen(file: _images[index]),
    );
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
      ref.read(marketplaceListProvider.notifier).refresh();
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
            // 사진 개수 헤더
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
                if (_images.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text(
                    '(드래그로 순서 변경 · X로 삭제 · 탭하면 크게)',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),

            // 사진 영역
            if (_images.isEmpty)
              // 빈 상태: 추가 버튼
              GestureDetector(
                onTap: _addImages,
                child: Container(
                  height: 116,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? const Color(0xFF333333) : const Color(0xFFDDDDDD)),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.camera, color: Colors.grey),
                        SizedBox(height: 4),
                        Text('사진 추가 (최대 5장)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              )
            else
              // 사진 있을 때: 드래그 재정렬 가능한 가로 스트립
              SizedBox(
                height: 146,
                child: ReorderableListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(right: 8),
                  buildDefaultDragHandles: true,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      // "추가" 타일이 포함된 가상 인덱스 범위이므로
                      // 실제 이미지 범위 안에서만 처리
                      if (oldIndex >= _images.length || newIndex > _images.length) return;
                      if (newIndex > oldIndex) newIndex--;
                      final img = _images.removeAt(oldIndex);
                      _images.insert(newIndex, img);
                    });
                  },
                  itemCount: _images.length + (_images.length < 5 ? 1 : 0),
                  itemBuilder: (ctx, i) {
                    // 마지막 아이템: "+ 사진 추가" 타일
                    if (i == _images.length) {
                      return GestureDetector(
                        key: const ValueKey('__add_tile__'),
                        onTap: _addImages,
                        child: Container(
                          width: 110,
                          height: 130,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark ? const Color(0xFF333333) : const Color(0xFFDDDDDD),
                            ),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(LucideIcons.plus, color: Colors.grey, size: 20),
                              SizedBox(height: 4),
                              Text('사진 추가', style: TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                        ),
                      );
                    }

                    // 실제 이미지 타일
                    final file = _images[i];
                    final accentColor = context.accentColor;
                    final divColor = isDark ? const Color(0xFF333333) : const Color(0xFFDDDDDD);
                    return GestureDetector(
                      key: ValueKey(file.path),
                      onTap: () => _openFullscreen(i),
                      child: Stack(
                        children: [
                          Container(
                            width: 110,
                            height: 130,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: i == 0 ? accentColor : divColor,
                                width: i == 0 ? 2 : 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(7),
                              child: Image.file(file, fit: BoxFit.cover),
                            ),
                          ),
                          if (i == 0)
                            Positioned(
                              bottom: 4, left: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: accentColor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  '대표',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.black),
                                ),
                              ),
                            ),
                          Positioned(
                            top: 4, right: 12,
                            child: GestureDetector(
                              onTap: () => _removeImage(i),
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
