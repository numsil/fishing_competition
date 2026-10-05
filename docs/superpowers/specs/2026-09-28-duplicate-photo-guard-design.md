# 조과 사진 중복 업로드 차단 설계

작성일: 2026-09-28

## 배경

같은 배스 사진으로 조과 인증을 두 번 받아 점수를 중복 획득하는 부정을 막는다.

현재 업로드 경로는 파일명을 `posts/{userId}_{timestamp}.jpg` 형태로 앱이 직접 생성하고
원본 파일명은 저장하지 않는다(`feed_repository.dart:531`). 타임스탬프가 매번 달라지므로
파일명으로는 동일 사진을 판별할 수 없다. 사진 내용 자체의 지문으로 판별해야 한다.

## 결정

압축 전 **원본 사진 바이트의 SHA-256**을 `posts.image_hash`에 저장하고,
부분 unique 인덱스로 중복 등록을 DB에서 차단한다.

### 해시 대상을 원본으로 잡는 이유

압축 결과는 기기·`flutter_image_compress` 버전에 따라 바이트가 달라질 수 있어,
같은 사진인데 해시가 어긋나는 오탐이 생긴다. 원본 바이트는 갤러리에서 같은 파일을
다시 고르면 항상 동일하다.

### 비교 범위를 전역으로 잡는 이유

전역 unique 인덱스는 B-tree 탐색이라 행 수가 늘어도 탐색 깊이가 3~4단계로 거의 일정하다
(현재 posts 218행 / 224KB). 본인 글로 범위를 좁혀도 빨라지지 않고, 부계정·사진 도용을
놓치기만 한다. 체감 비용은 앱에서 SHA-256을 계산하는 10~40ms뿐이며, 이는 기존 사진 압축
시간(수백 ms)에 묻힌다.

## 스키마

```sql
ALTER TABLE posts ADD COLUMN image_hash text;

-- 개인기록끼리 중복 차단
CREATE UNIQUE INDEX posts_personal_image_hash_unique
  ON posts (image_hash)
  WHERE image_hash IS NOT NULL
    AND is_personal_record = true
    AND coalesce(is_deleted, false) = false;

-- 같은 리그 안에서 중복 차단
CREATE UNIQUE INDEX posts_league_image_hash_unique
  ON posts (league_id, image_hash)
  WHERE image_hash IS NOT NULL
    AND league_id IS NOT NULL
    AND coalesce(is_deleted, false) = false;
```

판정 결과:

| 시나리오 | 결과 |
|---|---|
| 같은 사진으로 개인기록 2회 | 차단 |
| 같은 사진을 한 리그에 2회 | 차단 |
| 같은 사진을 리그 1회 + 개인기록 1회 | 허용 (정상 흐름) |
| 같은 사진을 A리그 1회 + B리그 1회 | 허용 (리그별 기간·규칙이 달라 판단 보류) |
| 삭제한 글과 같은 사진 재등록 | 허용 (`is_deleted` 제외) |
| 일반 피드 글 | 해시 저장만, 차단 없음 |

일반 피드 글에도 해시를 저장하는 이유는 나중에 차단 범위를 넓히거나 유사 사진 감지를
붙일 때 쓰기 위함이다.

## 업로드 흐름

```
사진 선택
  → 원본 바이트 SHA-256 (스트림 청크 처리)
  → 사전 조회 (인덱스 1회)
      ├ 중복 → 업로드하지 않고 즉시 에러
      └ 통과 → 압축 → 스토리지 업로드 → posts INSERT
                                          └ 경합 시 unique 위반
                                            → 방금 올린 객체 삭제 후 에러
```

사전 조회를 앞에 두는 것은 스토리지에 고아 파일이 남지 않게 하기 위함이고,
unique 인덱스는 동시 업로드 경합에 대한 최종 방어선이다.

사전 조회 대상은 등록하려는 글의 종류에 맞춘다.
개인기록이면 개인기록 범위, 리그 조과면 해당 `league_id` 범위로 조회한다.

## 사용자 메시지

```
이미 등록된 사진입니다. 다른 사진으로 인증해주세요.
```

누가 언제 올렸는지는 노출하지 않는다. 타인의 게시물 존재를 드러내게 된다.

## 변경 파일

| 파일 | 변경 |
|---|---|
| `pubspec.yaml` | `crypto` 패키지 추가 (순수 Dart) |
| `supabase/migrations/<ts>_post_image_hash.sql` | 컬럼 + 부분 unique 인덱스 2개 |
| `lib/core/utils/image_hash.dart` (신규) | 파일 스트림 → SHA-256 hex |
| `lib/features/feed/data/feed_repository.dart` | 해시 계산·사전 조회·INSERT 반영·경합 시 업로드 파일 정리 |
| `lib/features/my_league/presentation/screens/personal_catch_screen.dart` | 중복 에러 메시지 |
| `lib/features/league/presentation/screens/league_catch_screen.dart` | 중복 에러 메시지 |

`createPost`는 네 곳에서 호출된다(개인 조과, 리그 조과, 피드 업로드 2곳).
해시 계산은 단일 이미지(`imageFile`) 경로와 다중 이미지 경로 모두에서 첫 번째 사진을
기준으로 한다. 조과 등록 화면은 단일 사진만 받으므로 실질적으로 단일 경로가 대상이다.

## 한계

**기존 218건은 소급 적용되지 않는다.** 원본 바이트 기준인데 스토리지에는 압축본만 있어
과거 글의 해시를 복원할 수 없다. 배포 이후 등록분끼리만 비교된다.

**크롭·재저장·스크린샷은 우회된다.** 해시가 달라지기 때문이다. 무심코 같은 파일을 다시
올리는 것은 확실히 막지만 작정한 편집은 막지 못한다. 그 영역은 지각 해시(dHash/pHash)로
심사 화면에 "비슷한 사진이 이미 있음" 경고를 띄우는 방식이 적합하며, 자동 거절은
오탐 위험 때문에 하지 않는다. 이번 범위에서는 다루지 않는다.

**해시는 클라이언트가 계산한다.** 변조된 클라이언트는 임의 해시를 보내 우회할 수 있다.
서버가 검증하려면 업로드된 이미지를 다시 받아 해시를 내야 하므로 비용이 크다.
현 단계에서는 감수하고, 필요해지면 Edge Function에서 검증하는 방향으로 확장한다.

## 테스트

- 같은 사진으로 개인기록 2회 등록 → 두 번째가 차단되고 스토리지에 파일이 남지 않는다
- 같은 사진을 한 리그에 2회 등록 → 두 번째가 차단된다
- 같은 사진을 리그 1회 + 개인기록 1회 → 둘 다 등록된다
- 개인기록 삭제 후 같은 사진 재등록 → 등록된다
- 다른 사진 2장 연속 등록 → 둘 다 등록된다
- 일반 피드 글에 같은 사진 2회 → 둘 다 등록된다(차단 대상 아님)
