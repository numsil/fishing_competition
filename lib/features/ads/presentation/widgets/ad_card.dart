import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../../core/extensions/theme_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/ad_model.dart';
import '../../data/ad_repository.dart';
import 'ad_video_player.dart';

/// 피드 광고 카드.
/// - 카드 가시 영역이 50%+ 들어왔을 때 view 이벤트 기록 (세션 내 1회만)
/// - 탭 시 외부 브라우저로 link_url 열고 click 이벤트 기록
class AdCard extends ConsumerStatefulWidget {
  const AdCard({super.key, required this.ad, required this.slotKey});
  final AdFeed ad;
  final String slotKey; // VisibilityDetector 키 중복 방지 (같은 광고 재노출 시)

  @override
  ConsumerState<AdCard> createState() => _AdCardState();
}

class _AdCardState extends ConsumerState<AdCard> {
  bool _viewRecorded = false;

  void _onVisibilityChanged(VisibilityInfo info) {
    if (_viewRecorded) return;
    if (info.visibleFraction < 0.5) return;
    _viewRecorded = true;
    // 세션 dedupe: 같은 광고 같은 세션 중복 기록 방지
    final tracker = ref.read(adViewTrackerProvider);
    if (tracker.markIfNew(widget.ad.id)) {
      ref.read(adRepositoryProvider).recordView(widget.ad.id);
    }
  }

  Future<void> _onTap() async {
    final ad = widget.ad;
    // 클릭 기록 (best-effort)
    unawaited(ref.read(adRepositoryProvider).recordClick(ad.id));
    final uri = Uri.tryParse(ad.linkUrl);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('링크를 열 수 없습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ad = widget.ad;
    final isDark = context.isDark;
    final sub =
        isDark ? AppColors.darkTextSub : AppColors.lightTextSub;

    return VisibilityDetector(
      key: Key('ad_card_${widget.slotKey}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.darkSurface2 : AppColors.lightDivider,
            ),
            bottom: BorderSide(
              color: isDark ? AppColors.darkSurface2 : AppColors.lightDivider,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 미디어
            AspectRatio(
              aspectRatio: ad.aspectRatio <= 0 ? 1.0 : ad.aspectRatio,
              child: Stack(
                children: [
                  Positioned.fill(child: _Media(ad: ad, slotKey: widget.slotKey)),
                  // "광고" 레이블 (앱마켓 정책)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '광고',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 캡션 + CTA
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ad.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (ad.body?.isNotEmpty == true) ...[
                          const SizedBox(height: 2),
                          Text(
                            ad.body!,
                            style: TextStyle(
                              fontSize: 12,
                              color: sub,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(LucideIcons.externalLink, size: 16, color: sub),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

// best-effort fire-and-forget
void unawaited(Future<void> f) {
  f.then((_) {}, onError: (_) {});
}

// ──────────────────────────────────────────
// 미디어 분기
// ──────────────────────────────────────────
class _Media extends StatelessWidget {
  const _Media({required this.ad, required this.slotKey});
  final AdFeed ad;
  final String slotKey;

  @override
  Widget build(BuildContext context) {
    if (ad.hasVideo) {
      return AdVideoPlayer(
        adId: ad.id,
        slotKey: slotKey,
        videoUrl: ad.videoUrl!,
        thumbnailUrl: ad.thumbnailUrl,
      );
    }
    if (ad.hasCarousel) {
      return _AdCarousel(urls: ad.imageUrls);
    }
    if (ad.hasImage) {
      return CachedNetworkImage(
        imageUrl: ad.imageUrl!,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) =>
            Container(color: const Color(0xFF1A1A1A)),
      );
    }
    return Container(color: const Color(0xFF1A1A1A));
  }
}

class _AdCarousel extends StatefulWidget {
  const _AdCarousel({required this.urls});
  final List<String> urls;

  @override
  State<_AdCarousel> createState() => _AdCarouselState();
}

class _AdCarouselState extends State<_AdCarousel> {
  static const _autoInterval = Duration(seconds: 3, milliseconds: 500);
  static const _pauseAfterUser = Duration(seconds: 5);

  final _ctrl = PageController();
  int _page = 0;
  Timer? _timer;
  DateTime? _userInteractedAt;
  bool _visible = false;

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.urls.length <= 1) return;
    _timer = Timer.periodic(_autoInterval, (_) {
      if (!mounted || !_visible || !_ctrl.hasClients) return;
      final pausedUntil = _userInteractedAt?.add(_pauseAfterUser);
      if (pausedUntil != null && DateTime.now().isBefore(pausedUntil)) return;
      final next = (_page + 1) % widget.urls.length;
      _ctrl.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  void _onVisibility(VisibilityInfo info) {
    final v = info.visibleFraction >= 0.5;
    if (v == _visible) return;
    _visible = v;
    if (_visible) {
      _startTimer();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('ad_carousel_${widget.urls.first.hashCode}'),
      onVisibilityChanged: _onVisibility,
      child: Stack(
      fit: StackFit.expand,
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n is ScrollStartNotification &&
                n.dragDetails != null) {
              _userInteractedAt = DateTime.now();
            }
            return false;
          },
          child: PageView.builder(
          controller: _ctrl,
          itemCount: widget.urls.length,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (_, i) => CachedNetworkImage(
            imageUrl: widget.urls[i],
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) =>
                Container(color: const Color(0xFF1A1A1A)),
          ),
        ),
        ),
        // 페이지 인디케이터
        Positioned(
          bottom: 8,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.urls.length, (i) {
              final selected = i == _page;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: selected ? 8 : 6,
                height: selected ? 8 : 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.5),
                ),
              );
            }),
          ),
        ),
      ],
    ),
    );
  }
}
