import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_svg.dart';
import '../../../auth/data/auth_repository.dart';
import '../../data/league_repository.dart';

class LeagueCreateScreen extends ConsumerStatefulWidget {
  const LeagueCreateScreen({super.key});

  @override
  ConsumerState<LeagueCreateScreen> createState() => _LeagueCreateScreenState();
}

class _LeagueCreateScreenState extends ConsumerState<LeagueCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _maxCtrl = TextEditingController();
  final _feeCtrl = TextEditingController();
  final _introCtrl = TextEditingController();

  DateTimeRange? _dateRange;
  String _rule = '최대어';
  bool _isPublic = true;

  // 어종
  String _fishCategory = '민물';
  final Set<String> _selectedFish = {'배스'};

  // 장소 좌표
  LatLng? _selectedLatLng;

  // 상금/상품
  String _prizeType = '상금';
  final List<_PrizeItem> _prizes = [
    _PrizeItem(rank: '1위', value: ''),
    _PrizeItem(rank: '2위', value: ''),
    _PrizeItem(rank: '3위', value: ''),
  ];
  final _etcPrizeCtrl = TextEditingController();

  // 소개 이미지 (URL 리스트)
  final List<String> _introImages = [];

  bool _creating = false;

  static const _rules = ['최대어', '합산 길이', '마릿수', '최대어 + 마릿수'];
  static const _freshFish = ['배스', '배스(스몰)', '쏘가리', '붕어', '잉어', '향어', '가물치', '메기', '강준치', '피라미'];
  static const _saltFish = ['광어', '볼락', '우럭', '참돔', '감성돔', '삼치', '고등어', '방어', '농어', '무늬오징어'];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _locationCtrl.dispose();
    _maxCtrl.dispose();
    _feeCtrl.dispose();
    _introCtrl.dispose();
    _etcPrizeCtrl.dispose();
    super.dispose();
  }

  // ── 리그 개설 ──
  Future<void> _createLeague() async {
    if (_formKey.currentState?.validate() != true) return;
    if (_dateRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('일정을 선택해주세요.')),
      );
      return;
    }
    if (_locationCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('장소를 입력해주세요.')),
      );
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }

    setState(() => _creating = true);
    try {
      await ref.read(leagueRepositoryProvider).createLeague(
        hostId: user.id,
        title: _nameCtrl.text.trim(),
        description: _introCtrl.text.trim().isEmpty ? null : _introCtrl.text.trim(),
        location: _locationCtrl.text.trim(),
        lat: _selectedLatLng?.latitude,
        lng: _selectedLatLng?.longitude,
        startTime: _dateRange!.start,
        endTime: _dateRange!.end,
        entryFee: int.tryParse(_feeCtrl.text) ?? 0,
        maxParticipants: int.tryParse(_maxCtrl.text) ?? 100,
        fishTypes: _selectedFish.isEmpty ? '미정' : _selectedFish.join(', '),
        rule: _rule,
        prizeInfo: _buildPrizeInfo(),
        isPublic: _isPublic,
      );
      ref.invalidate(leaguesProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _creating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('개설 실패: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  // ── 시상 정보 문자열 생성 ──
  String? _buildPrizeInfo() {
    if (_prizeType == '기타') {
      final t = _etcPrizeCtrl.text.trim();
      return t.isEmpty ? null : t;
    }
    final lines = _prizes
        .where((p) => p.value.trim().isNotEmpty)
        .map((p) => _prizeType == '상금'
            ? '${p.rank}: ${p.value}원'
            : '${p.rank}: ${p.value}')
        .toList();
    return lines.isEmpty ? null : lines.join('\n');
  }

  // ── 날짜 선택 ──
  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final result = await showDateRangePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
      initialDateRange: _dateRange,
      locale: const Locale('ko', 'KR'),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final accent = isDark ? AppColors.neonGreen : AppColors.navy;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? ColorScheme.dark(primary: accent, onPrimary: Colors.black)
                : ColorScheme.light(primary: accent, onPrimary: Colors.white),
          ),
          child: child!,
        );
      },
    );
    if (result != null) setState(() => _dateRange = result);
  }

  // ── 지도 선택 팝업 ──
  Future<void> _openMapPicker() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.neonGreen : AppColors.navy;
    LatLng pinned = _selectedLatLng ?? const LatLng(36.8, 127.9);
    final mapCtrl = MapController();

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Dialog(
          insetPadding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: SizedBox(
            width: double.infinity,
            height: 480,
            child: Column(
              children: [
                // 헤더
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                  child: Row(
                    children: [
                      const Text('장소 선택', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded, size: 22),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // 지도
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(0)),
                    child: Stack(
                      children: [
                        FlutterMap(
                          mapController: mapCtrl,
                          options: MapOptions(
                            initialCenter: pinned,
                            initialZoom: 9,
                            onTap: (_, latlng) => setS(() => pinned = latlng),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.huk.app',
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: pinned,
                                  width: 40,
                                  height: 40,
                                  child: Icon(Icons.location_pin, color: accent, size: 40),
                                ),
                              ],
                            ),
                          ],
                        ),
                        // 안내
                        Positioned(
                          top: 10, left: 0, right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text('지도를 탭하여 위치를 선택하세요',
                                  style: TextStyle(color: Colors.white, fontSize: 12)),
                            ),
                          ),
                        ),
                        // 좌표 표시
                        Positioned(
                          bottom: 10, left: 0, right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${pinned.latitude.toStringAsFixed(4)}, ${pinned.longitude.toStringAsFixed(4)}',
                                style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // 확인 버튼
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _selectedLatLng = pinned;
                          _locationCtrl.text =
                              '${pinned.latitude.toStringAsFixed(4)}, ${pinned.longitude.toStringAsFixed(4)}';
                        });
                        Navigator.pop(ctx);
                      },
                      child: const Text('이 위치로 선택'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── 소개 이미지 팝업 ──
  Future<void> _openImagePopup() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.neonGreen : AppColors.navy;
    final urlCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Dialog(
          insetPadding: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('이미지 추가', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded, size: 22),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // 추가된 이미지 목록
                if (_introImages.isNotEmpty) ...[
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _introImages.length,
                      itemBuilder: (_, i) => Stack(
                        children: [
                          Container(
                            width: 80, height: 80,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: AppSvg(AppIcons.fish, size: 36,
                                  color: isDark ? const Color(0xFF444444) : const Color(0xFFCCCCCC)),
                            ),
                          ),
                          Positioned(
                            top: 2, right: 10,
                            child: GestureDetector(
                              onTap: () => setS(() {
                                setState(() => _introImages.removeAt(i));
                              }),
                              child: Container(
                                width: 18, height: 18,
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, size: 12, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                // 이미지 추가 버튼들
                Row(
                  children: [
                    Expanded(
                      child: _ImgBtn(
                        icon: Icons.camera_alt_outlined,
                        label: '카메라',
                        accent: accent,
                        isDark: isDark,
                        onTap: () {
                          setS(() {
                            setState(() => _introImages.add('camera_${_introImages.length}'));
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ImgBtn(
                        icon: Icons.photo_library_outlined,
                        label: '갤러리',
                        accent: accent,
                        isDark: isDark,
                        onTap: () {
                          setS(() {
                            setState(() => _introImages.add('gallery_${_introImages.length}'));
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // URL 직접 입력
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: urlCtrl,
                        style: const TextStyle(fontSize: 13),
                        decoration: const InputDecoration(
                          hintText: '이미지 URL 직접 입력',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        if (urlCtrl.text.trim().isNotEmpty) {
                          setS(() {
                            setState(() => _introImages.add(urlCtrl.text.trim()));
                          });
                          urlCtrl.clear();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      child: const Text('추가'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('완료 (${_introImages.length}장)'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.neonGreen : AppColors.navy;
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final sub = isDark ? const Color(0xFF8E8E8E) : const Color(0xFF737373);
    final divColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE);
    final fishList = _fishCategory == '민물' ? _freshFish : _saltFish;
    final dateText = _dateRange == null
        ? null
        : '${_dateRange!.start.year}.${_dateRange!.start.month.toString().padLeft(2, '0')}.${_dateRange!.start.day.toString().padLeft(2, '0')}  ~  ${_dateRange!.end.year}.${_dateRange!.end.month.toString().padLeft(2, '0')}.${_dateRange!.end.day.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('리그 개설', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _creating ? null : _createLeague,
              child: _creating
                  ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: accent))
                  : Text('개설', style: TextStyle(color: accent, fontWeight: FontWeight.w800, fontSize: 15)),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 60),
          children: [

            // ── 대회명 ──
            _Section(
              title: '대회명',
              accent: accent,
              child: TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(hintText: '예) 2026 충주호 배스 오픈'),
                validator: (v) => v?.isEmpty == true ? '대회명을 입력해주세요' : null,
              ),
            ),

            // ── 일정 ──
            _Section(
              title: '일정',
              accent: accent,
              child: GestureDetector(
                onTap: _pickDateRange,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF8F8F8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _dateRange != null ? accent : divColor,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_month_rounded,
                          color: _dateRange != null ? accent : sub, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          dateText ?? '날짜 범위를 선택하세요',
                          style: TextStyle(
                            fontSize: 14,
                            color: _dateRange != null
                                ? (isDark ? Colors.white : Colors.black)
                                : sub,
                            fontWeight: _dateRange != null ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (_dateRange != null)
                        GestureDetector(
                          onTap: () => setState(() => _dateRange = null),
                          child: Icon(Icons.close_rounded, size: 16, color: sub),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // ── 장소 ──
            _Section(
              title: '장소',
              accent: accent,
              child: Column(
                children: [
                  TextFormField(
                    controller: _locationCtrl,
                    decoration: InputDecoration(
                      hintText: '지도에서 선택하거나 직접 입력',
                      suffixIcon: IconButton(
                        onPressed: _openMapPicker,
                        icon: Icon(Icons.map_outlined, color: accent, size: 22),
                        tooltip: '지도에서 선택',
                      ),
                    ),
                  ),
                  if (_selectedLatLng != null) ...[
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: _openMapPicker,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          height: 140,
                          child: FlutterMap(
                            options: MapOptions(
                              initialCenter: _selectedLatLng!,
                              initialZoom: 12,
                              interactionOptions: const InteractionOptions(
                                flags: InteractiveFlag.none,
                              ),
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.huk.app',
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: _selectedLatLng!,
                                    width: 36,
                                    height: 36,
                                    child: Icon(Icons.location_pin, color: accent, size: 36),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── 어종 ──
            _Section(
              title: '대상 어종',
              accent: accent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 대분류 탭
                  Row(
                    children: ['민물', '바다'].map((cat) {
                      final sel = _fishCategory == cat;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _fishCategory = cat;
                          _selectedFish.clear();
                        }),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                          decoration: BoxDecoration(
                            color: sel ? accent : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: sel ? accent : divColor),
                          ),
                          child: Text(
                            cat,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: sel ? (isDark ? Colors.black : Colors.white) : sub,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  // 소분류 어종
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: fishList.map((fish) {
                      final sel = _selectedFish.contains(fish);
                      return GestureDetector(
                        onTap: () => setState(() {
                          if (sel) {
                            _selectedFish.remove(fish);
                          } else {
                            _selectedFish.add(fish);
                          }
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: sel ? accent.withValues(alpha: 0.15) : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: sel ? accent : divColor,
                            ),
                          ),
                          child: Text(
                            fish,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                              color: sel ? accent : sub,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  if (_selectedFish.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '선택됨: ${_selectedFish.join(', ')}',
                      style: TextStyle(fontSize: 12, color: accent, fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),

            // ── 순위 결정 방식 ──
            _Section(
              title: '순위 결정 방식',
              accent: accent,
              child: Wrap(
                spacing: 8, runSpacing: 8,
                children: _rules.map((rule) {
                  final sel = _rule == rule;
                  return GestureDetector(
                    onTap: () => setState(() => _rule = rule),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? accent.withValues(alpha: 0.15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: sel ? accent : divColor),
                      ),
                      child: Text(
                        rule,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                          color: sel ? accent : sub,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // ── 최대 참가자 + 참가비 ──
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _Section(
                      title: '최대 참가자',
                      accent: accent,
                      bottomPad: 0,
                      child: TextFormField(
                        controller: _maxCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(hintText: '0', suffixText: '명'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _Section(
                      title: '참가비',
                      accent: accent,
                      bottomPad: 0,
                      child: TextFormField(
                        controller: _feeCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(hintText: '0', suffixText: '원'),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── 상금/상품/기타 ──
            _Section(
              title: '시상',
              accent: accent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 타입 선택
                  Row(
                    children: ['상금', '상품', '기타'].map((t) {
                      final sel = _prizeType == t;
                      return GestureDetector(
                        onTap: () => setState(() => _prizeType = t),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                          decoration: BoxDecoration(
                            color: sel ? accent : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: sel ? accent : divColor),
                          ),
                          child: Text(
                            t,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: sel ? (isDark ? Colors.black : Colors.white) : sub,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),

                  // 상금
                  if (_prizeType == '상금') ...[
                    ..._prizes.asMap().entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 36,
                            child: Text(
                              e.value.rank,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: e.key == 0
                                    ? AppColors.gold
                                    : e.key == 1
                                        ? AppColors.silver
                                        : AppColors.bronze,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              style: const TextStyle(fontSize: 14),
                              decoration: const InputDecoration(
                                hintText: '0',
                                suffixText: '원',
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                isDense: true,
                              ),
                              onChanged: (v) => _prizes[e.key].value = v,
                            ),
                          ),
                        ],
                      ),
                    )),
                    // 추가 버튼
                    TextButton.icon(
                      onPressed: () => setState(() => _prizes.add(
                        _PrizeItem(rank: '${_prizes.length + 1}위', value: ''),
                      )),
                      icon: Icon(Icons.add_circle_outline, size: 18, color: accent),
                      label: Text('순위 추가', style: TextStyle(color: accent, fontSize: 13)),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    ),
                  ],

                  // 상품
                  if (_prizeType == '상품') ...[
                    ..._prizes.asMap().entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 36,
                            child: Text(e.value.rank,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: e.key == 0
                                      ? AppColors.gold
                                      : e.key == 1
                                          ? AppColors.silver
                                          : e.key == 2
                                              ? AppColors.bronze
                                              : sub,
                                )),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              style: const TextStyle(fontSize: 14),
                              decoration: const InputDecoration(
                                hintText: '예) 낚시 릴 세트, 루어 박스',
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                isDense: true,
                              ),
                              onChanged: (v) => _prizes[e.key].value = v,
                            ),
                          ),
                        ],
                      ),
                    )),
                    TextButton.icon(
                      onPressed: () => setState(() => _prizes.add(
                        _PrizeItem(rank: '${_prizes.length + 1}위', value: ''),
                      )),
                      icon: Icon(Icons.add_circle_outline, size: 18, color: accent),
                      label: Text('순위 추가', style: TextStyle(color: accent, fontSize: 13)),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    ),
                  ],

                  // 기타
                  if (_prizeType == '기타')
                    TextField(
                      controller: _etcPrizeCtrl,
                      maxLines: 3,
                      style: const TextStyle(fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: '시상 내용을 자유롭게 입력하세요\n예) 참가자 전원 기념품 증정',
                        alignLabelWithHint: true,
                      ),
                    ),
                ],
              ),
            ),

            // ── 대회 소개 ──
            _Section(
              title: '대회 소개',
              accent: accent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _introCtrl,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      hintText: '대회 규정, 유의사항, 참가 방법 등을 입력하세요',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 이미지 추가 버튼
                  GestureDetector(
                    onTap: _openImagePopup,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: divColor),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined, size: 20, color: accent),
                          const SizedBox(width: 8),
                          Text(
                            _introImages.isEmpty
                                ? '소개 이미지 추가'
                                : '이미지 ${_introImages.length}장 추가됨',
                            style: TextStyle(
                              fontSize: 13,
                              color: _introImages.isEmpty ? sub : accent,
                              fontWeight: _introImages.isEmpty ? FontWeight.w400 : FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 이미지 미리보기
                  if (_introImages.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _introImages.length,
                        itemBuilder: (_, i) => Stack(
                          children: [
                            Container(
                              width: 80, height: 80,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: divColor),
                              ),
                              child: Center(
                                child: AppSvg(AppIcons.fish, size: 36,
                                    color: isDark ? const Color(0xFF444444) : const Color(0xFFCCCCCC)),
                              ),
                            ),
                            Positioned(
                              top: 2, right: 10,
                              child: GestureDetector(
                                onTap: () => setState(() => _introImages.removeAt(i)),
                                child: Container(
                                  width: 18, height: 18,
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, size: 12, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── 공개 설정 ──
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: divColor),
              ),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('공개 리그', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  _isPublic ? '누구나 참가 신청 가능' : '초대 링크로만 참가 가능',
                  style: TextStyle(fontSize: 12, color: sub),
                ),
                value: _isPublic,
                activeColor: accent,
                onChanged: (v) => setState(() => _isPublic = v),
              ),
            ),

            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _creating ? null : _createLeague,
                child: _creating
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Text('리그 개설하기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 섹션 래퍼 ──
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.accent,
    required this.child,
    this.bottomPad = 20,
  });
  final String title;
  final Color accent;
  final Widget child;
  final double bottomPad;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

// ── 이미지 추가 버튼 ──
class _ImgBtn extends StatelessWidget {
  const _ImgBtn({required this.icon, required this.label, required this.accent, required this.isDark, required this.onTap});
  final IconData icon;
  final String label;
  final Color accent;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accent.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: accent),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 13, color: accent, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ── 시상 항목 모델 ──
class _PrizeItem {
  _PrizeItem({required this.rank, required this.value});
  final String rank;
  String value;
}
