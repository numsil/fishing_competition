# HUK Project Rules

## 🧠 Architecture

UI → Provider → Repository → Supabase

- UI / Provider에서 직접 쿼리 금지
- 모든 데이터 접근은 Repository를 통해서만

---

## Supabase 금지 규칙

- 반복문 안에서 쿼리 금지 (N+1)
- select('*') 사용 금지
- 동일 조건 중복 조회 금지

---

## Supabase 규칙

- 필요한 컬럼만 select
- 관계 데이터는 join(users!inner)
- 동일 데이터는 1회 조회 후 재사용

---

## 캐싱 규칙

- 리스트: 5분 TTL
- 프로필: 3분 TTL
- 유저: keepAlive 유지

---

## Refactoring Rules

- 한 번에 한 파일만 수정
- 기존 기능 절대 유지
- 변경 파일만 반환

---

## Working Style

- 최소 범위 수정
- 전체 프로젝트 수정 금지
- 분석 후 수정

---

## Domain Rules

- posts.league_id != null → 리그 전용
- feed/profile 쿼리 → league_id null 필수

---

## UI Rules

- 공통 UI는 core/widgets 사용
- 중복 UI 구현 금지

---

## 공통 위젯 사용 규칙

### 원칙
모든 UI 요소는 `lib/core/widgets/` 의 통합 위젯을 우선 사용한다.
직접 Flutter 기본 위젯(TextField, ElevatedButton, Container 등)을 스타일링하여 쓰는 것을 금지한다.

### 적용 대상 (반드시 통합 위젯 사용)
- 텍스트 입력: `AppTextField` (TextField/TextFormField 직접 사용 금지)
- 버튼: `AppButton` (ElevatedButton/TextButton/OutlinedButton 직접 사용 금지)
- 카드/패널: `AppCard` (Container + BoxDecoration로 카드 직접 만들기 금지)
- 아바타: `UserAvatar` (CircleAvatar 직접 사용 금지)
- 빈 상태: `EmptyState`
- SVG 에셋: `AppSvg` (Image.asset으로 SVG 직접 사용 금지) / lucide_icons는 직접 사용 허용
- 텍스트 스타일: `AppTextStyles` 토큰 사용

### 적용 제외 (통합 위젯 만들지 말 것)
- Padding, SizedBox, Row, Column, Stack 등 레이아웃 프리미티브
- 한 화면에서만 쓰이는 화면 전용 위젯 (해당 screen 폴더에 둘 것)
- 외부 패키지 위젯을 그대로 쓰는 경우 (예: CachedNetworkImage)

### 통합 위젯이 없는 경우
1. 기존 통합 위젯의 props 확장으로 해결 가능한지 먼저 검토
   - 예: AppCard에 variant 추가 vs 새 위젯 만들기 → 변형이면 props 추가 우선
2. props 확장으로 안 되면 새 통합 위젯을 `lib/core/widgets/` 에 추가
3. 새 위젯 추가 시 사용자에게 먼저 확인 후 진행. 임의로 만들지 말 것

### 디자인 토큰
- 색상: `AppColors` 만 사용. `Color(0xFF...)` 하드코딩 금지
- 간격: `AppSpacing` 토큰 사용 권장 (없으면 8의 배수)
- 폰트: `AppTextStyles` 만 사용

### 기존 코드 리팩토링 금지
사용자가 명시적으로 요청한 파일 외에는 기존 코드를 통합 위젯으로 교체하지 말 것.
새 코드 작성 시에만 본 규칙 적용.

### 카탈로그
모든 통합 위젯은 `lib/dev/widget_catalog_screen.dart` 에 추가하여 시각적으로 검증 가능하게 한다.

## Git Rules

- 기본 push는 항상 `develop` 브랜치
- `main` push는 친구들 배포 시에만 (명시적으로 요청할 때만)
- main 배포 순서: `git checkout main → git merge develop → git push origin main → git checkout develop`
- **push는 사용자가 명시적으로 요청할 때만 실행** (코드 수정 후 자동 push 금지)
- **main 배포 시 항상 `pubspec.yaml` 빌드 번호 +1** (예: `1.0.0+6` → `1.0.0+7`). 빌드 번호 안 올리면 GitHub Actions가 같은 태그로 빌드 실패하고 업데이트 팝업이 안 뜸

---

## Docs Reference

- 디자인 시스템: docs/DESIGN_SYSTEM.md
- 컴포넌트: docs/COMPONENTS.md
- 아키텍처: docs/ARCHITECTURE.md

필요 시 해당 문서를 참고해서 구현한다.