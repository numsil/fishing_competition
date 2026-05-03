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

## Docs Reference

- 디자인 시스템: docs/DESIGN_SYSTEM.md
- 컴포넌트: docs/COMPONENTS.md
- 아키텍처: docs/ARCHITECTURE.md

필요 시 해당 문서를 참고해서 구현한다.