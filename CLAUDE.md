# HUK — 낚시 리그 & 조과 SNS

Flutter 앱. 패키지명 `fishing_competition`.

## 기술 스택
- **Flutter** + **Riverpod 2** (riverpod_annotation, riverpod_generator)
- **GoRouter 14.8.1** (딥링크 포함)
- **Supabase Flutter 2.12.4**
- **Freezed 3.0** (모델 코드 생성)
- **flutter_svg**, **lucide_icons**

## 폴더 구조
```
lib/
  core/
    presentation/screens/  # splash, main
    router/app_router.dart  # GoRouter 전체 라우트 정의
    theme/                  # AppColors, AppTheme
    widgets/                # UserAvatar, AppSvg
  features/
    auth/       # 로그인/회원가입, currentUserProvider
    feed/       # 홈 피드, 게시물 상세, 좋아요, 댓글
    league/     # 리그 목록/상세/개설/조과업로드/참가자상세
    my_league/  # 내 리그 (참여중/기록/개설)
    profile/    # 프로필, 통계, 게시물 그리드
    ranking/    # 전체 랭킹
    upload/     # 일반 피드 업로드
```

## 핵심 규칙

### 리그 조과 ↔ 일반 피드 분리
- `posts.league_id IS NOT NULL` → 리그 전용, 홈피드/프로필에 노출 안 됨
- 피드/프로필 쿼리에는 반드시 `.isFilter('league_id', null)` 적용
- "내 피드에 공유" = `league_id=null`인 새 post INSERT (원본 유지)

### async + Navigator 패턴
다이얼로그에서 삭제 등 async 작업 시 이 순서 준수:
```dart
final messenger = ScaffoldMessenger.of(context); // 1. 미리 캡처
Navigator.pop(dialogCtx);                         // 2. dialog context로 닫기
await Future.delayed(const Duration(milliseconds: 300)); // 3. 애니메이션 대기
await doWork();                                   // 4. 작업
messenger.showSnackBar(...);                      // 5. 스낵바
ref.invalidate(someProvider);                     // 6. 마지막에 invalidate
```

### 코드 생성
- `.freezed.dart`, `.g.dart` 직접 수정 금지
- 모델/provider 변경 후: `dart run build_runner build --delete-conflicting-outputs`

### Riverpod 로딩 플래시 방지
```dart
ref.watch(someProvider).when(
  skipLoadingOnReload: true,
  data: ..., loading: ..., error: ...,
)
```

## Supabase 마이그레이션
`supabase/migration_fix_rls_and_columns.sql` → Supabase Dashboard > SQL Editor에서 실행 필요.
미실행 시 리그 개설/시작/삭제가 RLS에 막혀 동작 안 함.

## 테마
- 다크모드 accent: `AppColors.neonGreen` (`#00FF88`)
- 라이트모드 accent: `AppColors.navy` (`#1A2A6C`)
- 다크 배경: `AppColors.darkBg` (`#09090B`)

## 딥링크
- scheme: `huk://`
- 리그 상세: `huk:///league/detail/:id`

## 미구현 / 다음 작업
- 댓글 삭제
- 리그 조과 삭제 (리그 내에서)
- 다른 유저 프로필 조회
- 푸시 알림
- 참가 승인 플로우 (현재 즉시 approved)
