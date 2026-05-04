# 조과 앨범 묶음 피드 공유 기능 설계

## 개요

개인 기록 탭의 조과 앨범에서 사진을 여러 장 선택해 하나의 피드 포스트(캐러셀)로 공유하는 기능.
선택 후 피드 등록 전용 화면에서 문구, 위치, 길이/무게, 리그 태그를 작성한 뒤 공유한다.

## 범위

- 진입: 나의 리그 → 개인 기록 탭 → 조과 앨범
- 출력: 일반 피드에 다중 이미지 포스트 (기존 PostImageCarousel로 표시)
- 최대 선택: 5장

---

## 1. UI & 상태 관리 (조과 앨범 선택 모드)

### 선택 모드 진입
- "내 조과 앨범 N장" 텍스트 우측에 **"선택" / "취소"** 텍스트 버튼 추가
- `_PersonalRecordTab`을 `ConsumerStatefulWidget`으로 변환
- 내부 상태:
  - `bool _selectMode` — 선택 모드 여부
  - `Set<String> _selectedIds` — 선택된 Post.id 집합
  - `List<Post> _orderedSelected` — 선택 순서 보존용 리스트

### 그리드 아이템 동작
| 상태 | 탭 동작 | 시각 표시 |
|---|---|---|
| 선택 모드 OFF | 상세 화면 이동 (기존) | 변화 없음 |
| 선택 모드 ON, 미선택 | 선택 추가 | 기본 |
| 선택 모드 ON, 선택됨 | 선택 해제 | 파란 오버레이 + 우상단 체크 아이콘 + 선택 순번 |
| 선택 모드 ON, 5장 도달 시 미선택 | 탭 불가 | dimmed (opacity 0.4) |

### 하단 버튼 영역
| 상태 | 표시 |
|---|---|
| 선택 모드 OFF | 기존 "앨범" + "사진 촬영하기" 버튼 |
| 선택 모드 ON, 0장 | "피드에 공유하기" 버튼 (비활성) |
| 선택 모드 ON, 1장 이상 | "N장 선택됨 · 피드에 공유하기" 버튼 (활성) |

---

## 2. 피드 등록 화면 (AlbumBundleShareScreen)

### 진입
"피드에 공유하기" 탭 → `AlbumBundleShareScreen`으로 push
- 전달 데이터: `List<Post> posts` (선택 순서 보존)

### 화면 구성
기존 `_CaptionStep` (upload_screen.dart) 과 동일한 UX:

1. **사진 썸네일 스트립** (상단, 가로 스크롤)
   - `CachedNetworkImage`로 각 Post.imageUrl 표시
   - 첫 번째 사진에 "대표" 뱃지
   - 2장 이상 시 스트립 표시, 1장이면 숨김
2. **문구 입력** — 첫 번째 썸네일 + 캡션 TextField (나란히 배치)
3. **위치 추가** — TextField + 위치 아이콘
4. **길이 (cm) / 무게 (g)** — 나란히 배치, 숫자 입력
5. **리그 태그** — `myJoinedLeaguesProvider` 목록, 없음 선택 기본값
6. 우상단 AppBar "공유" 버튼

### 초기값 자동 채움
- `location`: 첫 번째 선택 Post의 location (있는 경우)
- `length`: 첫 번째 선택 Post의 length (있는 경우)
- 나머지 필드: 빈 값

---

## 3. 데이터 흐름

### Repository 메서드
```dart
// feed_repository.dart
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

- 이미지 재업로드 없음 — 기존 Storage URL 직접 참조
- `imageUrl`: 첫 번째 사진 URL (하위 호환용 단일 필드)
- `imageUrls`: 선택 순서대로 모든 사진 URL 배열 (캐러셀 순서 결정)
- `catch_count`: 선택된 사진 수

### 공유 완료 후 처리
- `ref.invalidate(feedPostsProvider)`
- `ref.invalidate(myPostsProvider)`
- 화면 pop (AlbumBundleShareScreen 닫힘)
- 선택 모드 자동 해제 (`_selectMode = false`, `_orderedSelected.clear()`)
- 스낵바: "피드에 공유되었습니다 🎣"

---

## 4. 피드 표시

`PostImageCarousel`이 `imageUrls`를 이미 처리하므로 **추가 수정 없음**.
- 2장 이상 → PageView 캐러셀 자동 활성화
- 우상단 "1 / N" 카운터 뱃지
- 하단 dot 인디케이터

---

## 5. 변경 파일 목록

| 파일 | 변경 내용 |
|---|---|
| `lib/features/my_league/presentation/screens/my_league_screen.dart` | `_PersonalRecordTab` StatefulWidget 전환, 선택 모드 UI |
| `lib/features/feed/data/feed_repository.dart` | `shareMultiplePostsToFeed()` 메서드 추가 |
| `lib/features/my_league/presentation/screens/album_bundle_share_screen.dart` | **신규** — 피드 등록 화면 |
| `lib/core/router/app_router.dart` | 새 라우트 등록 |

### 변경 불필요 파일
- `post_model.dart` — 수정 없음
- `post_image_carousel.dart` — 수정 없음
- `feed_screen.dart` — 수정 없음
- DB 스키마 — 수정 없음

---

## 6. 제약 조건

- 최대 선택: 5장 (초과 시 미선택 아이템 dimmed + 탭 불가)
- 선택 순서대로 `imageUrls` 배열에 저장
- 캡션, 위치, 길이, 무게는 선택 입력 (빈 값 허용)
- 리그 태그 기본값: 없음 (일반 피드 공유)
