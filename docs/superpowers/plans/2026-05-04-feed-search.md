# 피드 검색 기능 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 피드 홈화면 AppBar에 검색 아이콘을 추가하고, 탭하면 유저명 또는 해시태그로 피드를 클라이언트 필터링한다.

**Architecture:** `feedPostsProvider`의 기존 캐시 데이터를 클라이언트에서 필터링하므로 Supabase 쿼리 추가 없음. `FeedScreen`을 `ConsumerStatefulWidget`으로 변환해 `_isSearching`, `_searchQuery` 상태를 로컬로 관리한다. 필터 순수 함수는 별도 유틸 파일로 분리해 테스트한다.

**Tech Stack:** Flutter, Riverpod, Freezed, go_router, lucide_icons

---

## File Map

| 동작 | 파일 |
|------|------|
| Create | `lib/features/feed/presentation/utils/feed_search_utils.dart` |
| Create | `test/features/feed/presentation/feed_search_utils_test.dart` |
| Modify | `lib/features/feed/presentation/screens/feed_screen.dart` |

---

## Task 1: 검색 유틸 함수 + 단위 테스트 (TDD)

**Files:**
- Create: `lib/features/feed/presentation/utils/feed_search_utils.dart`
- Create: `test/features/feed/presentation/feed_search_utils_test.dart`

- [ ] **Step 1: 테스트 디렉토리 생성**

```bash
mkdir -p test/features/feed/presentation
```

- [ ] **Step 2: 실패하는 테스트 작성**

`test/features/feed/presentation/feed_search_utils_test.dart`:

```dart
import 'package:fishing_competition/features/feed/data/post_model.dart';
import 'package:fishing_competition/features/feed/presentation/utils/feed_search_utils.dart';
import 'package:flutter_test/flutter_test.dart';

Post _post({required String username, String? caption}) => Post(
      id: 'id',
      userId: 'uid',
      imageUrl: '',
      createdAt: DateTime.now(),
      username: username,
      caption: caption,
    );

void main() {
  group('extractHashtags', () {
    test('캡션에서 해시태그 추출', () {
      expect(extractHashtags('#배스 #루어낚시 좋은 날씨'), ['#배스', '#루어낚시']);
    });
    test('해시태그 없으면 빈 리스트', () {
      expect(extractHashtags('태그 없음'), []);
    });
    test('null 캡션이면 빈 리스트', () {
      expect(extractHashtags(null), []);
    });
    test('빈 문자열이면 빈 리스트', () {
      expect(extractHashtags(''), []);
    });
  });

  group('filterPosts', () {
    final posts = [
      _post(username: '김민준', caption: '#배스 #루어낚시'),
      _post(username: '이서연', caption: '#잉어'),
      _post(username: '배스왕', caption: '맑은 날'),
    ];

    test('빈 쿼리는 전체 반환', () {
      expect(filterPosts(posts, '').length, 3);
    });

    test('공백만 있는 쿼리는 전체 반환', () {
      expect(filterPosts(posts, '   ').length, 3);
    });

    test('유저명 부분 일치 필터링', () {
      final r = filterPosts(posts, '민준');
      expect(r.length, 1);
      expect(r.first.username, '김민준');
    });

    test('# 포함 태그로 필터링', () {
      expect(filterPosts(posts, '#배스').length, 1);
    });

    test('# 없이 태그로 필터링 — 태그 + 유저명 모두 매칭', () {
      // 김민준(#배스 태그) + 배스왕(유저명) 둘 다 매칭
      expect(filterPosts(posts, '배스').length, 2);
    });

    test('대소문자 무시', () {
      expect(filterPosts(posts, '서연').length, 1);
    });

    test('일치하는 결과 없으면 빈 리스트', () {
      expect(filterPosts(posts, '고등어').length, 0);
    });
  });
}
```

- [ ] **Step 3: 테스트 실행 — 실패 확인**

```bash
flutter test test/features/feed/presentation/feed_search_utils_test.dart
```

예상: `Error: 'feed_search_utils.dart' doesn't exist`

- [ ] **Step 4: 유틸 파일 구현**

`lib/features/feed/presentation/utils/feed_search_utils.dart`:

```dart
import '../../data/post_model.dart';

List<String> extractHashtags(String? caption) {
  if (caption == null || caption.isEmpty) return [];
  return caption
      .split(RegExp(r'\s+'))
      .where((w) => w.startsWith('#') && w.length > 1)
      .toList();
}

List<Post> filterPosts(List<Post> posts, String query) {
  final q = query.trim().toLowerCase().replaceAll('#', '');
  if (q.isEmpty) return posts;
  return posts.where((p) {
    if (p.username.toLowerCase().contains(q)) return true;
    return extractHashtags(p.caption)
        .any((t) => t.toLowerCase().replaceAll('#', '').contains(q));
  }).toList();
}
```

- [ ] **Step 5: 테스트 실행 — 전부 통과 확인**

```bash
flutter test test/features/feed/presentation/feed_search_utils_test.dart
```

예상:
```
00:02 +8: All tests passed!
```

- [ ] **Step 6: 커밋**

```bash
git add lib/features/feed/presentation/utils/feed_search_utils.dart \
        test/features/feed/presentation/feed_search_utils_test.dart
git commit -m "feat: 피드 검색 유틸 함수 + 단위 테스트"
```

---

## Task 2: FeedScreen → ConsumerStatefulWidget 변환

**Files:**
- Modify: `lib/features/feed/presentation/screens/feed_screen.dart`

이 단계에서는 상태 변수와 핸들러만 추가한다. 기존 피드 동작은 변하지 않는다.

- [ ] **Step 1: import 추가**

`feed_screen.dart` 상단 imports 블록에 추가:

```dart
import '../utils/feed_search_utils.dart';
```

- [ ] **Step 2: FeedScreen 클래스 교체**

`feed_screen.dart`에서 아래 기존 코드를:

```dart
class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    return Scaffold(
      appBar: _FeedAppBar(isDark: context.isDark, accent: context.accentColor),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(feedPostsProvider),
        child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _FavoritesBar(isDark: context.isDark, accent: context.accentColor)),
          SliverToBoxAdapter(
            child: Divider(
              height: 0.5,
              thickness: 0.5,
              color: context.isDark ? const Color(0xFF262626) : const Color(0xFFDBDBDB),
            ),
          ),
          ref.watch(feedPostsProvider).when(
            data: (posts) {
              if (posts.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(
                    child: Text('아직 올라온 조과가 없습니다.\n첫 조과를 자랑해보세요!'),
                  ),
                );
              }
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _InstaPost(
                    post: posts[i],
                    isDark: context.isDark,
                    accent: context.accentColor,
                  ),
                  childCount: posts.length,
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, st) => SliverFillRemaining(
              child: Center(child: Text('피드를 불러오지 못했습니다.')),
            ),
          ),
        ],
        ),
      ),
    );
  }
}
```

다음으로 교체:

```dart
class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  bool _isSearching = false;
  String _searchQuery = '';
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchToggle() => setState(() => _isSearching = true);

  void _onSearchCancel() {
    setState(() {
      _isSearching = false;
      _searchQuery = '';
    });
    _searchCtrl.clear();
  }

  void _onSearchChanged(String value) => setState(() => _searchQuery = value);

  void _onSearchClear() {
    _searchCtrl.clear();
    setState(() => _searchQuery = '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _FeedAppBar(
        isDark: context.isDark,
        accent: context.accentColor,
        isSearching: _isSearching,
        searchQuery: _searchQuery,
        searchCtrl: _searchCtrl,
        onSearchToggle: _onSearchToggle,
        onSearchChanged: _onSearchChanged,
        onSearchCancel: _onSearchCancel,
        onSearchClear: _onSearchClear,
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(feedPostsProvider),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _FavoritesBar(isDark: context.isDark, accent: context.accentColor)),
            SliverToBoxAdapter(
              child: Divider(
                height: 0.5,
                thickness: 0.5,
                color: context.isDark ? const Color(0xFF262626) : const Color(0xFFDBDBDB),
              ),
            ),
            ref.watch(feedPostsProvider).when(
              data: (posts) {
                if (posts.isEmpty) {
                  return const SliverFillRemaining(
                    child: Center(
                      child: Text('아직 올라온 조과가 없습니다.\n첫 조과를 자랑해보세요!'),
                    ),
                  );
                }
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _InstaPost(
                      post: posts[i],
                      isDark: context.isDark,
                      accent: context.accentColor,
                    ),
                    childCount: posts.length,
                  ),
                );
              },
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, st) => const SliverFillRemaining(
                child: Center(child: Text('피드를 불러오지 못했습니다.')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: 컴파일 확인**

```bash
flutter analyze lib/features/feed/presentation/screens/feed_screen.dart
```

예상: `No issues found!` (또는 `_FeedAppBar` 파라미터 mismatch 에러 — Task 3에서 해결)

- [ ] **Step 4: 커밋**

```bash
git add lib/features/feed/presentation/screens/feed_screen.dart
git commit -m "refactor: FeedScreen → ConsumerStatefulWidget, 검색 상태 변수 추가"
```

---

## Task 3: _FeedAppBar 검색 UI 구현

**Files:**
- Modify: `lib/features/feed/presentation/screens/feed_screen.dart` (`_FeedAppBar` 클래스)

- [ ] **Step 1: _FeedAppBar 클래스 교체**

`feed_screen.dart`에서 기존 `_FeedAppBar` 전체를 아래로 교체:

```dart
class _FeedAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _FeedAppBar({
    required this.isDark,
    required this.accent,
    required this.isSearching,
    required this.searchQuery,
    required this.searchCtrl,
    required this.onSearchToggle,
    required this.onSearchChanged,
    required this.onSearchCancel,
    required this.onSearchClear,
  });

  final bool isDark, isSearching;
  final String searchQuery;
  final Color accent;
  final TextEditingController searchCtrl;
  final VoidCallback onSearchToggle, onSearchCancel, onSearchClear;
  final ValueChanged<String> onSearchChanged;

  @override
  Size get preferredSize => const Size.fromHeight(44);

  @override
  Widget build(BuildContext context) {
    if (isSearching) {
      return AppBar(
        toolbarHeight: 44,
        backgroundColor: isDark ? AppColors.darkBg : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 12,
        title: Row(
          children: [
            Expanded(
              child: TextField(
                controller: searchCtrl,
                autofocus: true,
                onChanged: onSearchChanged,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.black,
                ),
                decoration: InputDecoration(
                  hintText: '유저명 또는 #태그 검색...',
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: isDark ? const Color(0xFF666666) : const Color(0xFFAAAAAA),
                  ),
                  prefixIcon: Icon(LucideIcons.search, size: 18, color: accent),
                  suffixIcon: searchQuery.isNotEmpty
                      ? GestureDetector(
                          onTap: onSearchClear,
                          child: Icon(
                            LucideIcons.x,
                            size: 16,
                            color: isDark ? const Color(0xFF888888) : const Color(0xFFAAAAAA),
                          ),
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF0F0F0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  isDense: true,
                ),
                textInputAction: TextInputAction.search,
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: onSearchCancel,
              child: Text(
                '취소',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: accent,
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
      );
    }

    return AppBar(
      toolbarHeight: 44,
      backgroundColor: isDark ? AppColors.darkBg : Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      title: SvgPicture.asset(
        'assets/images/nakstar.svg',
        height: 26,
        fit: BoxFit.contain,
        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
      ),
      actions: [
        GestureDetector(
          onTap: () => context.push(AppRoutes.upload),
          child: Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            child: Icon(
              LucideIcons.plus,
              color: isDark ? Colors.black : Colors.white,
              size: 20,
            ),
          ),
        ),
        IconButton(
          onPressed: () {},
          icon: Icon(LucideIcons.heart,
              color: isDark ? Colors.white : Colors.black, size: 24),
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          onPressed: onSearchToggle,
          icon: Icon(LucideIcons.search,
              color: isDark ? Colors.white : Colors.black, size: 22),
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          onPressed: () => context.push(AppRoutes.dm),
          icon: Icon(LucideIcons.send,
              color: isDark ? Colors.white : Colors.black, size: 22),
          visualDensity: VisualDensity.compact,
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}
```

- [ ] **Step 2: 컴파일 확인**

```bash
flutter analyze lib/features/feed/presentation/screens/feed_screen.dart
```

예상: `No issues found!`

- [ ] **Step 3: 커밋**

```bash
git add lib/features/feed/presentation/screens/feed_screen.dart
git commit -m "feat: 피드 AppBar 검색 아이콘 + 검색바 UI 추가"
```

---

## Task 4: 피드 필터링 + 즐겨찾기 숨김 + 결과 배너

**Files:**
- Modify: `lib/features/feed/presentation/screens/feed_screen.dart`

- [ ] **Step 1: `_SearchResultBanner` 위젯 추가**

`feed_screen.dart`에서 `// ── AppBar ─` 주석 바로 위에 추가:

```dart
class _SearchResultBanner extends StatelessWidget {
  const _SearchResultBanner({required this.count, required this.isDark});
  final int count;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
      child: Text(
        '결과 $count개',
        style: TextStyle(
          fontSize: 12,
          color: isDark ? const Color(0xFF8E8E8E) : const Color(0xFF737373),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: `_FeedScreenState.build()` — 즐겨찾기 숨김 + 피드 필터링 적용**

`_FeedScreenState.build()` 안의 `body` 부분을 아래로 교체:

```dart
body: RefreshIndicator(
  onRefresh: () async => ref.invalidate(feedPostsProvider),
  child: CustomScrollView(
    slivers: [
      if (!_isSearching) ...[
        SliverToBoxAdapter(
          child: _FavoritesBar(isDark: context.isDark, accent: context.accentColor),
        ),
        SliverToBoxAdapter(
          child: Divider(
            height: 0.5,
            thickness: 0.5,
            color: context.isDark ? const Color(0xFF262626) : const Color(0xFFDBDBDB),
          ),
        ),
      ],
      ...ref.watch(feedPostsProvider).when(
        data: (posts) {
          final filtered = filterPosts(posts, _searchQuery);
          return [
            if (_isSearching && _searchQuery.isNotEmpty)
              SliverToBoxAdapter(
                child: _SearchResultBanner(
                  count: filtered.length,
                  isDark: context.isDark,
                ),
              ),
            if (filtered.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Text(
                    _searchQuery.isEmpty
                        ? '아직 올라온 조과가 없습니다.\n첫 조과를 자랑해보세요!'
                        : '검색 결과가 없습니다.',
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _InstaPost(
                    post: filtered[i],
                    isDark: context.isDark,
                    accent: context.accentColor,
                  ),
                  childCount: filtered.length,
                ),
              ),
          ];
        },
        loading: () => [
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
        error: (e, st) => [
          const SliverFillRemaining(
            child: Center(child: Text('피드를 불러오지 못했습니다.')),
          ),
        ],
      ),
    ],
  ),
),
```

- [ ] **Step 3: `_InstaPostState`의 `_extractHashtags` 메서드를 공용 함수로 교체**

`_InstaPostState`에서 아래 메서드를 삭제:

```dart
  /// 캡션에서 해시태그 목록 추출 (예: ['#배스', '#조황'])
  List<String> _extractHashtags(String? caption) {
    if (caption == null || caption.isEmpty) return [];
    return caption
        .split(RegExp(r'\s+'))
        .where((w) => w.startsWith('#') && w.length > 1)
        .toList();
  }
```

그리고 `_InstaPostState.build()` 안의 `_extractHashtags(p.caption)` 호출 두 곳을 `extractHashtags(p.caption)`으로 변경 (Task 1에서 import한 top-level 함수 사용):

변경 전 (2곳):
```dart
        if (_extractHashtags(p.caption).isNotEmpty)
```
```dart
              _extractHashtags(p.caption).join('  '),
```

변경 후:
```dart
        if (extractHashtags(p.caption).isNotEmpty)
```
```dart
              extractHashtags(p.caption).join('  '),
```

- [ ] **Step 4: 컴파일 + 정적 분석**

```bash
flutter analyze lib/features/feed/presentation/screens/feed_screen.dart
```

예상: `No issues found!`

- [ ] **Step 5: 전체 테스트**

```bash
flutter test
```

예상:
```
00:02 +9: All tests passed!
```

- [ ] **Step 6: 수동 검증**

앱 실행 후 아래 시나리오 확인:

1. 피드 화면 진입 → AppBar에 🔍 아이콘 보임
2. 🔍 탭 → 검색바 나타남, 즐겨찾기 바 사라짐, 키보드 자동 포커스
3. "배스" 입력 → 피드가 유저명/태그 기준으로 즉시 필터링, "결과 N개" 배너 표시
4. "#루어" 입력 → `#루어낚시` 태그가 있는 피드만 표시
5. X 버튼 탭 → 검색어만 삭제, 전체 피드 복귀 (검색 상태 유지)
6. "취소" 탭 → 검색 종료, 즐겨찾기 바 + 전체 피드 복귀
7. 검색 결과 없는 쿼리 → "검색 결과가 없습니다." 표시

- [ ] **Step 7: 최종 커밋**

```bash
git add lib/features/feed/presentation/screens/feed_screen.dart
git commit -m "feat: 피드 검색 — 인라인 필터링, 즐겨찾기 숨김, 결과 배너"
```
