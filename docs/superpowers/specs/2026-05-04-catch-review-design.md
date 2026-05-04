# 조과 심사 기능 설계

**날짜**: 2026-05-04  
**기능**: 리그 개설자의 조과 보류/해지 심사

---

## 개요

진행 중 리그에서 개설자가 참가자의 조과 사진을 검토하고, 규칙에 맞지 않는 조과를 보류 처리하여 점수에서 제외할 수 있는 기능.

**핵심 원칙**:
- 기본적으로 모든 조과는 점수에 반영됨 (자동 승인)
- 개설자가 문제 있는 조과만 선택적으로 보류
- 보류 해지로 언제든 복원 가능
- 알림 없음, 보류 이유 입력 없음
- 참가자는 본인 사진에 보류 마크로 확인 가능

---

## DB 변경

### Migration (새 파일)

```sql
ALTER TABLE posts
  ADD COLUMN review_status TEXT NOT NULL DEFAULT 'approved'
  CHECK (review_status IN ('approved', 'held'));

CREATE INDEX idx_posts_league_review
  ON posts(league_id, review_status, score DESC)
  WHERE league_id IS NOT NULL;
```

### RLS 정책 추가

```sql
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

---

## 데이터 모델

### PostModel

`review_status` 필드 추가:

```dart
final String reviewStatus; // 'approved' | 'held'

// fromJson
reviewStatus: json['review_status'] as String? ?? 'approved',

// toJson
'review_status': reviewStatus,
```

---

## Repository

### LeagueRepository — 추가 메서드

```dart
// 심사 탭용: 리그 전체 조과 최신순
Future<List<PostModel>> getLeagueCatchesForReview(String leagueId) async {
  final data = await supabase
      .from('posts')
      .select('id, user_id, league_id, image_url, fish_type, length, weight, score, review_status, created_at, username, avatar_url')
      .eq('league_id', leagueId)
      .eq('is_deleted', false)
      .order('created_at', ascending: false);
  return data.map(PostModel.fromJson).toList();
}

// 보류
Future<void> holdPost(String postId) async {
  await supabase
      .from('posts')
      .update({'review_status': 'held'})
      .eq('id', postId);
}

// 보류 해지
Future<void> unholdPost(String postId) async {
  await supabase
      .from('posts')
      .update({'review_status': 'approved'})
      .eq('id', postId);
}
```

### 기존 랭킹 쿼리 수정

`LeagueRepository.getLeagueRanking()` 및 `RankingRepository` 관련 쿼리에 조건 추가:

```dart
.eq('review_status', 'approved')  // 보류 조과 랭킹 제외
```

---

## Provider

### CatchReviewProvider (신규)

```dart
class CatchReviewProvider extends ChangeNotifier {
  final LeagueRepository _repo;

  List<PostModel> posts = [];
  bool isLoading = false;
  String? error;

  Future<void> load(String leagueId) async { ... }

  Future<void> holdPost(String postId) async {
    // Supabase 업데이트
    await _repo.holdPost(postId);
    // 로컬 상태 즉시 반영 (리로드 없이)
    final idx = posts.indexWhere((p) => p.id == postId);
    if (idx != -1) {
      posts[idx] = posts[idx].copyWith(reviewStatus: 'held');
      notifyListeners();
    }
  }

  Future<void> unholdPost(String postId) async {
    await _repo.unholdPost(postId);
    final idx = posts.indexWhere((p) => p.id == postId);
    if (idx != -1) {
      posts[idx] = posts[idx].copyWith(reviewStatus: 'approved');
      notifyListeners();
    }
  }
}
```

---

## UI

### LeagueDetailPage

개설자(`hostId == currentUserId`)일 때만 "심사" 탭 추가:

```dart
if (isHost) ...[
  const Tab(text: '심사'),
  CatchReviewTab(leagueId: leagueId),
]
```

### CatchReviewTab (신규 위젯)

`CatchReviewProvider`를 구독하는 ListView.  
`load(leagueId)` 호출로 초기 데이터 로드.

### CatchReviewItem (신규 위젯)

한 행 구성:
```
[사진 썸네일 60×60] [참가자명 · 길이 · 점수] [보류 or 해지 버튼]
```

| 상태 | 스타일 | 버튼 |
|------|--------|------|
| approved | 정상 | 회색 "보류" 버튼 |
| held | opacity 0.5 + 흐림 | 빨간 "해지" 버튼 |

### PostCard (기존 위젯 수정)

본인 조과가 보류 중일 때 사진 위 오버레이 뱃지 표시:

```dart
if (post.reviewStatus == 'held' && post.userId == currentUserId)
  Positioned(
    top: 8, right: 8,
    child: HoldBadge(), // "보류" 반투명 뱃지
  )
```

---

## 파일 변경 목록

| 파일 | 변경 |
|------|------|
| `supabase/migrations/20260504_add_review_status.sql` | 신규 |
| `lib/features/feed/data/post_model.dart` | `reviewStatus` 필드 추가 |
| `lib/features/league/data/league_repository.dart` | 심사 메서드 3개 추가, 랭킹 쿼리 수정 |
| `lib/features/ranking/data/ranking_repository.dart` | 랭킹 쿼리 수정 |
| `lib/features/league/presentation/providers/catch_review_provider.dart` | 신규 |
| `lib/features/league/presentation/widgets/catch_review_tab.dart` | 신규 |
| `lib/features/league/presentation/widgets/catch_review_item.dart` | 신규 |
| `lib/features/league/presentation/screens/league_detail_screen.dart` | 심사 탭 조건부 추가 |
| `lib/features/feed/presentation/widgets/post_card.dart` | 보류 뱃지 조건부 추가 |
