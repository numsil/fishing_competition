import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/extensions/theme_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../feed/data/feed_repository.dart';
import '../../../feed/data/post_model.dart';
import '../../../league/data/league_repository.dart';
import '../../../profile/data/profile_repository.dart';
import '../../../../core/widgets/app_svg.dart'; // AppSvg, AppIcons 모두 이 파일에 정의됨

class AlbumBundleShareScreen extends ConsumerStatefulWidget {
  const AlbumBundleShareScreen({super.key, required this.posts});

  /// 선택 순서대로 전달된 포스트 목록 (최대 5개)
  final List<Post> posts;

  @override
  ConsumerState<AlbumBundleShareScreen> createState() =>
      _AlbumBundleShareScreenState();
}

class _AlbumBundleShareScreenState
    extends ConsumerState<AlbumBundleShareScreen> {
  final _captionCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _lengthCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  String? _selectedLeagueId;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    // 첫 번째 선택 사진의 메타데이터로 초기값 채움
    final first = widget.posts.first;
    if (first.location != null && first.location!.isNotEmpty) {
      _locationCtrl.text = first.location!;
    }
    if (first.length != null) {
      _lengthCtrl.text = first.length.toString();
    }
    if (first.weight != null) {
      _weightCtrl.text = first.weight.toString();
    }
  }

  @override
  void dispose() {
    _captionCtrl.dispose();
    _locationCtrl.dispose();
    _lengthCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    if (_sharing) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _sharing = true);
    try {
      await ref.read(feedRepositoryProvider).shareMultiplePostsToFeed(
        posts: widget.posts,
        caption: _captionCtrl.text.trim().isEmpty
            ? null
            : _captionCtrl.text.trim(),
        location: _locationCtrl.text.trim().isEmpty
            ? null
            : _locationCtrl.text.trim(),
        length: double.tryParse(_lengthCtrl.text.trim()),
        weight: double.tryParse(_weightCtrl.text.trim()),
        leagueId: _selectedLeagueId,
      );
      ref.invalidate(feedPostsProvider);
      ref.invalidate(myPostsProvider);
      if (mounted) {
        Navigator.of(context).pop(true); // true = 공유 성공
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sharing = false);
        AppSnackBar.error(context, '공유 실패: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final accent = context.accentColor;
    final bg = isDark ? AppColors.darkBg : Colors.white;
    final sub = isDark ? const Color(0xFF8E8E8E) : const Color(0xFF737373);
    final divColor = isDark ? const Color(0xFF262626) : const Color(0xFFEEEEEE);
    final textColor = isDark ? Colors.white : Colors.black;
    final isMulti = widget.posts.length > 1;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: _sharing ? null : () => Navigator.of(context).pop(),
          icon: Icon(LucideIcons.chevronLeft, color: textColor, size: 24),
        ),
        title: Text(
          '피드에 공유',
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700, color: textColor),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _sharing ? null : _share,
              child: _sharing
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: accent),
                    )
                  : Text(
                      '공유',
                      style: TextStyle(
                          color: accent,
                          fontSize: 16,
                          fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 40),
          children: [
            // ── 사진 썸네일 스트립 (2장 이상일 때) ──
            if (isMulti) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 0, 8),
                child: Row(children: [
                  Text(
                    '선택된 사진 ${widget.posts.length}/5',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textColor),
                  ),
                ]),
              ),
              SizedBox(
                height: 96,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  itemCount: widget.posts.length,
                  itemBuilder: (_, i) {
                    final post = widget.posts[i];
                    return Stack(
                      children: [
                        Container(
                          width: 60,
                          height: 75,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: i == 0 ? accent : divColor,
                              width: i == 0 ? 2 : 1,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: CachedNetworkImage(
                              imageUrl: post.imageUrl,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(
                                color: isDark
                                    ? AppColors.darkSurface2
                                    : AppColors.lightDivider,
                                child: Icon(LucideIcons.image,
                                    size: 20, color: sub),
                              ),
                            ),
                          ),
                        ),
                        if (i == 0)
                          Positioned(
                            bottom: 4,
                            left: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: accent,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('대표',
                                  style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black)),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              Divider(height: 1, color: divColor),
            ],

            // ── 첫 번째 썸네일 + 캡션 ──
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          width: 72,
                          height: 72,
                          child: CachedNetworkImage(
                            imageUrl: widget.posts.first.imageUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              color: isDark
                                  ? AppColors.darkSurface2
                                  : AppColors.lightDivider,
                              child: Icon(LucideIcons.image,
                                  size: 28, color: sub),
                            ),
                          ),
                        ),
                      ),
                      if (isMulti)
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '+${widget.posts.length - 1}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClipRect(
                      child: TextField(
                        controller: _captionCtrl,
                        maxLines: 5,
                        minLines: 3,
                        autofocus: true,
                        style: TextStyle(fontSize: 14, color: textColor),
                        decoration: InputDecoration(
                          hintText: '문구를 작성하세요...',
                          hintStyle: TextStyle(color: sub, fontSize: 14),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.only(top: 2),
                          isDense: true,
                        ),
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
                  suffixIcon:
                      Icon(Icons.location_on_outlined, color: sub, size: 20),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  isDense: true,
                ),
              ),
            ),

            Divider(height: 1, color: divColor),
            const SizedBox(height: 20),

            // ── 길이 / 무게 ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('길이 (cm)',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: textColor)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _lengthCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            // TODO: 전체 앱에서 소수점 입력 유효성 개선 필요 (#inherited)
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d*')),
                          ],
                          style: TextStyle(fontSize: 14, color: textColor),
                          decoration: InputDecoration(
                            hintText: '예) 42.5',
                            hintStyle: TextStyle(color: sub, fontSize: 14),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            isDense: true,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: divColor)),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: divColor)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: accent)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('무게 (g)',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: textColor)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _weightCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            // TODO: 전체 앱에서 소수점 입력 유효성 개선 필요 (#inherited)
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d*')),
                          ],
                          style: TextStyle(fontSize: 14, color: textColor),
                          decoration: InputDecoration(
                            hintText: '예) 980',
                            hintStyle: TextStyle(color: sub, fontSize: 14),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            isDense: true,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: divColor)),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: divColor)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: accent)),
                          ),
                        ),
                      ],
                    ),
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
                  Text('리그 태그',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: textColor)),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () =>
                        setState(() => _selectedLeagueId = null),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(children: [
                        Icon(Icons.block_rounded,
                            size: 14,
                            color: _selectedLeagueId == null ? accent : sub),
                        const SizedBox(width: 10),
                        Text('없음',
                            style: TextStyle(
                              fontSize: 14,
                              color: _selectedLeagueId == null
                                  ? accent
                                  : textColor,
                              fontWeight: _selectedLeagueId == null
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            )),
                        const Spacer(),
                        if (_selectedLeagueId == null)
                          Icon(Icons.check_rounded,
                              size: 18, color: accent),
                      ]),
                    ),
                  ),
                  ref.watch(myJoinedLeaguesProvider).when(
                    data: (leagues) => Column(
                      children: leagues.isEmpty
                          ? [
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                child: Text('참가 중인 리그가 없습니다.',
                                    style: TextStyle(
                                        fontSize: 13, color: sub)),
                              )
                            ]
                          : leagues.map((l) {
                              final selected = _selectedLeagueId == l.id;
                              return InkWell(
                                onTap: () => setState(
                                    () => _selectedLeagueId = l.id),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10),
                                  child: Row(children: [
                                    AppSvg(AppIcons.trophy,
                                        size: 14,
                                        color: selected ? accent : sub),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(l.title,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: selected
                                                ? accent
                                                : textColor,
                                            fontWeight: selected
                                                ? FontWeight.w600
                                                : FontWeight.w400,
                                          )),
                                    ),
                                    if (selected)
                                      Icon(Icons.check_rounded,
                                          size: 18, color: accent),
                                  ]),
                                ),
                              );
                            }).toList(),
                    ),
                    loading: () => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: accent),
                    ),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),
            Divider(height: 1, color: divColor),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(children: [
                Text('공개 범위',
                    style: TextStyle(fontSize: 14, color: textColor)),
                const Spacer(),
                Text('전체 공개',
                    style: TextStyle(fontSize: 14, color: sub)),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: sub),
              ]),
            ),
            Divider(height: 1, color: divColor),
          ],
        ),
      ),
    );
  }
}
