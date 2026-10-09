import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/extensions/theme_extensions.dart';
import '../../../../core/services/location_consent_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/banned_error_handler.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/section_label.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../feed/data/feed_repository.dart';
import '../../../profile/data/profile_repository.dart';
import '../../../ranking/data/score_cache_invalidation.dart';

/// 앨범에서 고른 여러 장을 개인 기록으로 한 번에 등록한다.
///
/// 개인 기록은 사진 1장 = 글 1건 = 점수 1건이므로 길이는 사진마다 받고,
/// 같은 출조로 보고 위치·메모는 전체에 공통 적용한다.
/// 길이를 적지 않은 사진은 등록에서 제외한다.
class PersonalCatchBatchScreen extends ConsumerStatefulWidget {
  const PersonalCatchBatchScreen({super.key, required this.images});

  final List<File> images;

  @override
  ConsumerState<PersonalCatchBatchScreen> createState() =>
      _PersonalCatchBatchScreenState();
}

class _CatchEntry {
  _CatchEntry(this.file);

  final File file;
  final TextEditingController lengthCtrl = TextEditingController();

  double? get length => double.tryParse(lengthCtrl.text.trim());
  bool get isReady => (length ?? 0) > 0;

  void dispose() => lengthCtrl.dispose();
}

class _PersonalCatchBatchScreenState
    extends ConsumerState<PersonalCatchBatchScreen> {
  late final List<_CatchEntry> _entries;
  final _locationCtrl = TextEditingController();
  final _captionCtrl = TextEditingController();

  double? _capturedLat;
  double? _capturedLng;
  bool _fetchingLocation = false;

  bool _submitting = false;
  int _doneCount = 0;

  @override
  void initState() {
    super.initState();
    _entries = widget.images.map(_CatchEntry.new).toList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _captureCurrentLocation();
    });
  }

  @override
  void dispose() {
    for (final e in _entries) {
      e.dispose();
    }
    _locationCtrl.dispose();
    _captionCtrl.dispose();
    super.dispose();
  }

  int get _readyCount => _entries.where((e) => e.isReady).length;

  Future<void> _captureCurrentLocation() async {
    if (_fetchingLocation) return;
    // 위치정보법: 시스템 권한과 별개로 앱 차원의 명시적 동의 필요 (1회)
    final agreed = await LocationConsentService.ensureAgreed(context);
    if (!agreed) return;
    setState(() => _fetchingLocation = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) AppSnackBar.warning(context, '위치 서비스를 켜주세요');
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (mounted) AppSnackBar.warning(context, '위치 권한이 거부되었습니다');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      _capturedLat = pos.latitude;
      _capturedLng = pos.longitude;
      if (_locationCtrl.text.trim().isEmpty) {
        try {
          final placemarks =
              await placemarkFromCoordinates(pos.latitude, pos.longitude);
          if (placemarks.isNotEmpty) {
            final p = placemarks.first;
            final rawParts = [
              p.administrativeArea,
              p.locality,
              p.subLocality,
              p.thoroughfare
            ].where((s) => s != null && s.isNotEmpty).toList();
            final parts = <String>[];
            for (final part in rawParts) {
              if (parts.isEmpty || parts.last != part) parts.add(part!);
            }
            if (parts.isNotEmpty) _locationCtrl.text = parts.join(' ');
          }
        } catch (_) {}
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) AppSnackBar.error(context, '위치 가져오기 실패: $e');
    } finally {
      if (mounted) setState(() => _fetchingLocation = false);
    }
  }

  void _remove(_CatchEntry entry) {
    setState(() {
      _entries.remove(entry);
    });
    entry.dispose();
    if (_entries.isEmpty && mounted) Navigator.pop(context);
  }

  Future<void> _submit() async {
    final targets = _entries.where((e) => e.isReady).toList();
    if (targets.isEmpty) {
      AppSnackBar.warning(context, '길이를 입력한 사진이 없습니다');
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final location =
        _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim();
    final caption =
        _captionCtrl.text.trim().isEmpty ? null : _captionCtrl.text.trim();

    setState(() {
      _submitting = true;
      _doneCount = 0;
    });

    var success = 0;
    var duplicated = 0;
    final failures = <String>[];

    // 순차 처리 — 동시 업로드는 네트워크가 불안정한 현장에서 실패율이 높다.
    for (final entry in targets) {
      try {
        await ref.read(feedRepositoryProvider).createPost(
              userId: user.id,
              imageFile: entry.file,
              imageMaxDimension: 1280, // 개인 조과: 1280 단일 인코딩
              fishType: '배스',
              length: entry.length,
              location: location,
              lat: _capturedLat,
              lng: _capturedLng,
              caption: caption,
              catchCount: 1,
              isPersonalRecord: true,
            );
        success++;
      } on DuplicateCatchPhotoException {
        duplicated++;
      } catch (e) {
        if (await handleIfBanned(e)) return;
        failures.add('$e');
      } finally {
        if (mounted) setState(() => _doneCount++);
      }
    }

    if (success > 0) {
      ref.invalidate(myPersonalRecordsProvider);
      invalidateScoreCaches(ref);
    }

    if (!mounted) return;
    setState(() => _submitting = false);

    final parts = <String>['조과 $success건이 기록되었습니다'];
    if (duplicated > 0) parts.add('$duplicated건은 이미 등록된 사진');
    if (failures.isNotEmpty) parts.add('${failures.length}건 실패');
    final message = parts.join(' · ');

    if (success > 0) {
      AppSnackBar.success(context, '$message 🎣');
      Navigator.pop(context, true);
    } else {
      AppSnackBar.error(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final accent = context.accentColor;
    final sub = isDark ? AppColors.darkTextSub : AppColors.lightTextSub;

    return Scaffold(
      appBar: AppBar(
        title: Text('조과 ${_entries.length}건 기록',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      ),
      body: AbsorbPointer(
        absorbing: _submitting,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Text(
              '사진을 탭하면 크게 볼 수 있습니다. 길이를 입력하지 않은 사진은 등록되지 않습니다.',
              style: TextStyle(fontSize: 13, color: sub),
            ),
            const SizedBox(height: 16),
            ..._entries.map((entry) => _EntryCard(
                  entry: entry,
                  accent: accent,
                  sub: sub,
                  onChanged: () => setState(() {}),
                  onRemove: _submitting ? null : () => _remove(entry),
                )),
            const SizedBox(height: 8),
            SectionLabel(text: '공통 정보', color: accent),
            const SizedBox(height: 8),
            AppTextField(
              controller: _locationCtrl,
              label: '위치',
              hint: '예) 대호만',
              suffixIcon: _fetchingLocation
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: Icon(LucideIcons.mapPin, size: 18, color: accent),
                      onPressed: _captureCurrentLocation,
                    ),
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _captionCtrl,
              label: '메모',
              hint: '모든 조과에 함께 기록됩니다',
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            AppButton(
              label: _submitting
                  ? '등록 중 $_doneCount/${_entries.where((e) => e.isReady).length}'
                  : '$_readyCount건 등록하기',
              loading: _submitting,
              onPressed: _readyCount == 0 || _submitting ? null : _submit,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.entry,
    required this.accent,
    required this.sub,
    required this.onChanged,
    required this.onRemove,
  });

  final _CatchEntry entry;
  final Color accent;
  final Color sub;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final ready = entry.isReady;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(10),
        radius: 14,
        borderColor: ready ? accent.withValues(alpha: 0.4) : null,
        child: Row(
          children: [
            // 길이를 적기 전에 사진을 확인해야 하므로 탭하면 크게 본다.
            GestureDetector(
              onTap: () => showDialog<void>(
                context: context,
                barrierColor: Colors.black,
                builder: (_) => _PhotoViewer(file: entry.file),
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      entry.file,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    right: 3,
                    bottom: 3,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(LucideIcons.maximize2,
                          size: 10, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                controller: entry.lengthCtrl,
                hint: '길이 입력',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                onChanged: (_) => onChanged(),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'cm',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: ready ? accent : sub,
              ),
            ),
            IconButton(
              onPressed: onRemove,
              icon: Icon(LucideIcons.x, size: 18, color: sub),
              tooltip: '목록에서 제외',
            ),
          ],
        ),
      ),
    );
  }
}

/// 등록 전 사진 확인용 전체화면 뷰어. 확대·축소와 탭으로 닫기를 지원한다.
class _PhotoViewer extends StatelessWidget {
  const _PhotoViewer({required this.file});

  final File file;

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: Center(child: Image.file(file, fit: BoxFit.contain)),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: SafeArea(
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(LucideIcons.x, color: Colors.white, size: 26),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
