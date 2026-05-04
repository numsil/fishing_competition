# 조과 앨범 묶음 피드 공유 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 개인 기록 탭의 조과 앨범에서 사진을 최대 5장 선택해 하나의 피드 캐러셀 포스트로 공유하는 기능을 구현한다.

**Architecture:** `_PersonalRecordTab`에 선택 모드를 추가하고, 선택 완료 후 `AlbumBundleShareScreen`(신규)으로 push하여 문구·위치·길이/무게·리그 태그를 작성한 뒤 `feedRepository.shareMultiplePostsToFeed()`로 피드에 등록한다. 이미 업로드된 이미지 URL을 그대로 참조하므로 재업로드가 없다.

**Tech Stack:** Flutter, Riverpod (riverpod_annotation), Supabase, go_router, cached_network_image, lucide_icons

---

## File Map

| 파일 | 역할 |
|---|---|
| `lib/features/feed/data/feed_repository.dart` | `shareMultiplePostsToFeed()` 메서드 추가 |
| `lib/features/my_league/presentation/screens/album_bundle_share_screen.dart` | **신규** — 피드 등록 화면 |
| `lib/core/router/app_router.dart` | `/album-bundle-share` 라우트 + `AppRoutes.albumBundleShare` 상수 추가 |
| `lib/features/my_league/presentation/screens/my_league_screen.dart` | `_PersonalRecordTab` → StatefulWidget 전환 + 선택 모드 UI |

---

## Task 1: FeedRepository에 shareMultiplePostsToFeed 추가

**Files:**
- Modify: `lib/features/feed/data/feed_repository.dart`

- [ ] **Step 1: `shareMultiplePostsToFeed` 메서드를 `FeedRepository` 클래스에 추가**

`deletePost` 메서드 바로 아래에 다음을 추가한다.

```dart
/// 조과 앨범에서 선택한 여러 Post를 하나의 피드 포스트로 공유.
/// 이미지는 재업로드 없이 기존 URL을 그대로 참조한다.
Future<void> shareMultiplePostsToFeed({
  required List<Post> posts,
  String? caption,
  String? location,
  double? length,
  double? weight,
  String? leagueId,
}) async {
  final userId = _supabase.auth.currentUser?.id;
  if (userId == null) throw Exception('Not logged in');
  final first = posts.first;
  await _supabase.from('posts').insert({
    'user_id': userId,
    'image_url': first.imageUrl,
    'image_urls': posts.map((p) => p.imageUrl).toList(),
    'aspect_ratio': first.aspectRatio,
    'caption': caption,
    'fish_type': first.fishType,
    'location': location,
    'league_id': leagueId,
    'is_personal_record': false,
    'length': length,
    'weight': weight,
    'catch_count': posts.length,
    'is_lunker': length != null && length >= 50.0,
  });
}
```

- [ ] **Step 2: 앱이 빌드되는지 확인**

```bash
cd /Users/jun/Desktop/code/HUK/fishing_competition
flutter analyze lib/features/feed/data/feed_repository.dart
```

Expected: `No issues found!`

- [ ] **Step 3: 커밋**

```bash
git add lib/features/feed/data/feed_repository.dart
git commit -m "feat: FeedRepository에 shareMultiplePostsToFeed 추가"
```

---

## Task 2: AlbumBundleShareScreen 신규 생성

**Files:**
- Create: `lib/features/my_league/presentation/screens/album_bundle_share_screen.dart`

이 화면은 `upload_screen.dart`의 `_CaptionStep`과 동일한 UX이지만 로컬 파일 대신 이미 업로드된 네트워크 URL을 사용한다.

- [ ] **Step 1: 파일 생성**

`lib/features/my_league/presentation/screens/album_bundle_share_screen.dart` 를 아래 내용으로 생성한다.

```dart
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
```

- [ ] **Step 2: 빌드 확인**

```bash
flutter analyze lib/features/my_league/presentation/screens/album_bundle_share_screen.dart
```

Expected: `No issues found!`

- [ ] **Step 3: 커밋**

```bash
git add lib/features/my_league/presentation/screens/album_bundle_share_screen.dart
git commit -m "feat: AlbumBundleShareScreen 신규 추가"
```

---

## Task 3: 라우터에 albumBundleShare 등록

**Files:**
- Modify: `lib/core/router/app_router.dart`

- [ ] **Step 1: import 추가**

`app_router.dart` 상단 import 목록에 다음을 추가한다 (기존 `personal_record_detail_screen.dart` import 바로 아래).

```dart
import '../../features/my_league/presentation/screens/album_bundle_share_screen.dart';
```

- [ ] **Step 2: AppRoutes 상수 추가**

`app_router.dart` 하단 `AppRoutes` 클래스의 상수 목록에 다음을 추가한다 (`dmChat` 상수 바로 아래).

```dart
static const String albumBundleShare = '/album-bundle-share';
```

- [ ] **Step 3: GoRoute 등록**

`personalRecordDetail` GoRoute 블록 바로 아래에 다음을 추가한다.

```dart
// 조과 앨범 묶음 피드 등록
GoRoute(
  path: AppRoutes.albumBundleShare,
  pageBuilder: (context, state) {
    final posts = state.extra as List<Post>;
    return MaterialPage(child: AlbumBundleShareScreen(posts: posts));
  },
),
```

- [ ] **Step 4: 빌드 확인**

```bash
flutter analyze lib/core/router/app_router.dart
```

Expected: `No issues found!`

- [ ] **Step 5: 커밋**

```bash
git add lib/core/router/app_router.dart
git commit -m "feat: /album-bundle-share 라우트 등록"
```

---

## Task 4: _PersonalRecordTab 선택 모드 구현

**Files:**
- Modify: `lib/features/my_league/presentation/screens/my_league_screen.dart`

이 태스크는 `_PersonalRecordTab`을 `ConsumerWidget` → `ConsumerStatefulWidget`으로 변환하고 선택 모드 UI를 추가한다.

- [ ] **Step 1: 클래스 선언부 변환**

기존:
```dart
class _PersonalRecordTab extends ConsumerWidget {
  const _PersonalRecordTab({
    required this.isDark,
    required this.accent,
    required this.sub,
    required this.cardBg,
    required this.divColor,
  });
  final bool isDark;
  final Color accent, sub, cardBg, divColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
```

변경 후:
```dart
class _PersonalRecordTab extends ConsumerStatefulWidget {
  const _PersonalRecordTab({
    required this.isDark,
    required this.accent,
    required this.sub,
    required this.cardBg,
    required this.divColor,
  });
  final bool isDark;
  final Color accent, sub, cardBg, divColor;

  @override
  ConsumerState<_PersonalRecordTab> createState() => _PersonalRecordTabState();
}

class _PersonalRecordTabState extends ConsumerState<_PersonalRecordTab> {
  bool _selectMode = false;
  final List<Post> _orderedSelected = [];

  void _toggleSelect(Post post) {
    setState(() {
      final already = _orderedSelected.any((p) => p.id == post.id);
      if (already) {
        _orderedSelected.removeWhere((p) => p.id == post.id);
      } else {
        if (_orderedSelected.length >= 5) return;
        _orderedSelected.add(post);
      }
    });
  }

  void _exitSelectMode() {
    setState(() {
      _selectMode = false;
      _orderedSelected.clear();
    });
  }

  bool get isDark => widget.isDark;
  Color get accent => widget.accent;
  Color get sub => widget.sub;
  Color get cardBg => widget.cardBg;
  Color get divColor => widget.divColor;

  @override
  Widget build(BuildContext context) {
```

- [ ] **Step 2: "내 조과 앨범 N장" 행에 선택/취소 버튼 추가**

기존:
```dart
SliverToBoxAdapter(
  child: Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
    child: Row(
      children: [
        Icon(LucideIcons.image, size: 14, color: sub),
        const SizedBox(width: 6),
        Text('내 조과 앨범 ${posts.length}장',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: sub)),
      ],
    ),
  ),
),
```

변경 후:
```dart
SliverToBoxAdapter(
  child: Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
    child: Row(
      children: [
        Icon(LucideIcons.image, size: 14, color: sub),
        const SizedBox(width: 6),
        Text('내 조과 앨범 ${posts.length}장',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: sub)),
        const Spacer(),
        if (posts.isNotEmpty)
          GestureDetector(
            onTap: () {
              setState(() {
                _selectMode = !_selectMode;
                if (!_selectMode) _orderedSelected.clear();
              });
            },
            child: Text(
              _selectMode ? '취소' : '선택',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: accent),
            ),
          ),
      ],
    ),
  ),
),
```

- [ ] **Step 3: 그리드 아이템 선택 모드 오버레이 적용**

기존 `GestureDetector` 블록:
```dart
return GestureDetector(
  onTap: () => context.push(AppRoutes.personalRecordDetail, extra: post),
  child: Stack(
    fit: StackFit.expand,
    children: [
      CachedNetworkImage(
        imageUrl: post.imageUrl,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => Container(
          color: isDark ? AppColors.darkSurface2 : AppColors.lightDivider,
          child: Icon(LucideIcons.image, size: 24, color: sub),
        ),
      ),
      if (post.isLunker)
        Positioned(
          bottom: 4, right: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.gold,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              post.length != null ? '${post.length}cm' : '런커',
              style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.black),
            ),
          ),
        ),
    ],
  ),
);
```

변경 후 (전체 교체):
```dart
final isSelected = _orderedSelected.any((p) => p.id == post.id);
final selectedIndex = _orderedSelected.indexWhere((p) => p.id == post.id);
final maxReached = _orderedSelected.length >= 5;
final dimmed = _selectMode && !isSelected && maxReached;

return GestureDetector(
  onTap: () {
    if (_selectMode) {
      if (!isSelected && maxReached) return;
      _toggleSelect(post);
    } else {
      context.push(AppRoutes.personalRecordDetail, extra: post);
    }
  },
  child: Opacity(
    opacity: dimmed ? 0.4 : 1.0,
    child: Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: post.imageUrl,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => Container(
            color: isDark ? AppColors.darkSurface2 : AppColors.lightDivider,
            child: Icon(LucideIcons.image, size: 24, color: sub),
          ),
        ),
        // 선택 오버레이
        if (_selectMode && isSelected)
          Container(color: Colors.blue.withValues(alpha: 0.35)),
        // 선택 순번 뱃지
        if (_selectMode)
          Positioned(
            top: 6, right: 6,
            child: isSelected
                ? Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        '${selectedIndex + 1}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                  )
                : Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                      color: Colors.black.withValues(alpha: 0.3),
                    ),
                  ),
          ),
        // 런커 뱃지 (선택 모드에서도 유지)
        if (post.isLunker)
          Positioned(
            bottom: 4, right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                post.length != null ? '${post.length}cm' : '런커',
                style: const TextStyle(
                    fontSize: 8, fontWeight: FontWeight.w800, color: Colors.black),
              ),
            ),
          ),
      ],
    ),
  ),
);
```

- [ ] **Step 4: 하단 버튼 영역 — 선택 모드일 때 공유 버튼으로 전환**

기존 `Positioned` 하단 버튼 블록 전체를 아래로 교체한다.

기존:
```dart
Positioned(
  left: 16, right: 16, bottom: 16,
  child: Row(
    children: [
      // 앨범 버튼 ... 카메라 버튼 ...
    ],
  ),
),
```

변경 후:
```dart
Positioned(
  left: 16, right: 16, bottom: 16,
  child: _selectMode
      ? SizedBox(
          height: 54,
          child: ElevatedButton(
            onPressed: _orderedSelected.isEmpty
                ? null
                : () async {
                    final result = await context.push<bool>(
                      AppRoutes.albumBundleShare,
                      extra: List<Post>.from(_orderedSelected),
                    );
                    if (result == true && mounted) {
                      _exitSelectMode();
                      AppSnackBar.success(context, '피드에 공유되었습니다 🎣');
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _orderedSelected.isEmpty ? null : accent,
              foregroundColor: isDark ? Colors.black : Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(
              _orderedSelected.isEmpty
                  ? '사진을 선택하세요'
                  : '${_orderedSelected.length}장 선택됨 · 피드에 공유하기',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        )
      : Row(
          children: [
            // 앨범 버튼
            SizedBox(
              width: 54, height: 54,
              child: OutlinedButton(
                onPressed: () async {
                  File? picked;
                  try {
                    final img = await ImagePicker().pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 85,
                      maxWidth: 1280,
                    );
                    if (img != null) picked = File(img.path);
                  } catch (e) {
                    if (context.mounted) AppSnackBar.error(context, '갤러리 실행 실패: $e');
                    return;
                  }
                  if (picked == null || !context.mounted) return;
                  await context.push(AppRoutes.personalCatch, extra: picked);
                },
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  side: BorderSide(color: accent.withValues(alpha: 0.6)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
                ),
                child: Icon(Icons.photo_library_rounded, size: 22, color: accent),
              ),
            ),
            const SizedBox(width: 10),
            // 카메라 버튼
            Expanded(
              child: SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    File? captured;
                    try {
                      final picked = await ImagePicker().pickImage(
                        source: ImageSource.camera,
                        imageQuality: 85,
                        maxWidth: 1280,
                      );
                      if (picked != null) captured = File(picked.path);
                    } catch (e) {
                      if (context.mounted) AppSnackBar.error(context, '카메라 실행 실패: $e');
                      return;
                    }
                    if (captured == null || !context.mounted) return;
                    await context.push(AppRoutes.personalCatch, extra: captured);
                  },
                  icon: const Icon(Icons.camera_alt_rounded, size: 22),
                  label: const Text('사진 촬영하기',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
          ],
        ),
),
```

- [ ] **Step 5: 빌드 확인**

```bash
flutter analyze lib/features/my_league/presentation/screens/my_league_screen.dart
```

Expected: `No issues found!`

- [ ] **Step 6: 전체 앱 analyze**

```bash
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 7: 커밋**

```bash
git add lib/features/my_league/presentation/screens/my_league_screen.dart
git commit -m "feat: 조과 앨범 묶음 선택 모드 및 피드 공유 진입 구현"
```

---

## 수동 검증 시나리오

구현 완료 후 아래 시나리오를 기기/시뮬레이터에서 직접 확인한다.

1. **선택 모드 진입/취소**
   - 나의 리그 → 개인 기록 탭 → "선택" 탭 → 그리드에 빈 원형 뱃지 표시 확인
   - "취소" 탭 → 선택 해제, 기존 UI 복원 확인

2. **사진 선택**
   - 사진 탭 → 파란 오버레이 + "1" 순번 표시 확인
   - 추가 탭 → "2", "3" 순번 확인
   - 5장 선택 시 나머지 사진 dimmed + 탭 불가 확인
   - 선택된 사진 재탭 → 해제 + 순번 재정렬 확인

3. **피드 공유 화면**
   - "N장 선택됨 · 피드에 공유하기" 탭 → AlbumBundleShareScreen 진입 확인
   - 2장 이상: 상단 썸네일 스트립 + "대표" 뱃지 확인
   - 1장: 스트립 미표시 확인
   - 첫 번째 사진의 위치/길이 자동 채움 확인
   - 문구 입력 후 "공유" 탭 → 피드 화면에서 캐러셀로 표시 확인

4. **피드 캐러셀 확인**
   - 피드 탭 → 공유한 포스트에 "1 / N" 카운터 + 스와이프로 사진 전환 확인
   - dot 인디케이터 정상 작동 확인
