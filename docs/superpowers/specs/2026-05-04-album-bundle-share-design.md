# 조과 앨범 묶음 피드 공유 기능 설계

## 개요

개인 기록 탭의 조과 앨범에서 사진을 여러 장 선택해 하나의 피드 포스트(캐러셀)로 공유하는 기능.

## 범위

- 진입: 나의 리그 → 개인 기록 탭 → 조과 앨범
- 출력: 일반 피드에 다중 이미지 포스트 (기존 PostImageCarousel로 표시)
- 최대 선택: 5장

---

## UI & 상태 관리

### 선택 모드 진입
- "내 조과 앨범 N장" 텍스트 우측에 **"선택" / "취소"** 텍스트 버튼 추가
- `_PersonalRecordTab`을 `ConsumerStatefulWidget`으로 변환
- 내부 상태:
  - `bool _selectMode` — 선택 모드 여부
  - `Set<String> _selectedIds` — 선택된 Post.id 집합

### 그리드 아이템 동작
| 상태 | 탭 동작 | 시각 표시 |
|---|---|---|
| 선택 모드 OFF | 상세 화면 이동 (기존) | 변화 없음 |
| 선택 모드 ON, 미선택 | 선택 | 기본 |
| 선택 모드 ON, 선택됨 | 선택 해제 | 파란 오버레이 + 체크 아이콘 (우상단) |
| 선택 모드 ON, 5장 도달 시 미선택 | 탭 불가 | dimmed 처리 |

### 하단 버튼 영역
| 상태 | 표시 |
|---|---|
| 선택 모드 OFF | 기존 "앨범" + "사진 촬영하기" 버튼 |
| 선택 모드 ON, 0장 | "피드에 공유하기" 버튼 (비활성) |
| 선택 모드 ON, 1장 이상 | "N장 선택됨 · 피드에 공유하기" 버튼 (활성) |

---

## 데이터 흐름

### 캡션 입력 Bottom Sheet
"피드에 공유하기" 탭 시 표시:
1. 선택된 사진 썸네일 가로 스크롤 미리보기 (최대 5장)
2. 캡션 텍스트필드 (선택 입력)
3. "공유하기" 확인 버튼

### 새 Repository 메서드
```dart
// feed_repository.dart
Future<void> shareMultiplePostsToFeed(List<Post> posts, String? caption) async {
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
    'location': first.location,
    'league_id': null,
    'is_personal_record': false,
    'length': first.length,
    'weight': first.weight,
    'catch_count': posts.length,
    'is_lunker': first.isLunker,
  });
}
```

- 이미지 재업로드 없음 — 기존 Storage URL 직접 참조
- `imageUrl`: 첫 번째 사진 URL (하위 호환용 단일 필드)
- `imageUrls`: 선택된 모든 사진 URL 배열
- `catch_count`: 선택된 사진 수 (묶음 마릿수로 사용)
- 나머지 메타데이터(fish_type, length 등): 첫 번째 선택 사진 기준

### 공유 완료 후 처리
- `ref.invalidate(feedPostsProvider)`
- `ref.invalidate(myPostsProvider)`
- 선택 모드 자동 해제 (`_selectMode = false`, `_selectedIds.clear()`)
- 스낵바: "피드에 공유되었습니다 🎣"

---

## 피드 표시

`PostImageCarousel`이 `imageUrls`를 이미 처리하므로 **추가 수정 없음**.
- 2장 이상 → PageView 캐러셀 자동 활성화
- 우상단 "1 / N" 카운터 뱃지
- 하단 dot 인디케이터

---

## 변경 파일 목록

| 파일 | 변경 내용 |
|---|---|
| `lib/features/my_league/presentation/screens/my_league_screen.dart` | `_PersonalRecordTab` StatefulWidget 전환, 선택 모드 UI 및 캡션 Bottom Sheet |
| `lib/features/feed/data/feed_repository.dart` | `shareMultiplePostsToFeed()` 메서드 추가 |

### 변경 불필요 파일
- `post_model.dart` — 수정 없음
- `post_image_carousel.dart` — 수정 없음
- `feed_screen.dart` — 수정 없음
- DB 스키마 — 수정 없음

---

## 제약 조건

- 최대 선택: 5장 (초과 시 미선택 아이템 dimmed + 탭 불가)
- 선택 순서대로 `imageUrls` 배열에 저장 (캐러셀 표시 순서 결정)
- 캡션은 선택 입력 (빈 값 허용)
