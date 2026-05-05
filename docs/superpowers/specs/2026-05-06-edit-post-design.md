# 게시물 수정 기능 설계

## 개요

피드·리그 조과·개인 기록 각각에 수정 기능을 추가한다.
복잡도 최소화를 원칙으로, 케이스별로 다른 수정 범위와 UI를 적용한다.

---

## 1. 피드 수정

### 수정 가능 필드
- 사진 (교체 가능)
- 캡션 (문구 + 해시태그)
- 위치
- 길이 (cm)
- 무게 (g)

### 진입점
`PostDetailScreen` 더보기 메뉴 (`_MoreMenu`) → "수정하기"
- 조건: 본인 게시물(`isOwner`) + 피드 게시물(`leagueId == null && !isPersonalRecord`)

### UI
`UploadScreen`의 `_CaptionStep`을 edit 모드로 재사용.
- `post` 파라미터를 받으면 edit 모드로 동작
- 기존 이미지를 첫 번째 썸네일로 표시 (교체 가능)
- 텍스트 필드는 기존 값으로 pre-fill
- 버튼 텍스트: "공유" → "저장"

### 백엔드
`FeedRepository.updatePost()` 추가:
```dart
Future<void> updatePost({
  required String postId,
  File? newImageFile,       // null이면 이미지 유지
  List<File>? newImageFiles,
  String? caption,
  String? location,
  double? length,
  double? weight,
})
```
- 이미지 변경 시: 새 이미지 업로드 → `image_url`, `image_urls` 업데이트
- `is_lunker`, `score` 재계산 (length 기준)
- `review_status` 변경 없음 (피드는 항상 approved)

### 캐시 무효화
`feedPostsProvider`, `myPostsProvider`

---

## 2. 리그 조과 수정

### 수정 가능 필드
- 메모 (caption)만

### 진입점
`LeagueParticipantDetailScreen`의 `_CatchCard` 사진 우측 상단 `...` 아이콘 버튼
- 조건: 본인 조과(`isMyPost`)에만 표시
- 탭 시 바텀시트로 액션 선택:
  - **수정하기** → 메모 수정 바텀시트
  - **피드에 공유**
  - **사진 저장**
  - **삭제**
- 기존 카드 하단 버튼 행(피드에 공유 | 사진 저장 | 삭제) 제거

### UI
```
┌─────────────────────────┐
│ [사진]              [⋯] │  ← 본인 조과에만 표시
│                         │
│ 배스  42.5cm  인증      │
│ 2026.05.06 14:32        │
│ 조과 메모...            │
└─────────────────────────┘
```

`...` 탭 시 액션 바텀시트:
```
수정하기
피드에 공유
사진 저장
삭제
```

수정하기 탭 시 메모 수정 바텀시트:
```
┌─────────────────────────────┐
│  수정하기          [저장]   │
│─────────────────────────────│
│  메모                       │
│  [ 조과 상황...           ] │
└─────────────────────────────┘
```
- 기존 caption pre-fill
- 저장 버튼 탭 시 바로 업데이트

### 백엔드
`FeedRepository.updatePostMeta()` 추가:
```dart
Future<void> updatePostMeta({
  required String postId,
  String? caption,
  String? location,
})
```
단순 `update` 쿼리:
```sql
UPDATE posts SET caption = ?, location = ? WHERE id = ?
```

### 캐시 무효화
`feedPostsProvider`, `leagueRankingProvider(leagueId)`, `leagueDetailProvider(leagueId)`

---

## 3. 개인 기록 수정

### 수정 가능 필드
- 장소 (location)
- 메모 (caption)

### 진입점
`PersonalRecordDetailScreen` 앱바 `...` 메뉴 → "수정하기"

### UI
바텀시트 (새 화면 없음):
```
┌─────────────────────────────┐
│  수정하기          [저장]   │
│─────────────────────────────│
│  장소                       │
│  [ 충주호...              ] │
│                             │
│  메모                       │
│  [ 조과 상황...           ] │
└─────────────────────────────┘
```
- 기존 location, caption pre-fill
- 저장 버튼 탭 시 바로 업데이트

### 백엔드
`FeedRepository.updatePostMeta()` 동일 메서드 재사용

### 캐시 무효화
`myPersonalRecordsProvider`, `myProfileProvider`

---

## 공통 사항

### 추가할 Repository 메서드
| 메서드 | 용도 |
|--------|------|
| `updatePost()` | 피드 전체 수정 (이미지·텍스트) |
| `updatePostMeta()` | 리그·개인기록 메타 수정 (caption·location만) |

### 수정하지 않는 것
- 리그 조과: 사진, 길이/무게, review_status
- 개인 기록: 사진, 길이, review_status (인증 상태 유지)

### 라우팅
- 피드 수정: `UploadScreen`을 `post` extra로 push (fullscreenDialog)
- 리그/개인기록 수정: 바텀시트이므로 라우터 변경 불필요
