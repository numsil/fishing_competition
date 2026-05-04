# Architecture

## 구조

UI → Provider → Repository → Supabase

---

## 역할

### UI
- 화면 렌더링만 담당
- 비즈니스 로직 금지

### Provider
- 상태 관리
- Repository 호출

### Repository
- 모든 데이터 처리
- Supabase 쿼리 전담

---

## Supabase 규칙

- 반복문 안 쿼리 금지 (N+1)
- select('*') 금지
- join으로 관계 데이터 처리