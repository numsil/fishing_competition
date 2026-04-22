import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_svg.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  int _step = 0; // 0: 사진 선택, 1: 게시물 작성
  int _selectedPhoto = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _step == 0
        ? _PhotoPickerStep(
            isDark: isDark,
            selectedPhoto: _selectedPhoto,
            onSelect: (i) => setState(() => _selectedPhoto = i),
            onNext: () => setState(() => _step = 1),
          )
        : _CaptionStep(
            isDark: isDark,
            selectedPhoto: _selectedPhoto,
            onBack: () => setState(() => _step = 0),
          );
  }
}

// ── Step 1: 사진 선택 ─────────────────────────────────────
class _PhotoPickerStep extends StatelessWidget {
  const _PhotoPickerStep({
    required this.isDark,
    required this.selectedPhoto,
    required this.onSelect,
    required this.onNext,
  });
  final bool isDark;
  final int selectedPhoto;
  final ValueChanged<int> onSelect;
  final VoidCallback onNext;

  // 더미 사진 팔레트 (실제 앱에선 갤러리 이미지)
  static const _palette = [
    [Color(0xFF1A3026), Color(0xFF0A1A10)],
    [Color(0xFF2A1A0A), Color(0xFF1A0A05)],
    [Color(0xFF0A1A2A), Color(0xFF051020)],
    [Color(0xFF2A2A0A), Color(0xFF1A1A05)],
    [Color(0xFF2A0A1A), Color(0xFF1A0510)],
    [Color(0xFF0A2A2A), Color(0xFF051A1A)],
    [Color(0xFF1A1A2A), Color(0xFF0A0A1A)],
    [Color(0xFF2A1A1A), Color(0xFF1A0A0A)],
    [Color(0xFF0A2A1A), Color(0xFF051A0A)],
  ];

  static const _labels = [
    '배스 52.3cm', '쏘가리 38cm', '붕어 42cm',
    '배스 45cm', '잉어 60cm', '배스 38cm',
    '쏘가리 35cm', '붕어 30cm', '배스 48cm',
  ];

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColors.darkBg : Colors.black;
    final accent = isDark ? AppColors.neonGreen : AppColors.navy;

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
                    TextButton(
                      onPressed: onNext,
                      child: Text(
                        '다음',
                        style: TextStyle(
                          color: accent,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── 선택된 사진 미리보기 ──
              AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _palette[selectedPhoto],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                    Center(
                      child: AppSvg(
                        AppIcons.fish,
                        width: MediaQuery.of(context).size.width * 0.5,
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    Positioned(
                      bottom: 12, left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _labels[selectedPhoto],
                          style: TextStyle(
                            color: accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    // 확대 아이콘
                    Positioned(
                      bottom: 12, right: 12,
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.zoom_out_map_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                ),
              ),

              // ── 갤러리 / 카메라 탭 ──
              Container(
                color: isDark ? const Color(0xFF111111) : const Color(0xFF111111),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    _GalleryTabChip(label: '최근 항목', selected: true, accent: accent),
                    const SizedBox(width: 8),
                    const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 20),
                    const Spacer(),
                    _IconChip(icon: Icons.collections_outlined, accent: accent),
                    const SizedBox(width: 8),
                    _IconChip(icon: Icons.camera_alt_outlined, accent: accent),
                  ],
                ),
              ),

              // ── 사진 그리드 ──
              Expanded(
                child: Container(
                  color: Colors.black,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(1),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 1.5,
                      mainAxisSpacing: 1.5,
                    ),
                    itemCount: _palette.length,
                    itemBuilder: (_, i) {
                      final isSelected = i == selectedPhoto;
                      return GestureDetector(
                        onTap: () => onSelect(i),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: _palette[i],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                            ),
                            Center(
                              child: AppSvg(
                                AppIcons.fish,
                                size: 28,
                                color: Colors.white.withValues(alpha: 0.15),
                              ),
                            ),
                            // 선택 오버레이
                            if (isSelected) ...[
                              Container(color: Colors.white.withValues(alpha: 0.25)),
                              Positioned(
                                top: 4, right: 4,
                                child: Container(
                                  width: 22, height: 22,
                                  decoration: BoxDecoration(
                                    color: accent,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 1.5),
                                  ),
                                  child: Center(
                                    child: Icon(Icons.check_rounded,
                                        size: 13,
                                        color: isDark ? Colors.black : Colors.white),
                                  ),
                                ),
                              ),
                            ] else
                              Positioned(
                                top: 4, right: 4,
                                child: Container(
                                  width: 22, height: 22,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 1.5),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GalleryTabChip extends StatelessWidget {
  const _GalleryTabChip({required this.label, required this.selected, required this.accent});
  final String label;
  final bool selected;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: selected ? Colors.white : Colors.white60,
        fontSize: 14,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
      ),
    );
  }
}

class _IconChip extends StatelessWidget {
  const _IconChip({required this.icon, required this.accent});
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34, height: 34,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    );
  }
}

// ── Step 2: 캡션 작성 ─────────────────────────────────────
class _CaptionStep extends StatefulWidget {
  const _CaptionStep({
    required this.isDark,
    required this.selectedPhoto,
    required this.onBack,
  });
  final bool isDark;
  final int selectedPhoto;
  final VoidCallback onBack;

  @override
  State<_CaptionStep> createState() => _CaptionStepState();
}

class _CaptionStepState extends State<_CaptionStep> {
  final _captionCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  String _fish = '배스';
  String? _league = '충주호 배스 오픈';
  bool _sharing = false;

  static const _fishList = ['배스', '배스(스몰)', '쏘가리', '붕어', '잉어', '기타'];
  static const _leagues = ['없음', '충주호 배스 오픈', '소양강 챔피언십', '가평 계곡 대회'];

  static const _palette = [
    [Color(0xFF1A3026), Color(0xFF0A1A10)],
    [Color(0xFF2A1A0A), Color(0xFF1A0A05)],
    [Color(0xFF0A1A2A), Color(0xFF051020)],
    [Color(0xFF2A2A0A), Color(0xFF1A1A05)],
    [Color(0xFF2A0A1A), Color(0xFF1A0510)],
    [Color(0xFF0A2A2A), Color(0xFF051A1A)],
    [Color(0xFF1A1A2A), Color(0xFF0A0A1A)],
    [Color(0xFF2A1A1A), Color(0xFF1A0A0A)],
    [Color(0xFF0A2A1A), Color(0xFF051A0A)],
  ];

  @override
  void dispose() {
    _captionCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  void _share() async {
    setState(() => _sharing = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) Navigator.of(context).pop();
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
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
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
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: accent,
                      ),
                    )
                  : Text(
                      '공유',
                      style: TextStyle(
                        color: accent,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 40,
          ),
          children: [
            // ── 썸네일 + 캡션 ──
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 썸네일
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _palette[widget.selectedPhoto],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Center(
                        child: AppSvg(
                          AppIcons.fish,
                          size: 32,
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 캡션 입력
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
            Divider(height: 1, color: divColor),

            // ── 리그 태그 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('리그 태그', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textColor)),
                  const SizedBox(height: 10),
                  ..._leagues.map((l) {
                    final selected = _league == l || (l == '없음' && _league == null);
                    return InkWell(
                      onTap: () => setState(() => _league = l == '없음' ? null : l),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            if (l != '없음') ...[
                              AppSvg(AppIcons.trophy, size: 14, color: selected ? accent : sub),
                              const SizedBox(width: 10),
                            ] else ...[
                              Icon(Icons.block_rounded, size: 14, color: selected ? accent : sub),
                              const SizedBox(width: 10),
                            ],
                            Text(
                              l,
                              style: TextStyle(
                                fontSize: 14,
                                color: selected ? accent : textColor,
                                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                            const Spacer(),
                            if (selected)
                              Icon(Icons.check_rounded, size: 18, color: accent),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),

            const SizedBox(height: 8),
            Divider(height: 1, color: divColor),

            // ── 고급 설정 섹션들 (인스타 스타일) ──
            _SettingRow(
              label: '사람 태그',
              sub: sub,
              textColor: textColor,
              divColor: divColor,
            ),
            _SettingRow(
              label: '공개 범위',
              value: '전체 공개',
              sub: sub,
              textColor: textColor,
              divColor: divColor,
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
              if (value != null)
                Text(value!, style: TextStyle(fontSize: 14, color: sub)),
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
