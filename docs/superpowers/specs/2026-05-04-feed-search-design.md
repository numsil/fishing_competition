# 피드 검색 기능 설계

**날짜**: 2026-05-04  
**대상 파일**: `lib/features/feed/presentation/screens/feed_screen.dart` (단독)

---

## 요구사항

피드 홈화면에서 **등록 유저명** 또는 **캡션 내 해시태그**로 피드를 검색한다.

---

## UX 플로우

### 상태 전환

| 상태 | 트리거 | UI |
|------|--------|-----|
| 기본 | — | AppBar 로고 + 🔍 아이콘 + 즐겨찾기 바 + 전체 피드 |
| 검색 활성 | 🔍 탭 | AppBar 전체를 검색바가 차지, 즐겨찾기 바 숨김 |
| 결과 표시 | 타이핑 | 필터된 피드 인라인 표시, 결과 수 카운트 |
| 검색 종료 | "취소" 탭 or X | 기본 상태로 복귀 (즐겨찾기 바 + 전체 피드) |

### 검색 진입
- AppBar 우측에 `LucideIcons.search` 아이콘 추가 (기존 ♡, ✉ 사이)
- 탭 시 `_isSearching = true` → AppBar가 검색바로 전환, 즐겨찾기 바 숨김
- 키보드 자동 포커스

### 검색 실행
- 실시간 클라이언트 사이드 필터링 (Supabase 쿼리 없음)
- 필터 조건:
  - `post.username.toLowerCase().contains(query)` — 유저명 부분 일치
  - `post.caption` 내 `#태그` 추출 후 `tag.contains(query)` — 태그 부분 일치 (# 포함/미포함 모두 허용)
- 쿼리가 빈 문자열이면 전체 피드 표시

### 검색 종료
- "취소" 버튼 탭 → `_isSearching = false`, `_searchQuery = ''`, 키보드 닫기
- X 버튼으로 쿼리만 지우기 (검색 상태 유지)

---

## 아키텍처

### 상태 변수 (FeedScreen 로컬)

```dart
bool _isSearching = false;
String _searchQuery = '';
final TextEditingController _searchCtrl = TextEditingController();
```

`feedPostsProvider`는 변경하지 않는다. 기존 캐시(5분 TTL)를 그대로 사용.

### 필터 함수

```dart
List<Post> _filterPosts(List<Post> posts, String query) {
  if (query.isEmpty) return posts;
  final q = query.toLowerCase().replaceFirst('#', '');
  return posts.where((p) {
    final nameMatch = p.username.toLowerCase().contains(q);
    final tags = _extractHashtags(p.caption);
    final tagMatch = tags.any((t) => t.toLowerCase().replaceFirst('#', '').contains(q));
    return nameMatch || tagMatch;
  }).toList();
}
```

`_extractHashtags`는 이미 `_InstaPostState`에 존재 → 공용 함수로 끌어올림.

### UI 구조 변경

- `_FeedAppBar` → `_isSearching` 상태에 따라 두 가지 레이아웃 렌더링
  - `false`: 기존 로고 + 아이콘 행
  - `true`: 검색바 (TextField) + "취소" 버튼
- `_FavoritesBar` → `_isSearching == true`이면 렌더링 안 함
- 피드 리스트 → `_filterPosts(posts, _searchQuery)` 결과로 렌더링
- 결과 카운트 배너 → 쿼리가 있을 때 피드 상단에 `"결과 N개"` 표시

---

## 제약사항

- Supabase 쿼리 추가 없음 — 클라이언트 필터링만
- `feed_screen.dart` 단 1개 파일만 수정
- 기존 `feedPostsProvider` 캐시 유지 (캐시 무효화 없음)
- `posts.league_id == null` 조건은 기존 repository가 이미 처리 (변경 없음)
