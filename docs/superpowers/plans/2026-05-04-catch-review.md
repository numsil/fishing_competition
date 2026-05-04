# 조과 심사 기능 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 리그 개설자가 "심사" 탭에서 참가자 조과를 보류/해지 처리하고, 보류된 조과는 랭킹 점수에서 제외되며, 참가자 본인 화면에 보류 뱃지가 표시된다.

**Architecture:** `posts.review_status` 컬럼('approved'|'held')으로 상태 관리. 랭킹 쿼리에 `review_status = 'approved'` 조건 추가. UI → `leagueRepositoryProvider` 직접 호출로 hold/unhold, 완료 후 provider invalidate.

**Tech Stack:** Flutter, Riverpod (riverpod_annotation + FutureProvider.family), Freezed, Supabase, CachedNetworkImage

---

## File Map

| 파일 | 역할 |
|------|------|
| `supabase/migrations/20260504120000_add_review_status_to_posts.sql` | 신규 — `review_status` 컬럼 + 인덱스 + RLS |
| `lib/features/feed/data/post_model.dart` | 수정 — `reviewStatus` 필드 추가 |
| `lib/features/league/data/league_repository.dart` | 수정 — 심사 메서드 3개 + provider + 랭킹 쿼리 수정 |
| `lib/features/league/presentation/widgets/catch_review_item.dart` | 신규 — 조과 1행 (사진+정보+버튼) |
| `lib/features/league/presentation/widgets/catch_review_tab.dart` | 신규 — 심사 탭 컨텐츠 |
| `lib/features/league/presentation/screens/league_detail_screen.dart` | 수정 — 심사 탭 조건부 추가 |
| `lib/features/league/presentation/screens/league_participant_detail_screen.dart` | 수정 — `_CatchCard`에 보류 뱃지 추가 |

---

### Task 1: Migration — `review_status` 컬럼 추가

**Files:**
- Create: `supabase/migrations/20260504120000_add_review_status_to_posts.sql`

- [ ] **Step 1: 마이그레이션 파일 작성**

```sql
-- supabase/migrations/20260504120000_add_review_status_to_posts.sql

ALTER TABLE posts
  ADD COLUMN IF NOT EXISTS review_status TEXT NOT NULL DEFAULT 'approved'
  CHECK (review_status IN ('approved', 'held'));

-- 랭킹 쿼리 성능 인덱스 (league_id + review_status + score)
CREATE INDEX IF NOT EXISTS idx_posts_league_review
  ON posts(league_id, review_status, score DESC)
  WHERE league_id IS NOT NULL;

-- 리그 개설자만 review_status 변경 가능
CREATE POLICY "league host can update review_status"
  ON posts FOR UPDATE
  USING (
    league_id IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM leagues
      WHERE id = posts.league_id AND host_id = auth.uid()
    )
  )
  WITH CHECK (true);
```

- [ ] **Step 2: 마이그레이션 적용**

```bash
supabase db push
```

성공 시: `Applied X migrations` 출력.
실패 시 (`relation "posts" does not exist` 등): 로컬 Supabase가 실행 중인지 확인 — `supabase start`.

- [ ] **Step 3: 컬럼 확인**

```bash
supabase db diff
```

출력에 `review_status` 관련 diff가 없으면 정상 적용된 것.

- [ ] **Step 4: 커밋**

```bash
git add supabase/migrations/20260504120000_add_review_status_to_posts.sql
git commit -m "feat: posts 테이블에 review_status 컬럼 추가"
```

---

### Task 2: PostModel — `reviewStatus` 필드 추가

**Files:**
- Modify: `lib/features/feed/data/post_model.dart`

- [ ] **Step 1: `reviewStatus` 필드 추가**

`lib/features/feed/data/post_model.dart`에서 `@Default(0) int score,` 다음 줄에 추가:

```dart
@JsonKey(name: 'review_status') @Default('approved') String reviewStatus,
```

파일 전체에서 `score` 필드 아래 삽입:

```dart
// 변경 전 (score 필드 이후):
    @Default(0) int score,
    @JsonKey(name: 'created_at') required DateTime createdAt,

// 변경 후:
    @Default(0) int score,
    @JsonKey(name: 'review_status') @Default('approved') String reviewStatus,
    @JsonKey(name: 'created_at') required DateTime createdAt,
```

- [ ] **Step 2: 코드 생성**

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

예상 출력: `[INFO] Succeeded after ...` — `post_model.freezed.dart`, `post_model.g.dart` 재생성됨.

- [ ] **Step 3: 빌드 확인**

```bash
flutter analyze lib/features/feed/data/post_model.dart
```

에러 없어야 함.

- [ ] **Step 4: 커밋**

```bash
git add lib/features/feed/data/post_model.dart \
        lib/features/feed/data/post_model.freezed.dart \
        lib/features/feed/data/post_model.g.dart
git commit -m "feat: PostModel에 reviewStatus 필드 추가"
```

---

### Task 3: LeagueRepository — 심사 메서드 + 랭킹 쿼리 수정

**Files:**
- Modify: `lib/features/league/data/league_repository.dart:319-336, 200-228, 488-542`

- [ ] **Step 1: `getLeagueCatchesForReview` 메서드 추가**

`league_repository.dart`에서 `getUserLeaguePosts` 메서드(line 319) 바로 위에 삽입:

```dart
  // ── 심사 탭용: 리그 전체 조과 최신순 ──────────────────────
  Future<List<Post>> getLeagueCatchesForReview(String leagueId) async {
    final data = await _supabase
        .from('posts')
        .select('id, user_id, league_id, image_url, image_urls, aspect_ratio, fish_type, length, weight, score, review_status, created_at, users(username, avatar_url)')
        .eq('league_id', leagueId)
        .eq('is_deleted', false)
        .order('created_at', ascending: false);

    return data.map<Post>((d) {
      final user = d['users'] as Map?;
      return Post.fromJson(d).copyWith(
        username: user?['username'] as String? ?? '알 수 없음',
        avatarUrl: user?['avatar_url'] as String? ?? '',
      );
    }).toList();
  }

  // ── 조과 보류 ──────────────────────────────────────────────
  Future<void> holdPost(String postId) async {
    await _supabase
        .from('posts')
        .update({'review_status': 'held'})
        .eq('id', postId);
  }

  // ── 보류 해지 ──────────────────────────────────────────────
  Future<void> unholdPost(String postId) async {
    await _supabase
        .from('posts')
        .update({'review_status': 'approved'})
        .eq('id', postId);
  }
```

- [ ] **Step 2: `getLeagueRanking` 랭킹 쿼리에 보류 필터 추가**

`getLeagueRanking` 메서드 내 posts 쿼리(line 221-226)를 수정:

```dart
// 변경 전:
    final posts = await _supabase
        .from('posts')
        .select('user_id, length, weight, score, fish_type, is_lunker')
        .eq('league_id', leagueId)
        .eq('is_deleted', false);

// 변경 후:
    final posts = await _supabase
        .from('posts')
        .select('user_id, length, weight, score, fish_type, is_lunker')
        .eq('league_id', leagueId)
        .eq('is_deleted', false)
        .eq('review_status', 'approved');
```

- [ ] **Step 3: `leagueCatchesForReviewProvider` 추가**

파일 하단 provider 목록(line 542 이후)에 추가:

```dart
// 심사 탭용: 리그 전체 조과
final leagueCatchesForReviewProvider = FutureProvider.family<List<Post>, String>(
  (ref, leagueId) => ref.watch(leagueRepositoryProvider).getLeagueCatchesForReview(leagueId),
);
```

- [ ] **Step 4: 빌드 확인**

```bash
flutter analyze lib/features/league/data/league_repository.dart
```

에러 없어야 함.

- [ ] **Step 5: 커밋**

```bash
git add lib/features/league/data/league_repository.dart
git commit -m "feat: 조과 보류/해지 메서드 + 랭킹 쿼리 review_status 필터 추가"
```

---

### Task 4: CatchReviewItem 위젯 — 조과 한 행

**Files:**
- Create: `lib/features/league/presentation/widgets/catch_review_item.dart`

- [ ] **Step 1: 위젯 파일 작성**

```dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../feed/data/post_model.dart';

class CatchReviewItem extends StatelessWidget {
  const CatchReviewItem({
    super.key,
    required this.post,
    required this.isDark,
    required this.onHold,
    required this.onUnhold,
  });

  final Post post;
  final bool isDark;
  final VoidCallback onHold;
  final VoidCallback onUnhold;

  bool get _isHeld => post.reviewStatus == 'held';

  @override
  Widget build(BuildContext context) {
    final sub = isDark ? AppColors.darkTextSub : AppColors.lightTextSub;
    final surface = isDark ? AppColors.darkSurface : Colors.white;
    final divColor = isDark ? AppColors.darkDivider : AppColors.lightDivider;

    return Opacity(
      opacity: _isHeld ? 0.5 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isHeld ? AppColors.error.withValues(alpha: 0.4) : divColor,
          ),
        ),
        child: Row(
          children: [
            // 썸네일
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 60,
                height: 60,
                child: CachedNetworkImage(
                  imageUrl: post.imageUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    color: isDark ? AppColors.darkSurface2 : AppColors.lightDivider,
                    child: const Icon(Icons.image_not_supported_outlined,
                        color: Colors.grey, size: 20),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // 조과 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.username,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _measureText(),
                    style: TextStyle(fontSize: 12, color: sub),
                  ),
                  if (_isHeld)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '보류 중',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // 보류 / 해지 버튼
            GestureDetector(
              onTap: _isHeld ? onUnhold : onHold,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: _isHeld
                      ? AppColors.error.withValues(alpha: 0.15)
                      : (isDark ? AppColors.darkSurface2 : const Color(0xFFF0F0F0)),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isHeld ? AppColors.error : divColor,
                  ),
                ),
                child: Text(
                  _isHeld ? '해지' : '보류',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _isHeld ? AppColors.error : sub,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _measureText() {
    final parts = <String>[];
    if (post.length != null) parts.add('${post.length!.toStringAsFixed(0)}cm');
    if (post.weight != null) parts.add('${post.weight!.toStringAsFixed(0)}g');
    parts.add('${post.score}점');
    return parts.join(' · ');
  }
}
```

- [ ] **Step 2: 빌드 확인**

```bash
flutter analyze lib/features/league/presentation/widgets/catch_review_item.dart
```

에러 없어야 함.

- [ ] **Step 3: 커밋**

```bash
git add lib/features/league/presentation/widgets/catch_review_item.dart
git commit -m "feat: CatchReviewItem 위젯 추가"
```

---

### Task 5: CatchReviewTab 위젯 — 심사 탭 컨텐츠

**Files:**
- Create: `lib/features/league/presentation/widgets/catch_review_tab.dart`

- [ ] **Step 1: 위젯 파일 작성**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/extensions/theme_extensions.dart';
import '../../data/league_repository.dart';
import 'catch_review_item.dart';

class CatchReviewTab extends ConsumerWidget {
  const CatchReviewTab({super.key, required this.leagueId});
  final String leagueId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = context.isDark;
    final postsAsync = ref.watch(leagueCatchesForReviewProvider(leagueId));

    return postsAsync.when(
      data: (posts) {
        if (posts.isEmpty) {
          return Center(
            child: Text(
              '등록된 조과가 없습니다',
              style: TextStyle(
                color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return CatchReviewItem(
              post: post,
              isDark: isDark,
              onHold: () async {
                try {
                  await ref.read(leagueRepositoryProvider).holdPost(post.id);
                  ref.invalidate(leagueCatchesForReviewProvider(leagueId));
                  ref.invalidate(leagueRankingProvider(leagueId));
                } catch (e) {
                  if (context.mounted) {
                    AppSnackBar.error(context, '보류 처리 실패: $e');
                  }
                }
              },
              onUnhold: () async {
                try {
                  await ref.read(leagueRepositoryProvider).unholdPost(post.id);
                  ref.invalidate(leagueCatchesForReviewProvider(leagueId));
                  ref.invalidate(leagueRankingProvider(leagueId));
                } catch (e) {
                  if (context.mounted) {
                    AppSnackBar.error(context, '보류 해지 실패: $e');
                  }
                }
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('불러오기 실패: $e')),
    );
  }
}
```

- [ ] **Step 2: 빌드 확인**

```bash
flutter analyze lib/features/league/presentation/widgets/catch_review_tab.dart
```

에러 없어야 함.

- [ ] **Step 3: 커밋**

```bash
git add lib/features/league/presentation/widgets/catch_review_tab.dart
git commit -m "feat: CatchReviewTab 위젯 추가"
```

---

### Task 6: LeagueDetailScreen — 심사 탭 조건부 추가

**Files:**
- Modify: `lib/features/league/presentation/screens/league_detail_screen.dart`

현재 탭은 `_hasTabs`(status가 in_progress 또는 completed) 일 때 항상 2개. 개설자이면서 `in_progress` 상태일 때만 "심사" 탭을 3번째로 추가한다.

- [ ] **Step 1: import 추가**

파일 상단 import 목록에 추가:

```dart
import '../../../auth/data/auth_repository.dart';
import '../widgets/catch_review_tab.dart';
```

- [ ] **Step 2: `_isHost` 게터 + `_tabLength` 게터 추가**

`_LeagueDetailBodyState` 클래스에서 `_hasTabs` 게터 아래에 추가:

```dart
  bool get _isHost =>
      ref.read(currentUserProvider)?.id == widget.league.hostId;

  int get _tabLength =>
      _isHost && widget.league.status == 'in_progress' ? 3 : 2;
```

- [ ] **Step 3: TabController length를 `_tabLength`로 변경**

`initState`와 `didUpdateWidget` 두 곳에서 `TabController(length: 2, ...)` → `TabController(length: _tabLength, ...)`:

```dart
// initState 수정 전:
    if (_hasTabs) {
      _tab = TabController(length: 2, vsync: this);
    }

// initState 수정 후:
    if (_hasTabs) {
      _tab = TabController(length: _tabLength, vsync: this);
    }
```

```dart
// didUpdateWidget 수정 전:
      _tab = _hasTabs ? TabController(length: 2, vsync: this) : null;

// didUpdateWidget 수정 후:
      _tab = _hasTabs ? TabController(length: _tabLength, vsync: this) : null;
```

- [ ] **Step 4: TabBar에 "심사" 탭 조건부 추가**

`SliverPersistentHeader`의 `TabBar` 수정:

```dart
// 변경 전:
                  tabs: [
                    Tab(text: league.status == 'completed' ? '최종 순위' : '실시간 순위'),
                    const Tab(text: '대회 정보'),
                  ],

// 변경 후:
                  tabs: [
                    Tab(text: league.status == 'completed' ? '최종 순위' : '실시간 순위'),
                    if (_isHost && league.status == 'in_progress')
                      const Tab(text: '심사'),
                    const Tab(text: '대회 정보'),
                  ],
```

- [ ] **Step 5: TabBarView에 `CatchReviewTab` 조건부 추가**

```dart
// 변경 전:
              children: [
                _RankingTab(league: league, isDark: isDark, accent: accent),
                _InfoTab(league: league, isDark: isDark, accent: accent),
              ],

// 변경 후:
              children: [
                _RankingTab(league: league, isDark: isDark, accent: accent),
                if (_isHost && league.status == 'in_progress')
                  CatchReviewTab(leagueId: league.id),
                _InfoTab(league: league, isDark: isDark, accent: accent),
              ],
```

- [ ] **Step 6: 빌드 확인**

```bash
flutter analyze lib/features/league/presentation/screens/league_detail_screen.dart
```

에러 없어야 함.

- [ ] **Step 7: 커밋**

```bash
git add lib/features/league/presentation/screens/league_detail_screen.dart
git commit -m "feat: 리그 상세 화면에 심사 탭 추가 (개설자 + 진행 중 시만 표시)"
```

---

### Task 7: _CatchCard — 보류 뱃지 추가

**Files:**
- Modify: `lib/features/league/presentation/screens/league_participant_detail_screen.dart:377-396`

`_CatchCard` 위젯의 사진 영역(`ClipRRect`)을 `Stack`으로 감싸 보류 뱃지 오버레이 추가. `isMyPost == true && post.reviewStatus == 'held'` 일 때만 표시.

- [ ] **Step 1: 사진 영역을 Stack으로 감싸기**

`_CatchCard.build()`에서 `ClipRRect`(사진 부분)를 `Stack`으로 교체:

```dart
// 변경 전:
            // ── 사진 ───────────────────────────────────
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(13)),
              child: AspectRatio(
                aspectRatio: (post.aspectRatio ?? (4 / 3)).clamp(0.8, 1.91),
                child: CachedNetworkImage(
                  imageUrl: post.imageUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    color: isDark
                        ? AppColors.darkSurface2
                        : AppColors.lightDivider,
                    child: const Center(
                      child: Icon(Icons.image_not_supported_outlined,
                          color: Colors.grey),
                    ),
                  ),
                ),
              ),
            ),

// 변경 후:
            // ── 사진 ───────────────────────────────────
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(13)),
                  child: AspectRatio(
                    aspectRatio: (post.aspectRatio ?? (4 / 3)).clamp(0.8, 1.91),
                    child: CachedNetworkImage(
                      imageUrl: post.imageUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        color: isDark
                            ? AppColors.darkSurface2
                            : AppColors.lightDivider,
                        child: const Center(
                          child: Icon(Icons.image_not_supported_outlined,
                              color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                ),
                if (isMyPost && post.reviewStatus == 'held')
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '보류',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
```

- [ ] **Step 2: 빌드 확인**

```bash
flutter analyze lib/features/league/presentation/screens/league_participant_detail_screen.dart
```

에러 없어야 함.

- [ ] **Step 3: 커밋**

```bash
git add lib/features/league/presentation/screens/league_participant_detail_screen.dart
git commit -m "feat: 본인 조과에 보류 뱃지 표시"
```

---

### Task 8: 전체 빌드 & 수동 테스트

- [ ] **Step 1: 전체 분석**

```bash
flutter analyze
```

에러 없어야 함. (warning은 무시 가능)

- [ ] **Step 2: 앱 실행**

```bash
flutter run
```

- [ ] **Step 3: 개설자 계정으로 심사 탭 확인**

1. 진행 중(`in_progress`) 리그 상세 페이지 진입
2. 탭 목록에 "심사"가 보이는지 확인 (개설자 계정에서만)
3. "심사" 탭에 참가자 조과 목록이 최신순으로 나오는지 확인

- [ ] **Step 4: 보류 처리 확인**

1. 조과 오른쪽 "보류" 버튼 탭
2. 해당 행이 흐려지고 "해지" 버튼으로 바뀌는지 확인
3. "실시간 순위" 탭으로 이동해서 해당 유저 점수가 낮아졌는지 확인

- [ ] **Step 5: 보류 해지 확인**

1. 보류된 조과의 "해지" 버튼 탭
2. 행이 정상으로 돌아오고 "보류" 버튼으로 바뀌는지 확인
3. 랭킹 점수가 복원됐는지 확인

- [ ] **Step 6: 참가자 보류 뱃지 확인**

1. 참가자 계정으로 로그인
2. 랭킹 탭에서 본인 이름 탭 → 참가자 상세 화면
3. 보류된 조과 사진에 빨간 "보류" 뱃지가 표시되는지 확인

- [ ] **Step 7: 비개설자 계정 확인**

1. 참가자 계정으로 같은 리그 상세 진입
2. "심사" 탭이 없는지 확인
