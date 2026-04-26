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
    theme/                  # 디자인 토큰 (Colors/TextStyles/Spacing/Radius/Elevation/Durations) + AppTheme
    widgets/                # AppButton/AppCard/AppTextField/ConfirmDialog/AppSnackBar/SectionLabel/StatWidgets/InfoChip/EmptyState/SlideToConfirm/UserAvatar/AppSvg
  features/
    auth/       # 로그인/회원가입, currentUserProvider
    feed/       # 홈 피드, 게시물 상세, 좋아요, 댓글
    league/     # 리그 목록/상세/개설/조과업로드/참가자상세
    my_league/  # 내 리그 (참여중/기록/개설)
    profile/    # 프로필, 통계, 게시물 그리드
    ranking/    # 전체 랭킹
    upload/     # 일반 피드 업로드
docs/
  DESIGN_SYSTEM.md  # 🎨 디자인 시스템 단일 기준 문서 (UI 작업 전 필독)
```

## 디자인 시스템

> 📐 **모든 UI 작업의 기준 문서**: [`docs/DESIGN_SYSTEM.md`](docs/DESIGN_SYSTEM.md)
>
> 색상·타이포·스페이싱·컴포넌트 사양이 모두 거기에 있습니다. 새 화면을 만들거나 토큰/컴포넌트를 추가/변경할 때 그 문서를 함께 업데이트하세요.

## 공용 컴포넌트 원칙 (필수)

**여러 곳에서 반복되는 UI는 반드시 공용 컴포넌트로 만들고 import해서 사용한다. 절대 복붙 금지.**

### 현재 공용 위젯 목록 (`lib/core/widgets/`)
| 파일 | 클래스 | 용도 |
|---|---|---|
| `app_button.dart` | `AppButton` (primary/secondary/ghost/destructive) | 표준 버튼 |
| `app_card.dart` | `AppCard` (surface/tinted/outlined) | 표준 카드 컨테이너 |
| `app_text_field.dart` | `AppTextField` | 표준 입력 필드 |
| `confirm_dialog.dart` | `ConfirmDialog`, `showConfirmDialog()` | 확인/취소 다이얼로그 |
| `app_snack_bar.dart` | `AppSnackBar.success/error/info()` | 탑 슬라이드 배너 |
| `section_label.dart` | `SectionLabel` | 섹션 제목 (컬러 바 + 텍스트) |
| `stat_widgets.dart` | `StatNumber`, `StatBox` | 통계 숫자/박스 |
| `info_chip.dart` | `InfoChip`, `InfoChipFilled` | 아이콘+텍스트 칩 |
| `empty_state.dart` | `EmptyState` | 빈 목록 화면 |
| `slide_to_confirm.dart` | `SlideToConfirm`, `showDeleteConfirmSheet()` | 슬라이드 삭제 확인 |
| `user_avatar.dart` | `UserAvatar` | 유저 아바타 |
| `app_svg.dart` | `AppSvg`, `AppIcons` | SVG 래퍼 |

### 현재 공용 테마 (`lib/core/theme/`)
| 파일 | 클래스 | 용도 |
|---|---|---|
| `app_colors.dart` | `AppColors` | 색상 토큰 |
| `app_text_styles.dart` | `AppTextStyles` | 타이포 토큰 |
| `app_spacing.dart` | `AppSpacing` | 4pt 그리드 스페이싱 토큰 |
| `app_radius.dart` | `AppRadius` | 모서리 반경 토큰 |
| `app_elevation.dart` | `AppElevation` | 그림자 토큰 |
| `app_durations.dart` | `AppDurations` | 애니메이션 시간 토큰 |
| `app_theme.dart` | `AppTheme` | 다크/라이트 ThemeData 통합 |

### 새 컴포넌트가 필요한 경우
1. `lib/core/widgets/` 또는 `lib/core/theme/`에 파일 생성
2. 기존 코드에서 중복 클래스 제거하고 import로 교체
3. 이 목록 + `docs/DESIGN_SYSTEM.md`의 컴포넌트 섹션 + 변경 로그 업데이트

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
await Future.delayed(AppDurations.dialogClose);   // 3. 애니메이션 대기
await doWork();                                   // 4. 작업
AppSnackBar.success(context, '완료');              // 5. 피드백
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
- **[어드민]** Flutter 앱에 신고/문의 UI 추가 (현재 앱에 해당 화면 없음)
- **[어드민]** Vercel 배포
