import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/address_utils.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../auth/data/auth_repository.dart';
import '../../data/league_model.dart';
import '../../data/league_repository.dart';
import 'league_detail_screen.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/extensions/theme_extensions.dart';

class LeagueCreateScreen extends ConsumerStatefulWidget {
  const LeagueCreateScreen({super.key, this.league});

  /// null이면 생성 모드, non-null이면 편집 모드
  final League? league;

  @override
  ConsumerState<LeagueCreateScreen> createState() => _LeagueCreateScreenState();
}

class _LeagueCreateScreenState extends ConsumerState<LeagueCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _maxCtrl = TextEditingController();
  final _feeCtrl = TextEditingController();
  final _shortDescCtrl = TextEditingController();
  final _introCtrl = TextEditingController();

  DateTimeRange? _dateRange;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  String _rule = '최대어';
  int _catchLimit = 1; // 0=전체, 1,3,5,10
  bool _isPublic = true;
  bool _allowGallery = true;

  // 장소 좌표
  LatLng? _selectedLatLng;

  // 상금/상품
  String _prizeType = '기타';
  final List<_PrizeItem> _prizes = [
    _PrizeItem(rank: '1위', value: ''),
    _PrizeItem(rank: '2위', value: ''),
    _PrizeItem(rank: '3위', value: ''),
  ];
  final _etcPrizeCtrl = TextEditingController();

  // 소개 이미지 (편집 모드: 기존 URL + 새 파일)
  final List<String> _existingImageUrls = [];
  final List<XFile> _newImageFiles = [];
  final _imagePicker = ImagePicker();

  bool _submitting = false;
  bool _showDateError = false;

  // 필수 항목 스크롤 앵커
  final _nameKey = GlobalKey();
  final _dateKey = GlobalKey();
  final _locationKey = GlobalKey();
  final _maxKey = GlobalKey();

  bool get _isEditMode => widget.league != null;

  static const _rules = ['최대어', '합산 길이', '마릿수', '무게'];

  @override
  void initState() {
    super.initState();
    final l = widget.league;
    if (l != null) {
      _nameCtrl.text = l.title;
      _locationCtrl.text = l.location;
      _maxCtrl.text = l.maxParticipants.toString();
      _feeCtrl.text = l.entryFee.toString();
      _shortDescCtrl.text = l.shortDescription ?? '';
      _introCtrl.text = l.description ?? '';
      _dateRange = DateTimeRange(start: l.startTime, end: l.endTime);
      if (l.startTime.hour != 0 || l.startTime.minute != 0) {
        _startTime = TimeOfDay(hour: l.startTime.hour, minute: l.startTime.minute);
      }
      if (l.endTime.hour != 0 || l.endTime.minute != 0) {
        _endTime = TimeOfDay(hour: l.endTime.hour, minute: l.endTime.minute);
      }
      _rule = l.rule;
      _catchLimit = l.catchLimit;
      _isPublic = l.isPublic;
      _allowGallery = l.allowGallery;
      if (l.lat != null && l.lng != null) {
        _selectedLatLng = LatLng(l.lat!, l.lng!);
      }
      // prizeInfo는 기타 텍스트 필드로 표시
      _prizeType = '기타';
      _etcPrizeCtrl.text = l.prizeInfo ?? '';
      _existingImageUrls.addAll(l.introImageUrls);
    } else {
      // 생성 모드 기본값
      _prizeType = '상금';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _locationCtrl.dispose();
    _maxCtrl.dispose();
    _feeCtrl.dispose();
    _shortDescCtrl.dispose();
    _introCtrl.dispose();
    _etcPrizeCtrl.dispose();
    super.dispose();
  }

  // ── 첫 번째 미입력 필수 항목으로 스크롤 ──
  Future<void> _scrollToFirstError({required bool dateValid}) async {
    GlobalKey? firstKey;
    if (_nameCtrl.text.trim().isEmpty) {
      firstKey = _nameKey;
    } else if (!dateValid) {
      firstKey = _dateKey;
    } else if (_locationCtrl.text.trim().isEmpty) {
      firstKey = _locationKey;
    } else {
      final m = _maxCtrl.text.trim();
      if (m.isEmpty || int.tryParse(m) == null || (int.tryParse(m) ?? 0) < 1) {
        firstKey = _maxKey;
      }
    }
    final ctx = firstKey?.currentContext;
    if (ctx != null) {
      await Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: 0.1,
      );
    }
  }

  // ── 개설 / 수정 공통 제출 ──
  Future<void> _submit() async {
    setState(() => _showDateError = false);

    final formValid = _formKey.currentState?.validate() ?? false;
    final dateValid = _dateRange != null;
    if (!dateValid) setState(() => _showDateError = true);

    if (!formValid || !dateValid) {
      await _scrollToFirstError(dateValid: dateValid);
      return;
    }

    setState(() => _submitting = true);
    try {
      if (_isEditMode) {
        await ref.read(leagueRepositoryProvider).updateLeague(
          id: widget.league!.id,
          title: _nameCtrl.text.trim(),
          description: _introCtrl.text.trim().isEmpty ? null : _introCtrl.text.trim(),
          shortDescription: _shortDescCtrl.text.trim().isEmpty ? null : _shortDescCtrl.text.trim(),
          clearShortDescription: _shortDescCtrl.text.trim().isEmpty,
          location: _locationCtrl.text.trim(),
          lat: _selectedLatLng?.latitude,
          lng: _selectedLatLng?.longitude,
          startTime: _applyTime(_dateRange!.start, _startTime),
          endTime: _applyTime(_dateRange!.end, _endTime),
          entryFee: int.tryParse(_feeCtrl.text) ?? widget.league!.entryFee,
          maxParticipants: int.tryParse(_maxCtrl.text) ?? widget.league!.maxParticipants,
          rule: _rule,
          catchLimit: _catchLimit,
          prizeInfo: _buildPrizeInfo(),
          isPublic: _isPublic,
          allowGallery: _allowGallery,
          newImageFiles: _newImageFiles,
          existingImageUrls: _existingImageUrls,
          hostId: widget.league!.hostId,
        );
        ref.invalidate(leagueDetailProvider(widget.league!.id));
        ref.invalidate(leaguesProvider);
        if (mounted) {
                    AppSnackBar.success(context, '대회 정보가 수정되었습니다.');
          context.pop();
        }
      } else {
        final user = ref.read(currentUserProvider);
        if (user == null) {
          setState(() => _submitting = false);
                    AppSnackBar.warning(context, '로그인이 필요합니다.');
          return;
        }
        await ref.read(leagueRepositoryProvider).createLeague(
          hostId: user.id,
          title: _nameCtrl.text.trim(),
          description: _introCtrl.text.trim().isEmpty ? null : _introCtrl.text.trim(),
          shortDescription: _shortDescCtrl.text.trim().isEmpty ? null : _shortDescCtrl.text.trim(),
          location: _locationCtrl.text.trim(),
          lat: _selectedLatLng?.latitude,
          lng: _selectedLatLng?.longitude,
          startTime: _applyTime(_dateRange!.start, _startTime),
          endTime: _applyTime(_dateRange!.end, _endTime),
          entryFee: int.tryParse(_feeCtrl.text) ?? 0,
          maxParticipants: int.parse(_maxCtrl.text),
          fishTypes: '배스',
          rule: _rule,
          catchLimit: _catchLimit,
          prizeInfo: _buildPrizeInfo(),
          isPublic: _isPublic,
          allowGallery: _allowGallery,
          introImageFiles: _newImageFiles,
        );
        ref.invalidate(leaguesProvider);
        if (mounted) context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
                AppSnackBar.error(context, _isEditMode ? '수정 실패: $e' : '개설 실패: $e');
      }
    }
  }

  // ── 룰 미리보기 텍스트 ──
  String get _rulePreview {
    if (_rule == '마릿수') return '마릿수 기준으로 순위를 결정합니다';
    final limitStr = _catchLimit == 0 ? '전체' : '$_catchLimit마리';
    switch (_rule) {
      case '최대어': return '상위 $limitStr 중 가장 큰 물고기 기준';
      case '합산 길이': return '상위 $limitStr 길이(cm) 합산 기준';
      case '무게': return '상위 $limitStr 무게(g) 합산 기준';
      default: return '$limitStr $_rule 기준';
    }
  }

  // ── catch_limit 칩 ──
  Widget _buildLimitChip(int limit, String label, Color accent, Color divColor, Color sub, bool isDark) {
    final sel = _catchLimit == limit;
    return GestureDetector(
      onTap: () => setState(() => _catchLimit = limit),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? context.accentColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? context.accentColor : divColor),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
            color: sel ? (isDark ? Colors.black : Colors.white) : sub,
          ),
        ),
      ),
    );
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

  // ── 날짜+시간 조합 ──
  DateTime _applyTime(DateTime date, TimeOfDay? time) {
    if (time == null) return date;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
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
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: context.isDark
                ? ColorScheme.dark(primary: context.accentColor, onPrimary: Colors.black)
                : ColorScheme.light(primary: context.accentColor, onPrimary: Colors.white),
          ),
          child: child!,
        );
      },
    );
    if (result != null) setState(() => _dateRange = result);
  }

  // ── 시간 선택 ──
  Future<void> _pickStartTime() async {
    final result = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay.now(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (result != null) setState(() => _startTime = result);
  }

  Future<void> _pickEndTime() async {
    final result = await showTimePicker(
      context: context,
      initialTime: _endTime ?? TimeOfDay.now(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (result != null) setState(() => _endTime = result);
  }

  // ── 지도 선택 팝업 ──
  Future<void> _openMapPicker() async {
    LatLng pinned = _selectedLatLng ?? const LatLng(36.8, 127.9);
    bool loading = false;
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
                                  child: Icon(Icons.location_pin, color: context.accentColor, size: 40),
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
                                style: TextStyle(color: context.accentColor, fontSize: 12, fontWeight: FontWeight.w700),
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
                      onPressed: loading ? null : () async {
                        setS(() => loading = true);
                        String address;
                        try {
                          final placemarks = await placemarkFromCoordinates(
                            pinned.latitude, pinned.longitude,
                          );
                          if (placemarks.isNotEmpty) {
                            final p = placemarks.first;
                            final rawParts = [p.administrativeArea, p.locality, p.subLocality, p.thoroughfare]
                                .where((s) => s != null && s.isNotEmpty)
                                .toList();
                            final parts = <String>[];
                            for (final part in rawParts) {
                              if (parts.isEmpty || parts.last != part) parts.add(part!);
                            }
                            address = parts.isNotEmpty
                                ? parts.join(' ')
                                : '${pinned.latitude.toStringAsFixed(4)}, ${pinned.longitude.toStringAsFixed(4)}';
                          } else {
                            address = '${pinned.latitude.toStringAsFixed(4)}, ${pinned.longitude.toStringAsFixed(4)}';
                          }
                        } catch (_) {
                          address = '${pinned.latitude.toStringAsFixed(4)}, ${pinned.longitude.toStringAsFixed(4)}';
                        }
                        setState(() {
                          _selectedLatLng = pinned;
                          _locationCtrl.text = dedupeAddress(address);
                        });
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: loading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('이 위치로 선택'),
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

  int get _totalImageCount => _existingImageUrls.length + _newImageFiles.length;

  Future<void> _pickImage(ImageSource source, void Function(void Function()) setS) async {
    final file = await _imagePicker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (file == null) return;
    setS(() => setState(() => _newImageFiles.add(file)));
  }

  Future<void> _pickMultipleImages(void Function(void Function()) setS) async {
    final files = await _imagePicker.pickMultiImage(
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (files.isEmpty) return;
    setS(() => setState(() => _newImageFiles.addAll(files)));
  }

  // ── 소개 이미지 팝업 ──
  Future<void> _openImagePopup() async {
    final divColor = context.isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE);

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) {
          final totalCount = _existingImageUrls.length + _newImageFiles.length;
          return Dialog(
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
                  if (totalCount > 0) ...[
                    SizedBox(
                      height: 90,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          // 기존 URL 이미지 (편집 모드)
                          ..._existingImageUrls.asMap().entries.map((e) => Stack(
                            children: [
                              Container(
                                width: 80, height: 80,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: divColor),
                                  image: DecorationImage(
                                    image: NetworkImage(e.value),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 2, right: 10,
                                child: GestureDetector(
                                  onTap: () => setS(() {
                                    setState(() => _existingImageUrls.removeAt(e.key));
                                  }),
                                  child: Container(
                                    width: 20, height: 20,
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close, size: 13, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          )),
                          // 새로 선택한 파일 이미지
                          ..._newImageFiles.asMap().entries.map((e) => Stack(
                            children: [
                              Container(
                                width: 80, height: 80,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: context.accentColor.withValues(alpha: 0.4)),
                                  image: DecorationImage(
                                    image: FileImage(File(e.value.path)),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 2, right: 10,
                                child: GestureDetector(
                                  onTap: () => setS(() {
                                    setState(() => _newImageFiles.removeAt(e.key));
                                  }),
                                  child: Container(
                                    width: 20, height: 20,
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close, size: 13, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          )),
                        ],
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
                          accent: context.accentColor,
                          isDark: context.isDark,
                          onTap: () => _pickImage(ImageSource.camera, setS),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ImgBtn(
                          icon: Icons.photo_library_outlined,
                          label: '갤러리 (복수)',
                          accent: context.accentColor,
                          isDark: context.isDark,
                          onTap: () => _pickMultipleImages(setS),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AppButton(
                    label: '완료 ($totalCount장)',
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = context.isDark ? AppColors.darkSurface : Colors.white;
    final sub = context.isDark ? const Color(0xFF8E8E8E) : const Color(0xFF737373);
    final divColor = context.isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE);
    final dateText = _dateRange == null
        ? null
        : '${_dateRange!.start.year}.${_dateRange!.start.month.toString().padLeft(2, '0')}.${_dateRange!.start.day.toString().padLeft(2, '0')}  ~  ${_dateRange!.end.year}.${_dateRange!.end.month.toString().padLeft(2, '0')}.${_dateRange!.end.day.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditMode ? '리그 수정' : '리그 개설',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft, size: 24),
          onPressed: () => context.pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.accentColor,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 0,
              ),
              child: _submitting
                  ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : Text(
                      _isEditMode ? '저장' : '개설',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
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
            Padding(
              key: _nameKey,
              padding: const EdgeInsets.only(bottom: 20),
              child: TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: '대회명',
                  labelStyle: TextStyle(color: context.accentColor, fontWeight: FontWeight.w600),
                  hintText: '예) 2026 충주호 배스 오픈',
                  hintStyle: TextStyle(color: sub, fontSize: 14),
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: divColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.accentColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.accentColor, width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.error),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.error, width: 2),
                  ),
                  filled: true,
                  fillColor: context.isDark ? const Color(0xFF111111) : Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                validator: (v) => v?.isEmpty == true ? '대회명을 입력해주세요' : null,
              ),
            ),

            // ── 일정 ──
            Column(
              key: _dateKey,
              mainAxisSize: MainAxisSize.min,
              children: [
            _Section(
              title: '일정',
              accent: context.accentColor,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                GestureDetector(
                onTap: () {
                  setState(() => _showDateError = false);
                  _pickDateRange();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: context.isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF8F8F8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _showDateError
                          ? AppColors.error
                          : (_dateRange != null ? context.accentColor : divColor),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_month_rounded,
                          color: _dateRange != null ? context.accentColor : sub, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          dateText ?? '날짜 범위를 선택하세요',
                          style: TextStyle(
                            fontSize: 14,
                            color: _dateRange != null
                                ? (context.isDark ? Colors.white : Colors.black)
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
                if (_showDateError)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 12),
                    child: Text(
                      '일정을 선택해주세요',
                      style: TextStyle(fontSize: 12, color: AppColors.error),
                    ),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _pickStartTime,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                          decoration: BoxDecoration(
                            color: context.isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF8F8F8),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _startTime != null ? context.accentColor : divColor,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(LucideIcons.clock, size: 14,
                                  color: _startTime != null ? context.accentColor : sub),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _startTime != null
                                      ? '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}'
                                      : '시작 시간',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _startTime != null
                                        ? (context.isDark ? Colors.white : Colors.black)
                                        : sub,
                                    fontWeight: _startTime != null ? FontWeight.w600 : FontWeight.w400,
                                  ),
                                ),
                              ),
                              if (_startTime != null)
                                GestureDetector(
                                  onTap: () => setState(() => _startTime = null),
                                  child: Icon(Icons.close_rounded, size: 14, color: sub),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: _pickEndTime,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                          decoration: BoxDecoration(
                            color: context.isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF8F8F8),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _endTime != null ? context.accentColor : divColor,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(LucideIcons.clock, size: 14,
                                  color: _endTime != null ? context.accentColor : sub),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _endTime != null
                                      ? '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}'
                                      : '종료 시간',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _endTime != null
                                        ? (context.isDark ? Colors.white : Colors.black)
                                        : sub,
                                    fontWeight: _endTime != null ? FontWeight.w600 : FontWeight.w400,
                                  ),
                                ),
                              ),
                              if (_endTime != null)
                                GestureDetector(
                                  onTap: () => setState(() => _endTime = null),
                                  child: Icon(Icons.close_rounded, size: 14, color: sub),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                ],
              ),
            ),
              ],
            ),

            // ── 장소 ──
            Column(
              key: _locationKey,
              mainAxisSize: MainAxisSize.min,
              children: [
            _Section(
              title: '장소',
              accent: context.accentColor,
              child: Column(
                children: [
                  TextFormField(
                    controller: _locationCtrl,
                    decoration: InputDecoration(
                      hintText: '지도에서 선택하거나 직접 입력',
                      suffixIcon: IconButton(
                        onPressed: _openMapPicker,
                        icon: Icon(Icons.map_outlined, color: context.accentColor, size: 22),
                        tooltip: '지도에서 선택',
                      ),
                    ),
                    validator: (v) => v?.trim().isEmpty == true ? '장소를 입력해주세요' : null,
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
                                    child: Icon(Icons.location_pin, color: context.accentColor, size: 36),
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
              ],
            ),

            // ── 순위 결정 방식 ──
            _Section(
              title: '순위 결정 방식',
              accent: context.accentColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Step 1: 기본 방식
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _rules.map((rule) {
                      final sel = _rule == rule;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _rule = rule;
                          // 마릿수는 catchLimit 의미 없음
                          if (rule == '마릿수') _catchLimit = 0;
                          else if (_catchLimit == 0) _catchLimit = 1;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: sel ? context.accentColor : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: sel ? context.accentColor : divColor),
                          ),
                          child: Text(
                            rule,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                              color: sel ? (context.isDark ? Colors.black : Colors.white) : sub,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  // Step 2: 마릿수 제한 (마릿수 룰 제외)
                  if (_rule != '마릿수') ...[
                    const SizedBox(height: 14),
                    Text('몇 마리 기준으로 점수를 계산하나요?',
                        style: TextStyle(fontSize: 12, color: sub)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: [
                        _buildLimitChip(1, '1마리', context.accentColor, divColor, sub, context.isDark),
                        _buildLimitChip(3, '3마리', context.accentColor, divColor, sub, context.isDark),
                        _buildLimitChip(5, '5마리', context.accentColor, divColor, sub, context.isDark),
                        _buildLimitChip(10, '10마리', context.accentColor, divColor, sub, context.isDark),
                        _buildLimitChip(0, '전체', context.accentColor, divColor, sub, context.isDark),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 현재 설정 미리보기
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: context.accentColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: context.accentColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(children: [
                        Icon(Icons.info_outline_rounded, size: 14, color: context.accentColor),
                        const SizedBox(width: 6),
                        Text(
                          _rulePreview,
                          style: TextStyle(fontSize: 12, color: context.accentColor, fontWeight: FontWeight.w600),
                        ),
                      ]),
                    ),
                  ],
                ],
              ),
            ),

            // ── 최대 참가자 + 참가비 ──
            Padding(
              key: _maxKey,
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _Section(
                      title: '최대 참가자',
                      accent: context.accentColor,
                      bottomPad: 0,
                      child: TextFormField(
                        controller: _maxCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(hintText: '0', suffixText: '명'),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return '참가 인원을 입력해주세요';
                          final n = int.tryParse(v);
                          if (n == null || n < 1) return '1명 이상 입력해주세요';
                          return null;
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _Section(
                      title: '참가비',
                      accent: context.accentColor,
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
              accent: context.accentColor,
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
                            color: sel ? context.accentColor : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: sel ? context.accentColor : divColor),
                          ),
                          child: Text(
                            t,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: sel ? (context.isDark ? Colors.black : Colors.white) : sub,
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
                      icon: Icon(Icons.add_circle_outline, size: 18, color: context.accentColor),
                      label: Text('순위 추가', style: TextStyle(color: context.accentColor, fontSize: 13)),
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
                      icon: Icon(Icons.add_circle_outline, size: 18, color: context.accentColor),
                      label: Text('순위 추가', style: TextStyle(color: context.accentColor, fontSize: 13)),
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

            // ── 간단 소개 ──
            _Section(
              title: '간단 소개',
              accent: context.accentColor,
              child: TextFormField(
                controller: _shortDescCtrl,
                maxLength: 40,
                maxLines: 1,
                decoration: const InputDecoration(
                  hintText: '한 줄로 대회를 소개해주세요',
                  counterText: '',
                ),
              ),
            ),

            // ── 대회 소개 ──
            _Section(
              title: '대회 소개',
              accent: context.accentColor,
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
                        color: context.isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: divColor),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined, size: 20, color: context.accentColor),
                          const SizedBox(width: 8),
                          Text(
                            _totalImageCount == 0
                                ? '소개 이미지 추가'
                                : '이미지 $_totalImageCount장 추가됨',
                            style: TextStyle(
                              fontSize: 13,
                              color: _totalImageCount == 0 ? sub : context.accentColor,
                              fontWeight: _totalImageCount == 0 ? FontWeight.w400 : FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 이미지 미리보기
                  if (_totalImageCount > 0) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 80,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          ..._existingImageUrls.map((url) => Container(
                            width: 80, height: 80,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: divColor),
                              image: DecorationImage(
                                image: NetworkImage(url),
                                fit: BoxFit.cover,
                              ),
                            ),
                          )),
                          ..._newImageFiles.map((f) => Container(
                            width: 80, height: 80,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: context.accentColor.withValues(alpha: 0.4)),
                              image: DecorationImage(
                                image: FileImage(File(f.path)),
                                fit: BoxFit.cover,
                              ),
                            ),
                          )),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── 공개 설정 + 앨범 허용 ──
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: AppCard(
                padding: EdgeInsets.zero,
                radius: 12,
                borderColor: divColor,
                child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    title: Text(
                      _isPublic ? '공개 리그' : '비공개 리그',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      _isPublic ? '누구나 참가 신청 가능' : '초대 링크로만 참가 가능',
                      style: TextStyle(fontSize: 12, color: sub),
                    ),
                    value: _isPublic,
                    activeColor: context.accentColor,
                    onChanged: (v) => setState(() => _isPublic = v),
                  ),
                  Divider(height: 1, color: divColor),
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    title: Text(
                      _allowGallery ? '갤러리 사용 허용' : '갤러리 사용 불가',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      _allowGallery ? '참가자가 앨범 사진으로 조과 등록 가능' : '카메라 촬영만 조과 등록 가능',
                      style: TextStyle(fontSize: 12, color: sub),
                    ),
                    value: _allowGallery,
                    activeColor: context.accentColor,
                    onChanged: (v) => setState(() => _allowGallery = v),
                  ),
                ],
                ),
              ),
            ),

            AppButton(
              label: _isEditMode ? '수정 완료' : '리그 개설하기',
              onPressed: _submitting ? null : _submit,
              loading: _submitting,
              size: AppButtonSize.lg,
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
