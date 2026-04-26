# HUK / 낚스타 — 디자인 시스템

> **이 문서는 UI 작업의 단일 기준 문서입니다.** 새 화면/컴포넌트를 만들기 전에 반드시 읽고, 토큰·컴포넌트가 추가되거나 변경되면 이 문서를 함께 업데이트하세요.

앱은 **다크모드 기본**(neon green accent), 라이트모드(navy accent)를 모두 지원합니다. 토큰은 모두 `lib/core/theme/`, 공용 위젯은 `lib/core/widgets/` 에 있습니다.

---

## 1. Color System

다크/라이트 양쪽 토큰이 분리되어 있습니다. 화면에서 직접 색을 정하지 말고 **토큰으로 참조**하세요. 라이트/다크 분기가 필요하면 `Theme.of(context).brightness`로 판단합니다.

### 1.1 Brand / Accent

| 토큰 | Hex | 사용처 |
|---|---|---|
| `AppColors.neonGreen` | `#00FF88` | **다크모드 메인 accent** — 버튼, 탭 인디케이터, 포커스 보더 |
| `AppColors.neonGreenDim` | `#00CC6A` | neon green 서브 (호버/2차 상태) |
| `AppColors.navy` | `#1A2A6C` | **라이트모드 메인 accent** |
| `AppColors.navyLight` | `#2E4099` | navy 서브 |

### 1.2 Surface (배경)

| 토큰 | Hex | 역할 |
|---|---|---|
| `AppColors.darkBg` | `#09090B` | 다크 scaffold 배경 (Zinc-950) |
| `AppColors.darkSurface` | `#18181B` | 다크 카드 / 다이얼로그 / 바텀시트 (Zinc-900) |
| `AppColors.darkSurface2` | `#27272A` | 다크 input fill / 칩 배경 (Zinc-800) |
| `AppColors.lightBg` | `#F4F4F5` | 라이트 scaffold 배경 (Zinc-100) |
| `AppColors.lightSurface` | `#FFFFFF` | 라이트 카드 / 다이얼로그 |

### 1.3 Text

| 토큰 | Hex | 역할 |
|---|---|---|
| `AppColors.darkText` | `#FAFAFA` | 다크 본문/제목 (Zinc-50) |
| `AppColors.darkTextSub` | `#A1A1AA` | 다크 서브텍스트 (Zinc-400) |
| `AppColors.lightText` | `#09090B` | 라이트 본문/제목 |
| `AppColors.lightTextSub` | `#71717A` | 라이트 서브텍스트 (Zinc-500) |

### 1.4 Divider

| 토큰 | Hex | 역할 |
|---|---|---|
| `AppColors.darkDivider` | `#27272A` | 다크 디바이더 / 카드 외곽선 |
| `AppColors.lightDivider` | `#E4E4E7` | 라이트 디바이더 / 카드 외곽선 |

### 1.5 Semantic (상태)

| 토큰 | Hex | 의미 |
|---|---|---|
| `AppColors.success` | `#22C55E` | 성공, 등록 완료 |
| `AppColors.warning` | `#F59E0B` | 경고 |
| `AppColors.error` | `#EF4444` | 에러, **삭제(파괴적) 액션** |
| `AppColors.liveRed` | `#FF3B30` | 실시간/라이브 표시 |

### 1.6 Medal (랭킹/배지 전용)

| 토큰 | Hex |
|---|---|
| `AppColors.gold` | `#FFD700` |
| `AppColors.silver` | `#B0BEC5` |
| `AppColors.bronze` | `#CD7F32` |

### 1.7 Accent 헬퍼 패턴

라이트/다크에 따라 accent가 다르므로 다음 패턴을 권장합니다.

```dart
final isDark = Theme.of(context).brightness == Brightness.dark;
final accent = isDark ? AppColors.neonGreen : AppColors.navy;
final sub = isDark ? AppColors.darkTextSub : AppColors.lightTextSub;
```

---

## 2. Typography

`lib/core/theme/app_text_styles.dart` — 사이즈와 weight만 정의된 토큰입니다. 색상은 `Theme`의 `textTheme` 또는 호출부에서 `.copyWith(color:)`로 결정합니다.

| 토큰 | Size | Weight | 사용 |
|---|---|---|---|
| `AppTextStyles.heading1` | 20 | w800 | 화면 타이틀 |
| `AppTextStyles.heading2` | 18 | w800 | 섹션 큰 제목 |
| `AppTextStyles.heading3` | 16 | w800 | 카드 제목 |
| `AppTextStyles.heading4` | 15 | w800 | 작은 제목 |
| `AppTextStyles.bodyBold` | 14 | w700 | 본문 강조 |
| `AppTextStyles.body` | 14 | w500 | 기본 본문 |
| `AppTextStyles.bodySmall` | 13 | w500 | 작은 본문 |
| `AppTextStyles.caption` | 12 | w500 | 메타정보, 시간 |
| `AppTextStyles.captionBold` | 12 | w600 | 강조 캡션 |
| `AppTextStyles.captionSmall` | 11 | w500 | 가장 작은 보조 |
| `AppTextStyles.badge` | 10 | w800 | 배지 라벨 |

**Weight 사용 규칙**
- **w500 (medium)**: 기본 본문
- **w600 (semibold)**: 라벨, 메뉴
- **w700 (bold)**: 강조 본문
- **w800 (extrabold)**: 모든 제목, 배지

폰트 패밀리는 ThemeData 기본값(시스템 폰트)을 사용합니다.

---

## 3. Spacing System

`lib/core/theme/app_spacing.dart` — **4pt 그리드 기반**.

| 토큰 | Value | 용도 |
|---|---|---|
| `AppSpacing.xxs` | 2 | 매우 좁은 갭 (인라인 아이콘) |
| `AppSpacing.xs` | 4 | 글자/아이콘 사이 |
| `AppSpacing.sm` | 6 | 작은 갭 |
| `AppSpacing.md` | 8 | 칩 내부 등 |
| `AppSpacing.lg` | 12 | 카드 내부 요소 |
| `AppSpacing.xl` | 16 | **화면 좌우 패딩 기본** |
| `AppSpacing.xxl` | 20 | 섹션 사이 |
| `AppSpacing.xxxl` | 24 | 큰 섹션 사이 |
| `AppSpacing.huge` | 32 | 화면 단위 여백 |
| `AppSpacing.mega` | 40 | 빈 상태 등 큰 여백 |

### 3.1 자주 쓰는 프리셋

```dart
AppSpacing.pageHorizontal  // EdgeInsets.symmetric(horizontal: 16)
AppSpacing.pageAll         // EdgeInsets.all(16)
AppSpacing.card            // EdgeInsets.all(14)
AppSpacing.listItem        // EdgeInsets.symmetric(horizontal: 16, vertical: 12)
```

### 3.2 SizedBox 갭

`SizedBox(height: 16)` 같은 매직넘버 대신:

```dart
AppSpacing.gapH4 / gapH8 / gapH12 / gapH16 / gapH20 / gapH24
AppSpacing.gapW4 / gapW6 / gapW8 / gapW10 / gapW12
```

### 3.3 Spacing 사용 규칙

- **화면 좌우 패딩**: `AppSpacing.xl` (16) 기본. 스크롤뷰는 `AppSpacing.pageHorizontal`.
- **섹션 사이 세로 간격**: `AppSpacing.xxl`(20) 또는 `AppSpacing.xxxl`(24).
- **카드 내부 패딩**: `AppSpacing.card`(14).
- **인접 텍스트 사이**: 4(xs), 6(sm), 8(md) 중 선택.
- **스크롤 바닥**: `AppSpacing.huge`(32) — 마지막 아이템 가림 방지.

---

## 4. Radius

`lib/core/theme/app_radius.dart`

| 토큰 | Value | 용도 |
|---|---|---|
| `AppRadius.xs` | 4 | 작은 인디케이터 바 |
| `AppRadius.sm` | 8 | 작은 칩 / 인라인 박스 |
| `AppRadius.md` | 12 | **버튼 / 입력필드 기본** |
| `AppRadius.lg` | 16 | **카드 기본** |
| `AppRadius.xl` | 20 | 바텀시트 / 큰 카드 / 칩(chip) |
| `AppRadius.xxl` | 24 | 강조 카드 |
| `AppRadius.pill` | 9999 | 알약 모양 (status pill) |

```dart
AppRadius.brSm / brMd / brLg / brXl       // BorderRadius.circular
AppRadius.brTopXl                          // 바텀시트 상단만 둥글게
```

---

## 5. Elevation / Shadow

`lib/core/theme/app_elevation.dart`

```dart
AppElevation.sm(color)   // 작은 떠 있는 요소
AppElevation.md(color)   // top banner, hover
AppElevation.lg(color)   // modal, bottom sheet
```

색상을 받는 이유: 다크모드에선 검정 그림자보다 accent 컬러의 글로우 그림자가 잘 어울립니다. 일반 카드는 그림자 없이 border로 구분.

---

## 6. Durations

`lib/core/theme/app_durations.dart`

| 토큰 | Value | 용도 |
|---|---|---|
| `AppDurations.instant` | 100ms | 즉시 반응 (탭 피드백) |
| `AppDurations.fast` | 200ms | 호버, 작은 변화 |
| `AppDurations.normal` | 300ms | 페이지 전환, 다이얼로그 |
| `AppDurations.slow` | 450ms | 강조 애니메이션 |
| `AppDurations.dialogClose` | 300ms | **async + Navigator 패턴 대기 시간** |
| `AppDurations.snackBar` | 1800ms | 스낵바 노출 시간 |

---

## 7. Components

### 7.1 AppButton

```dart
AppButton(
  label: '리그 시작하기',
  onPressed: () {},
)

AppButton(
  label: '취소',
  variant: AppButtonVariant.secondary,
  onPressed: () {},
)

AppButton(
  label: '삭제',
  variant: AppButtonVariant.destructive,
  icon: Icons.delete_outline,
  onPressed: () {},
)

AppButton(
  label: '저장',
  loading: isSaving,                     // 로딩 스피너로 자동 교체
  onPressed: isSaving ? null : _save,
)
```

**상태 정의**
| 상태 | 처리 |
|---|---|
| default | 토큰대로 렌더 |
| pressed | InkWell ripple |
| disabled | `onPressed == null` → 45% opacity |
| loading | `loading: true` → 스피너로 교체, 클릭 막음 |

**Variant**
- `primary` — 다크: neonGreen / 라이트: navy
- `secondary` — surface + border (보조 액션)
- `ghost` — 배경 transparent, accent 텍스트 (3차 액션)
- `destructive` — error 색 (삭제)

**Size**
- `sm` (height 36) / `md` (44) / **`lg` (52, 기본)**

### 7.2 AppCard

```dart
AppCard(
  child: Text('기본 카드'),
)

AppCard(
  variant: AppCardVariant.tinted,
  tintColor: AppColors.neonGreen,
  child: Text('강조 카드'),
)

AppCard(
  variant: AppCardVariant.outlined,
  onTap: () {},
  child: Text('탭 가능 카드'),
)
```

**Variant**
- `surface` (기본) — surface 배경 + 라이트모드 border
- `tinted` — accent 색 6~10% 틴트
- `outlined` — 배경 transparent, border만

### 7.3 AppTextField

```dart
AppTextField(
  label: '이메일',
  hint: 'name@example.com',
  controller: _emailController,
  keyboardType: TextInputType.emailAddress,
  validator: (v) => v?.isEmpty ?? true ? '이메일을 입력하세요' : null,
)

AppTextField(
  label: '비밀번호',
  obscureText: true,
  prefixIcon: const Icon(Icons.lock_outline),
)
```

`InputDecorationTheme`을 따르므로 외곽선/포커스 색은 다크/라이트에서 자동 적용됩니다.

### 7.4 ConfirmDialog / showConfirmDialog

```dart
final ok = await showConfirmDialog(
  context,
  title: '리그를 종료할까요?',
  content: '종료 후엔 복구할 수 없습니다.',
  confirmText: '종료',
  confirmColor: AppColors.error,
);
if (ok) { /* ... */ }
```

### 7.5 showDeleteConfirmSheet (슬라이드 삭제)

파괴적 액션은 **다이얼로그 대신 슬라이드 시트**를 우선 사용합니다.

```dart
showDeleteConfirmSheet(
  context,
  title: '리그 삭제',
  content: '리그와 연결된 모든 게시물이 삭제됩니다.',
  slideLabel: '밀어서 삭제',
  onConfirmed: () => _delete(),
);
```

### 7.6 AppSnackBar (탑 배너)

기본 `SnackBar` 대신 화면 상단 슬라이드 배너:

```dart
AppSnackBar.success(context, '저장되었습니다');
AppSnackBar.error(context, '네트워크 오류');
AppSnackBar.info(context, '리그가 시작되었습니다');
```

### 7.7 SectionLabel

```dart
SectionLabel(text: '진행 중', color: AppColors.neonGreen)
```

### 7.8 InfoChip / InfoChipFilled

```dart
InfoChip(icon: Icons.location_on, label: '서울', color: sub)
InfoChipFilled(icon: Icons.timer, label: '3일', color: accent, isDark: isDark)
```

### 7.9 StatNumber / StatBox

```dart
StatNumber(value: '1,234', label: '팔로워', subColor: sub)
StatBox(icon: Icons.fish, value: '23', label: '조과', isDark: isDark, accent: accent)
```

### 7.10 EmptyState

```dart
EmptyState(
  icon: Icons.inbox,
  message: '아직 게시물이 없어요',
  subMessage: '첫 조과를 올려보세요',
  subColor: sub,
)
```

### 7.11 UserAvatar

```dart
UserAvatar(username: 'jun', avatarUrl: url, radius: 20, isDark: isDark)
```

### 7.12 AppSvg / AppIcons

```dart
AppSvg(AppIcons.fishingRod, size: 24, color: accent)
```

---

## 8. 상태(State) 표준

모든 인터랙티브 컴포넌트는 다음 상태를 처리합니다.

| 상태 | 시각적 처리 |
|---|---|
| **default** | 토큰 색 그대로 |
| **pressed / hovered** | InkWell ripple (Material) 또는 색상 5~10% 어둡게 |
| **disabled** | opacity 45% (`onPressed == null` 기준) |
| **loading** | 본문을 `CircularProgressIndicator`로 교체, 클릭 차단 |
| **selected** | accent 색 + accent 12~20% 틴트 배경 |
| **error** | 외곽선/배경 `AppColors.error` |

---

## 9. 패턴 / 가이드라인

### 9.1 새 UI 추가 시 체크리스트

1. **이미 있는 토큰/컴포넌트인가?** (`lib/core/theme/`, `lib/core/widgets/` 확인)
2. 색상은 `AppColors`, 사이즈는 `AppSpacing`/`AppRadius`로 표현 가능한가?
3. 같은 패턴이 **2회 이상 반복**되면 → 공용 컴포넌트로 추출하고 이 문서에 추가.
4. 라이트/다크 양쪽 동작 확인. 한쪽만 가정하지 말 것.
5. 새 컴포넌트는 반드시 **`isDark` 분기 또는 `Theme.of(context)` 참조**.

### 9.2 async + Navigator 패턴 (필수)

다이얼로그/시트에서 async 작업 시:

```dart
final messenger = ScaffoldMessenger.of(context);   // 1. 미리 캡처
Navigator.pop(dialogCtx);                          // 2. dialog context로 닫기
await Future.delayed(AppDurations.dialogClose);    // 3. 애니메이션 대기
await doWork();                                    // 4. 작업
AppSnackBar.success(context, '완료');               // 5. 피드백
ref.invalidate(someProvider);                      // 6. 마지막에 invalidate
```

### 9.3 색 사용 금지 사항

- `Color(0xFF...)` 인라인 작성 ❌ → `AppColors.*` 토큰
- `Colors.grey[400]` 등 Material grey ❌ → `AppColors.darkTextSub`/`lightTextSub`
- `Colors.red`, `Colors.green` ❌ → `AppColors.error`, `AppColors.success`

### 9.4 매직 넘버 금지

```dart
// ❌
Padding(padding: EdgeInsets.all(16))
SizedBox(height: 16)
borderRadius: BorderRadius.circular(12)

// ✅
Padding(padding: AppSpacing.pageAll)
AppSpacing.gapH16
borderRadius: AppRadius.brMd
```

### 9.5 버튼 스타일 인라인 금지

```dart
// ❌
ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.red,
    minimumSize: Size.fromHeight(52),
    ...
  ),
  child: Text('삭제'),
)

// ✅
AppButton(
  label: '삭제',
  variant: AppButtonVariant.destructive,
  onPressed: _delete,
)
```

---

## 10. 폴더 구조

```
lib/core/
  theme/
    app_colors.dart        ← 색상 토큰
    app_text_styles.dart   ← 타이포 토큰
    app_spacing.dart       ← 스페이싱 토큰
    app_radius.dart        ← 모서리 토큰
    app_elevation.dart     ← 그림자 토큰
    app_durations.dart     ← 애니메이션 시간 토큰
    app_theme.dart         ← ThemeData 통합
  widgets/
    app_button.dart        ← AppButton
    app_card.dart          ← AppCard
    app_text_field.dart    ← AppTextField
    confirm_dialog.dart    ← ConfirmDialog + showConfirmDialog
    slide_to_confirm.dart  ← SlideToConfirm + showDeleteConfirmSheet
    app_snack_bar.dart     ← AppSnackBar (탑 배너)
    section_label.dart     ← SectionLabel
    stat_widgets.dart      ← StatNumber / StatBox
    info_chip.dart         ← InfoChip / InfoChipFilled
    empty_state.dart       ← EmptyState
    user_avatar.dart       ← UserAvatar
    app_svg.dart           ← AppSvg / AppIcons
```

---

## 11. 변경 로그

이 섹션은 디자인 시스템에 추가/변경이 있을 때마다 누적합니다.

### 2026-04-26 — 초기 디자인 시스템 정립
- **Added**: `AppSpacing`, `AppRadius`, `AppElevation`, `AppDurations` 토큰
- **Added**: `AppButton` (4 variant × 3 size, loading/disabled 상태)
- **Added**: `AppCard` (3 variant)
- **Added**: `AppTextField`
- **Updated**: `AppTheme`에 `dialogTheme`/`bottomSheetTheme`/`snackBarTheme` 추가
- **Documented**: 본 문서 신설
