import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/extensions/theme_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../data/slope_model.dart';
import '../../data/slopes_repository.dart';

/// 슬로프 지도: 전체 슬로프 마커 표시 + 확대/축소 탐색.
/// [focus]가 주어지면 해당 슬로프로 카메라 이동 후 선택 상태로 시작.
class SlopeMapScreen extends ConsumerStatefulWidget {
  const SlopeMapScreen({super.key, this.focus});

  final Slope? focus;

  @override
  ConsumerState<SlopeMapScreen> createState() => _SlopeMapScreenState();
}

class _SlopeMapScreenState extends ConsumerState<SlopeMapScreen> {
  NaverMapController? _controller;
  Slope? _selected;
  bool _satellite = true;

  @override
  void initState() {
    super.initState();
    _selected = widget.focus;
  }

  NCameraPosition get _initialCamera => widget.focus != null
      ? NCameraPosition(
          target: NLatLng(widget.focus!.lat!, widget.focus!.lng!), zoom: 15)
      // 전국 뷰 (대한민국 중심)
      : const NCameraPosition(target: NLatLng(36.3, 127.8), zoom: 6);

  Future<void> _addMarkers(NaverMapController controller) async {
    final accent = context.isDark ? AppColors.neonGreen : AppColors.navy;
    final slopes = await ref.read(slopesProvider.future);
    if (!mounted) return;
    final markers = <NClusterableMarker>{};
    for (final s in slopes) {
      if (s.lat == null || s.lng == null) continue;
      final marker = NClusterableMarker(
        id: s.id,
        position: NLatLng(s.lat!, s.lng!),
        caption: NOverlayCaption(text: s.displayName, textSize: 11),
        iconTintColor: accent,
      );
      marker.setOnTapListener((_) {
        setState(() => _selected = s);
        _controller?.updateCamera(
          NCameraUpdate.scrollAndZoomTo(target: NLatLng(s.lat!, s.lng!)),
        );
      });
      markers.add(marker);
    }
    // 마커 일괄 추가 (개별 addOverlay 반복 X → 배치 1회)
    await controller.addOverlayAll(markers);
  }

  /// 네이버지도 앱으로 열기 (미설치 시 웹 폴백)
  Future<void> _openNaverMap(Slope slope) async {
    final query = Uri.encodeComponent(slope.address);
    final appUri =
        Uri.parse('nmap://search?query=$query&appname=com.glution.nakstar');
    final webUri = Uri.parse('https://map.naver.com/p/search/$query');
    if (await canLaunchUrl(appUri)) {
      await launchUrl(appUri);
      return;
    }
    final ok = await launchUrl(webUri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      AppSnackBar.error(context, '지도를 열 수 없어요');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final bg = isDark ? AppColors.darkBg : Colors.white;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subColor = isDark ? AppColors.darkTextSub : AppColors.lightTextSub;
    final accent = isDark ? AppColors.neonGreen : AppColors.navy;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Text(
          widget.focus?.displayName ?? '슬로프 지도',
          style: AppTextStyles.heading3.copyWith(color: textColor),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // 위성/일반 지도 전환
          IconButton(
            onPressed: () {
              setState(() => _satellite = !_satellite);
            },
            icon: Icon(
              _satellite ? LucideIcons.map : LucideIcons.globe,
              color: textColor,
              size: 22,
            ),
            tooltip: _satellite ? '일반지도' : '위성지도',
          ),
        ],
      ),
      body: Stack(
        children: [
          NaverMap(
            options: NaverMapViewOptions(
              initialCameraPosition: _initialCamera,
              mapType: _satellite ? NMapType.hybrid : NMapType.basic,
              logoAlign: NLogoAlign.leftTop,
              logoMargin: const EdgeInsets.all(AppSpacing.md),
            ),
            // 밀집 지역(당진 대호만 등) 자동 클러스터링
            clusterOptions: NaverMapClusteringOptions(
              clusterMarkerBuilder: (info, clusterMarker) {
                clusterMarker
                  ..setIconTintColor(accent)
                  ..setCaption(NOverlayCaption(
                    text: info.size.toString(),
                    color: isDark ? Colors.black : Colors.white,
                    haloColor: Colors.transparent,
                  ));
              },
            ),
            onMapReady: (controller) {
              _controller = controller;
              _addMarkers(controller);
            },
          ),
          // ── 선택된 슬로프 정보 카드 ──
          if (_selected != null)
            Positioned(
              left: AppSpacing.xl,
              right: AppSpacing.xl,
              bottom: AppSpacing.xxl,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _selected!.displayName,
                            style: AppTextStyles.bodyBold
                                .copyWith(color: textColor),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _selected = null),
                          child: Icon(LucideIcons.x, color: subColor, size: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _selected!.address,
                      style: AppTextStyles.caption.copyWith(color: subColor),
                    ),
                    if (_selected!.waterBody.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${_selected!.sigungu} · ${_selected!.waterBody}',
                        style:
                            AppTextStyles.captionSmall.copyWith(color: accent),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _openNaverMap(_selected!),
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: isDark ? Colors.black : Colors.white,
                          padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.lg),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(LucideIcons.navigation, size: 16),
                        label: Text('네이버지도 앱에서 열기',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: isDark ? Colors.black : Colors.white,
                              fontWeight: FontWeight.w700,
                            )),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
