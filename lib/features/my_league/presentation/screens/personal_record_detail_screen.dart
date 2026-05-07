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
import '../../../../core/widgets/menu_item.dart';
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

  late Post _post;
  Post get post => _post;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
  }

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
            AppMenuItem(
              icon: LucideIcons.pencil,
              label: '수정하기',
              color: accent,
              onTap: () {
                Navigator.pop(sheetCtx);
                _openEditSheet();
              },
            ),
            Divider(height: 1, color: divColor),
            AppMenuItem(
              icon: LucideIcons.send,
              label: '내 피드에 공유하기',
              color: accent,
              onTap: () {
                Navigator.pop(sheetCtx);
                _shareToFeed();
              },
            ),
            Divider(height: 1, color: divColor),
            AppMenuItem(
              icon: LucideIcons.download,
              label: '사진 저장',
              color: accent,
              onTap: () {
                Navigator.pop(sheetCtx);
                _downloadImage();
              },
            ),
            Divider(height: 1, color: divColor),
            AppMenuItem(
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

  void _openEditSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _PersonalRecordEditSheet(
        post: _post,
        isDark: context.isDark,
        accent: context.accentColor,
        onSaved: (updated) {
          if (mounted) setState(() => _post = updated);
          ref.invalidate(myPersonalRecordsProvider);
          ref.invalidate(myProfileProvider);
        },
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
                  ] else if (post.reviewStatus == 'rejected') ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(LucideIcons.shieldOff, size: 11, color: AppColors.error),
                        const SizedBox(width: 3),
                        Text('거부',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.error)),
                      ]),
                    ),
                  ] else if (post.reviewStatus == 'pending') ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(LucideIcons.clock, size: 11, color: Colors.orange[700]),
                        const SizedBox(width: 3),
                        Text('인증 중',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.orange[700])),
                      ]),
                    ),
                  ],
                ]),
              ),
            ),

          // ── 거부 안내 배너 ────────────────────────
          if (post.reviewStatus == 'rejected')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(LucideIcons.alertTriangle, size: 18, color: AppColors.error),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('인증이 거부되었습니다',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.error)),
                        const SizedBox(height: 4),
                        Text(
                          '점수에 반영되지 않습니다. 사진이 명확하지 않거나 측정값이 부정확할 수 있습니다. 삭제 후 다시 등록해주세요.',
                          style: TextStyle(fontSize: 12, color: AppColors.error.withValues(alpha: 0.85), height: 1.4),
                        ),
                      ],
                    ),
                  ),
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

class _PersonalRecordEditSheet extends ConsumerStatefulWidget {
  const _PersonalRecordEditSheet({
    required this.post,
    required this.isDark,
    required this.accent,
    required this.onSaved,
  });
  final Post post;
  final bool isDark;
  final Color accent;
  final void Function(Post updated) onSaved;

  @override
  ConsumerState<_PersonalRecordEditSheet> createState() => _PersonalRecordEditSheetState();
}

class _PersonalRecordEditSheetState extends ConsumerState<_PersonalRecordEditSheet> {
  late final TextEditingController _locationCtrl;
  late final TextEditingController _captionCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _locationCtrl = TextEditingController(text: widget.post.location ?? '');
    _captionCtrl = TextEditingController(text: widget.post.caption ?? '');
  }

  @override
  void dispose() {
    _locationCtrl.dispose();
    _captionCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final newCaption = _captionCtrl.text.trim();
      final newLocation = _locationCtrl.text.trim();
      await ref.read(feedRepositoryProvider).updatePostMeta(
        postId: widget.post.id,
        caption: newCaption,
        location: newLocation,
      );
      // 로컬 화면 즉시 갱신을 위해 업데이트된 Post 반환
      final updated = widget.post.copyWith(
        caption: newCaption.isEmpty ? null : newCaption,
        location: newLocation.isEmpty ? null : newLocation,
      );
      widget.onSaved(updated);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) AppSnackBar.error(context, '수정 실패: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final accent = widget.accent;
    final sub = isDark ? AppColors.darkTextSub : AppColors.lightTextSub;
    final divColor = isDark ? AppColors.darkDivider : AppColors.lightDivider;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('수정하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black)),
              const Spacer(),
              _saving
                  ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: accent))
                  : TextButton(
                      onPressed: _save,
                      child: Text('저장', style: TextStyle(color: accent, fontWeight: FontWeight.w700)),
                    ),
            ]),
            Divider(height: 24, color: divColor),
            Text('장소', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: sub)),
            const SizedBox(height: 8),
            TextField(
              controller: _locationCtrl,
              autofocus: true,
              style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                hintText: '예) 충주호, 소양강 등',
                hintStyle: TextStyle(color: sub, fontSize: 13),
                prefixIcon: Icon(LucideIcons.mapPin, size: 16, color: sub),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: divColor)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: divColor)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: accent)),
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              ),
            ),
            const SizedBox(height: 16),
            Text('메모', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: sub)),
            const SizedBox(height: 8),
            TextField(
              controller: _captionCtrl,
              maxLines: 4,
              style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                hintText: '조과 상황, 사용한 루어 등을 자유롭게 입력하세요',
                hintStyle: TextStyle(color: sub, fontSize: 13),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: divColor)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: divColor)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: accent)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
