import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/address_utils.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/widgets/slide_to_confirm.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../feed/data/feed_repository.dart';
import '../../../feed/data/post_model.dart';
import '../../../profile/data/profile_repository.dart';
import '../../../../core/extensions/theme_extensions.dart';
import '../../../../core/utils/image_downloader.dart';

class PersonalRecordDetailScreen extends ConsumerStatefulWidget {
  const PersonalRecordDetailScreen({super.key, required this.post});
  final Post post;

  @override
  ConsumerState<PersonalRecordDetailScreen> createState() => _PersonalRecordDetailScreenState();
}

class _PersonalRecordDetailScreenState extends ConsumerState<PersonalRecordDetailScreen> {
  bool _sharing = false;
  bool _downloading = false;

  Post get post => widget.post;

  Future<void> _delete() async {
    await showDeleteConfirmSheet(
      context,
      title: '기록 삭제',
      content: '이 조과 기록을 삭제하시겠습니까?\n삭제된 기록은 복구할 수 없습니다.',
      onConfirmed: () async {
        try {
          await ref.read(feedRepositoryProvider).deletePost(post.id);
          ref.invalidate(myPersonalRecordsProvider);
          ref.invalidate(myProfileProvider);
          if (mounted) Navigator.pop(context);
        } catch (e) {
          if (mounted) AppSnackBar.error(context, '삭제 실패: $e');
        }
      },
    );
  }

  void _openMoreMenu(bool isDark, Color accent) {
    final divColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE);
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF444444) : const Color(0xFFCCCCCC),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            _MenuItem(
              icon: LucideIcons.send,
              label: '내 피드에 공유하기',
              color: accent,
              onTap: () {
                Navigator.pop(sheetCtx);
                _shareToFeed();
              },
            ),
            Divider(height: 1, color: divColor),
            _MenuItem(
              icon: LucideIcons.download,
              label: '사진 저장',
              color: accent,
              onTap: () {
                Navigator.pop(sheetCtx);
                _downloadImage();
              },
            ),
            Divider(height: 1, color: divColor),
            _MenuItem(
              icon: LucideIcons.trash2,
              label: '기록 삭제',
              color: AppColors.error,
              onTap: () {
                Navigator.pop(sheetCtx);
                _delete();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadImage() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      await downloadImageToGallery(post.imageUrl);
      if (mounted) AppSnackBar.success(context, '갤러리에 저장되었습니다');
    } catch (e) {
      if (mounted) AppSnackBar.error(context, '저장 실패: $e');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _shareToFeed() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      await ref.read(feedRepositoryProvider).sharePostToFeed(post);
      ref.invalidate(feedPostsProvider);
      ref.invalidate(myPostsProvider);
      ref.invalidate(myProfileProvider);
      if (mounted) AppSnackBar.success(context, '내 피드에 공유되었습니다');
    } catch (e) {
      if (mounted) AppSnackBar.error(context, '공유 실패: $e');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = context.isDark ? AppColors.darkBg : Colors.white;
    final cardBg = context.isDark ? AppColors.darkSurface : const Color(0xFFF7F7F8);
    final sub = context.isDark ? const Color(0xFF8E8E8E) : const Color(0xFF737373);
    final iconColor = context.isDark ? Colors.white : Colors.black;
    final hasGps = post.lat != null && post.lng != null;
    final isOwner = ref.watch(currentUserProvider)?.id == post.userId;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('내 기록', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: Icon(LucideIcons.chevronLeft, color: iconColor),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (isOwner)
            (_sharing || _downloading)
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Center(
                      child: SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: context.accentColor),
                      ),
                    ),
                  )
                : IconButton(
                    icon: Icon(LucideIcons.moreHorizontal, color: iconColor),
                    onPressed: () => _openMoreMenu(context.isDark, context.accentColor),
                  ),
        ],
      ),
      body: ListView(
        children: [
          // ── 사진 ───────────────────────────────
          AspectRatio(
            aspectRatio: (post.aspectRatio ?? (4 / 3)).clamp(0.8, 1.91),
            child: Container(
              color: context.isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF2F2F2),
              child: CachedNetworkImage(
                imageUrl: post.imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Center(
                  child: CircularProgressIndicator(strokeWidth: 2, color: context.accentColor),
                ),
                errorWidget: (_, __, ___) => Center(
                  child: Icon(LucideIcons.image, size: 60, color: sub),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── 배스 크기 ────────────────────────────
          if (post.length != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                decoration: BoxDecoration(
                  color: context.accentColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.accentColor.withValues(alpha: 0.25)),
                ),
                child: Row(children: [
                  Icon(LucideIcons.fish, size: 22, color: context.accentColor),
                  const SizedBox(width: 12),
                  Text(post.fishType,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.accentColor)),
                  const Spacer(),
                  Text('${post.length}',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: context.accentColor)),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('cm',
                        style: TextStyle(fontSize: 13, color: context.accentColor, fontWeight: FontWeight.w700)),
                  ),
                  if (post.isLunker) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(LucideIcons.award, size: 11, color: Colors.black),
                        SizedBox(width: 3),
                        Text('런커',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black)),
                      ]),
                    ),
                  ],
                  if (post.reviewStatus == 'approved') ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(LucideIcons.badgeCheck, size: 11, color: Colors.green[700]),
                        const SizedBox(width: 3),
                        Text('인증',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.green[700])),
                      ]),
                    ),
                  ],
                ]),
              ),
            ),

          const SizedBox(height: 12),

          // ── 위치 (GPS) ────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AppCard(
              padding: EdgeInsets.zero,
              radius: 14,
              borderColor: context.isDark ? AppColors.darkSurface2 : AppColors.lightDivider,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(16, 14, 16, hasGps ? 12 : 14),
                    child: Row(children: [
                      Icon(LucideIcons.mapPin, size: 18, color: context.accentColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post.location?.isNotEmpty == true
                                  ? dedupeAddress(post.location!)
                                  : (hasGps ? '촬영 위치' : '위치 정보 없음'),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                            if (hasGps) ...[
                              const SizedBox(height: 2),
                              Text(
                                '${post.lat!.toStringAsFixed(6)}, ${post.lng!.toStringAsFixed(6)}',
                                style: TextStyle(fontSize: 11, color: sub),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (hasGps)
                        IconButton(
                          icon: Icon(LucideIcons.copy, size: 16, color: sub),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(
                              text: '${post.lat},${post.lng}',
                            ));
                            AppSnackBar.info(context, '좌표가 복사되었습니다');
                          },
                        ),
                    ]),
                  ),
                  if (hasGps)
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(13)),
                      child: SizedBox(
                        height: 200,
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: LatLng(post.lat!, post.lng!),
                            initialZoom: 14,
                            interactionOptions: const InteractionOptions(
                              flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                            ),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'app.huk.fishing_competition',
                            ),
                            MarkerLayer(markers: [
                              Marker(
                                point: LatLng(post.lat!, post.lng!),
                                width: 36, height: 36,
                                child: Icon(LucideIcons.mapPin, color: context.accentColor, size: 32),
                              ),
                            ]),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── 촬영 시간 ────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Icon(LucideIcons.clock, size: 13, color: sub),
              const SizedBox(width: 6),
              Text(_formatDate(post.createdAt), style: TextStyle(fontSize: 12, color: sub)),
            ]),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final l = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${l.year}.${two(l.month)}.${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Row(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 16),
          Text(label, style: TextStyle(fontSize: 15, color: color, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}
