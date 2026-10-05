# 리그 호스트의 조과 수치 수정 설계

작성일: 2026-10-05

## 배경

리그 심사 탭(`CatchReviewTab`, 호스트 + `status='in_progress'`에서만 노출)에는 현재
보류/보류 해지만 있다. 참가자가 길이를 잘못 적어 올린 경우 호스트가 할 수 있는 조치가
보류뿐이어서 다시 올리라고 요청하는 수밖에 없다. 호스트가 직접 수치를 고칠 수 있게 한다.

## 결정 사항

### 리그 개설 시 선택 옵션으로 두지 않는다

항상 호스트가 수정할 수 있다. 근거:

- 호스트는 이미 보류·해지로 결과를 좌우할 권한이 있다. 수치 수정은 그 권한의 연장이며,
  옵션을 꺼도 호스트가 결과를 흔들 수단은 남는다.
- 켜고 끈 리그가 섞이면 참가자 문의와 진행 중 옵션 변경 요구가 생긴다.
- 우려의 본질(호스트가 자기에게 유리하게 조작)은 기능을 끄는 것이 아니라 흔적을 남기고
  당사자에게 통보하는 쪽으로 해결한다.

### 이력은 posts 컬럼으로, 최초 원본만 보존

별도 이력 테이블을 두지 않는다. 필요한 정보는 "원래 얼마였나"와 "누가 언제 고쳤나"이고,
수정은 리그 진행 중 예외적으로 일어난다. 여러 번 고쳐도 `original_*`은 참가자가 올린
최초 값으로 유지한다. 중간 과정은 당사자가 매 수정마다 받는 알림으로 확인된다.

### 알림은 수정된 당사자에게만

피드나 다른 참가자에게는 노출하지 않는다. 당사자가 모르는 채 기록이 바뀌는 일만 막는다.

## 활용하는 기존 장치

- `trg_calc_post_score` — `BEFORE INSERT OR UPDATE OF length`. 길이를 바꾸면 `score`가
  자동 재계산된다. 점수 공식을 다시 구현하지 않는다.
- `create_notification(recipient, type, actor, target, body)` — 알림 행 삽입 + 푸시 발송 +
  본인 행위 제외 + 차단 관계 제외를 모두 처리한다.
- `is_lunker`는 자동 갱신되지 않으므로 RPC에서 함께 설정한다(길이 50cm 이상).

## 스키마

```sql
ALTER TABLE posts
  ADD COLUMN original_length   numeric,
  ADD COLUMN original_weight   numeric,
  ADD COLUMN measure_edited_by uuid REFERENCES users(id),
  ADD COLUMN measure_edited_at timestamptz;
```

`original_*`는 첫 수정 시에만 기록한다(이미 값이 있으면 유지).

## RPC `host_edit_catch_measure(p_post_id uuid, p_value numeric)`

SECURITY DEFINER. 함수 안에서 권한을 직접 검사한다.

| 검사 | 실패 시 예외 |
|---|---|
| 로그인 상태 | `AUTH_REQUIRED` |
| 글이 존재하고 `league_id`가 있고 삭제되지 않음 | `POST_NOT_FOUND` |
| 호출자가 해당 리그 호스트 또는 `users.role='admin'` | `NOT_LEAGUE_HOST` |
| 값이 0보다 크고 상한 이내 (길이 200cm / 무게 50000g) | `INVALID_VALUE` |

통과 시:

1. 리그 `rule`을 조회해 대상 컬럼 결정 — `'무게'`면 `weight`, 그 외는 `length`
2. 기존 값과 같으면 아무 변경 없이 종료
3. `original_*`가 NULL이면 기존 값을 기록
4. 대상 컬럼 + `is_lunker`(길이 규칙일 때) + `measure_edited_by` / `measure_edited_at` 갱신
   - `score`는 `trg_calc_post_score`가 처리
5. 글 작성자에게 `create_notification` 호출
6. 갱신된 값 반환

`enforce_posts_update_columns` 트리거는 수정하지 않는다. 해당 트리거는
`current_user IN ('postgres','supabase_admin')`을 통과 조건으로 두는데, SECURITY DEFINER
함수 안에서는 `current_user`가 함수 소유자(postgres)가 되어 그대로 통과한다.
트리거를 열지 않으므로 일반 UPDATE 경로의 컬럼 보호는 유지된다.

권한: `anon` REVOKE, `authenticated`만 EXECUTE.

## 알림

```
타입: league_catch_edit
본문: 리그 조과 길이가 54.0cm → 45.0cm 로 수정되었습니다
제목: 조과 기록 수정
```

`create_notification`의 푸시 제목 `CASE`에 `league_catch_edit` 분기를 추가한다
(현재는 `ELSE '알림'`으로 떨어진다).

## 앱 변경

| 파일 | 변경 |
|---|---|
| `lib/features/feed/data/post_model.dart` | `originalLength`, `originalWeight`, `measureEditedAt` 추가 |
| `lib/features/league/data/league_repository.dart` | `editCatchMeasure(postId, value)` → RPC 1회 호출 |
| `league_repository.dart` 조회 2곳 | `getLeagueCatchesForReview`, `getUserLeaguePosts` select에 새 컬럼 추가 |
| `catch_review_detail_screen.dart` | "수치 수정" 버튼 + 입력 다이얼로그, 수정된 글은 "원래 54.0cm" 표시 |
| 알림 목록 | `league_catch_edit` 타입 문구와 탭 시 이동 처리 |

입력 다이얼로그는 규칙에 따라 단위를 바꾼다(`최대어`/`합산 길이`/`마릿수` → cm, `무게` → g).
현재 값을 프리필하고, `AppTextField` / `AppButton`을 사용한다.

수정 성공 후 `leagueCatchesForReviewProvider`, `leagueRankingProvider`,
`leagueUserPostsProvider`를 무효화하고 `invalidateScoreCaches(ref)`를 호출해 순위를 즉시 반영한다.

## 표시 범위

참가자 화면에는 수정된 값만 보인다. 원본은 호스트의 심사 상세에서만 노출한다.
당사자는 푸시로 이전 값과 변경 사실을 받으므로 모르고 지나가지 않는다.

## 테스트

- 호스트가 길이를 54 → 45로 수정 → 값·`score`·`is_lunker`가 모두 갱신되고 순위가 바뀐다
- 같은 글을 45 → 48로 재수정 → `original_length`는 54로 유지된다
- 무게 규칙 리그에서 수정 → `weight`가 바뀌고 `length`는 건드리지 않는다
- 호스트가 아닌 참가자가 RPC 직접 호출 → `NOT_LEAGUE_HOST`
- 다른 리그 호스트가 남의 리그 글 수정 시도 → `NOT_LEAGUE_HOST`
- 음수·0·상한 초과 값 → `INVALID_VALUE`
- 수정 시 작성자에게 알림·푸시 도착, 호스트 자기 글 수정 시에는 알림 없음
- 기존 값과 동일한 값으로 수정 → 변경·알림 모두 없음
