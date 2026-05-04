# Components Guide

## 원칙

- 반복 UI는 반드시 공용 컴포넌트 사용
- 복붙 금지

---

## Widgets (lib/core/widgets/)

- AppButton: 표준 버튼
- AppCard: 카드 UI
- AppTextField: 입력 필드
- ConfirmDialog: 확인 다이얼로그
- AppSnackBar: 알림
- SectionLabel: 섹션 타이틀
- StatWidgets: 통계 UI
- InfoChip: 칩 UI
- EmptyState: 빈 화면
- SlideToConfirm: 삭제 슬라이드
- UserAvatar: 유저 아바타
- AppSvg / AppIcons: 아이콘 시스템

---

## 규칙

- ElevatedButton 직접 사용 금지 → AppButton 사용
- Container + BoxDecoration 카드 UI 금지 → AppCard 사용