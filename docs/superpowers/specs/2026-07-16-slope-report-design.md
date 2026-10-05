# 슬로프 제보 기능 설계

작성일: 2026-07-16
대상: 낚스타 앱 · 슬로프 찾기 페이지

## 목적
유저가 슬로프 관련 정보를 직접 제보할 수 있게 한다. 두 종류:
- **새 슬로프 제보** — 아직 목록에 없는 슬로프 위치를 알려줌
- **오류 신고** — 기존 슬로프의 잘못된 정보(폐쇄·위치 오류·유료 전환 등) 신고

제보 데이터는 Supabase `slope_reports` 테이블에 쌓이고, 어드민(별도 레포)에서 열람한다.
이번 범위는 **DB + Flutter 앱**까지. 어드민 페이지는 다음 세션.

## 진입점 & 네비게이션
- 슬로프 찾기 `AppBar`에서 지도 아이콘 오른쪽에 `...`(더보기) 아이콘 추가
- 탭 → `showAppActionSheet`로 2개 항목: `새 슬로프 제보`, `오류 신고`
- 각 항목 → 전용 폼 화면으로 push
- **로그인 필수** — 미로그인 시 `NotAuthenticatedException` → "로그인이 필요합니다" 스낵바

## 폼 화면

### 새 슬로프 제보 (`SlopeReportNewScreen`, `/slopes/report/new`)
- 슬로프 이름/위치 — 필수, 한 줄
- 주소 또는 위치 설명 — 필수, 한 줄
- 상세 내용 — 선택, 여러 줄
- 제출 `AppButton`

### 오류 신고 (`SlopeReportErrorScreen`, `/slopes/report/error`)
- 대상 슬로프 — 필수. 탭하면 검색 가능한 슬로프 선택 시트(`SlopePickerSheet`, `slopesProvider` 재사용)
- 오류 내용 — 필수, 여러 줄
- 제출 `AppButton`

공통: 모든 입력은 `AppTextField`. 제출 성공 → 스낵바 후 화면 닫기.

## DB 스키마 — 신규 테이블 `slope_reports`
| 컬럼 | 타입 | 설명 |
|---|---|---|
| id | uuid PK (gen_random_uuid) | |
| type | text | `'new_slope'` \| `'error'` (CHECK) |
| reporter_id | uuid | `users(id)` 참조, `auth.uid()` |
| slope_id | text | `slopes(id)` 참조, 오류신고 대상 (new_slope은 null) |
| slope_name | text | 새 슬로프 제보의 제안 이름/위치 (error는 null) |
| address | text | 새 슬로프 제보의 주소/위치 설명 |
| content | text | 상세/오류 내용 |
| status | text | `'pending'`(기본) \| `'resolved'` \| `'dismissed'` (CHECK) |
| created_at | timestamptz | default now() |
| updated_at | timestamptz | 트리거 자동 갱신 |

인덱스: `(status, created_at desc)` — 어드민 미처리 목록 조회용.

### RLS
- INSERT: 로그인 유저, `reporter_id = auth.uid()` 강제
- SELECT: 본인 제보만 (`reporter_id = auth.uid()`). 어드민은 `service_role`로 RLS 우회 → 전체 열람
- UPDATE/DELETE: 어드민(`users.role = 'admin'`)만 — 상태 변경용

## 데이터 흐름 (앱 → Repository → Supabase)
- `SlopeReportRepository` (`features/slopes/data/slope_report_repository.dart`)
  - `submitNewSlope({name, address, content})`
  - `submitError({slopeId, content})`
  - 미로그인 시 `NotAuthenticatedException` (기존 report 패턴 동일)
- Provider: Riverpod 코드젠 `@riverpod`

## 파일 구성 (모두 `features/slopes/` 하위)
- `data/slope_report_repository.dart` (+ `.g.dart`)
- `presentation/screens/slope_report_new_screen.dart`
- `presentation/screens/slope_report_error_screen.dart`
- `presentation/widgets/slope_picker_sheet.dart`
- 라우트 2개 추가 (`app_router.dart`)
- 마이그레이션 `supabase/migrations/..._create_slope_reports.sql`

## 어드민 (이번 범위 밖)
DB 테이블만 준비. `/dashboard/slope-reports` 페이지는 별도 세션에서 admin 레포 전환 후.

## 비목표 (YAGNI)
- 사진 첨부 / 연락처 필드 없음
- 통합 제보 폼 없음 (2종 분리 유지)
- 개별 슬로프 카드의 신고 진입점 없음 (메뉴에서만)
