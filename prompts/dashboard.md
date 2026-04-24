# 관리자 대시보드 기능 기획안 (v1.1)

## 1. 목표
Flutter 앱과 연동되는 관리자 웹에서 아래 기능을 수행한다.
- 유저 관리
- 게시물 관리
- 신고 처리
- 문의 관리
- 점수 관리
- 배지 관리

## 2. 사용자
- 관리자: 모든 데이터 조회/수정 가능
- 일반 유저: 관리자 페이지 접근 불가

## 3. 기능

### 3.1 유저 관리
- 유저 목록 조회
- 검색 (이메일, 닉네임)
- 상태 변경 (active, banned)
- 삭제 (soft delete)

정책:
- banned: 로그인 차단, 데이터 유지
- delete: is_deleted = true

### 3.2 게시물 관리
- 게시물 목록 조회
- 유저별 필터
- 삭제 (soft delete)

정책:
- 실제 삭제 금지
- is_deleted = true

### 3.3 신고 관리
- 신고 목록 조회
- 상세 조회
- 상태 변경

상태:
- pending
- resolved
- rejected

처리:
- 게시물 숨김
- 유저 정지
- 무시

### 3.4 문의 관리
- 문의 목록 조회
- 상세 조회
- 상태 변경

상태:
- open
- in_progress
- closed

### 3.5 점수 관리
- 유저 점수 조회
- 점수 변경

입력:
- 변경값 (+/-)
- 사유

정책:
- 모든 변경은 로그 기록

### 3.6 배지 관리

#### 기능
- 배지 목록 조회
- 배지 추가
- 배지 수정
- 배지 삭제
- 유저에게 배지 부여 / 회수

#### 배지 속성
- id
- name (배지 이름)
- description (설명)
- icon_url (이미지)
- condition (획득 조건 설명)
- is_active (활성 여부)
- created_at

#### 유저-배지 관계
- user_id
- badge_id
- assigned_at

#### 정책
- 배지 삭제 시 실제 삭제 ❌ → 비활성화(is_active = false)
- 동일 배지 중복 부여 방지
- 수동 부여/회수 가능

## 4. 공통 기능
- 검색
- 필터
- 페이지네이션
- 정렬 (최신순)

## 5. 권한
- 관리자 로그인 필요
- admin role만 접근 가능
- 모든 수정은 API 통해 처리

## 6. 기술 구성
- Backend: Supabase
- Web: Next.js
- App: Flutter

## 7. 데이터 구조

users / profiles
- id
- email
- status
- role
- created_at

posts
- id
- user_id
- content
- is_deleted
- created_at

reports
- id
- post_id
- reporter_id
- reason
- status
- created_at

tickets
- id
- user_id
- message
- status
- created_at

score_logs
- id
- user_id
- change
- reason
- admin_id
- created_at

badges
- id
- name
- description
- icon_url
- condition
- is_active
- created_at

user_badges
- id
- user_id
- badge_id
- assigned_at


## 8. 우선순위
1. 유저 관리
2. 게시물 관리
3. 신고 관리
4. 문의 관리
5. 점수 관리
6. 배지 관리
7. 권한/보안

## 9. 핵심 원칙
- soft delete 사용
- 관리자 액션 로그 기록
- 권한 체크 필수
- 앱과 동일 DB 사용
- 배지는 비활성화 방식으로 관리