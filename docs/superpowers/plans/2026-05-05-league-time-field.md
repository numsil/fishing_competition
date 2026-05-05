# League Time Field Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 리그 개설 폼에 선택적 대회 시간(시작~종료) 입력을 추가하고, 리스트 카드·나의 리그 카드·상세 화면에 시간을 표시한다.

**Architecture:** `League` 모델의 `startTime`/`endTime`은 이미 `DateTime`이므로 DB 변경 없이 UI만 수정한다. 시간 미설정 시 `00:00`으로 저장되며, 표시 시 `hour == 0 && minute == 0` 조건으로 숨긴다.

**Tech Stack:** Flutter, Riverpod, intl (DateFormat), LucideIcons

---

## File Map

| 파일 | 역할 |
|------|------|
| `lib/features/league/presentation/screens/league_create_screen.dart` | 시간 picker state + UI 추가, submit 시 날짜+시간 조합 |
| `lib/features/league/presentation/screens/league_screen.dart` | `_LeagueItem` 카드에 시간 행 추가 |
| `lib/features/my_league/presentation/screens/my_league_screen.dart` | `_ActiveLeagueCard`, `_MyLeagueCard` 카드에 시간 행 추가 |
| `lib/features/league/presentation/screens/league_detail_screen.dart` | 상세 화면 날짜 행 아래 시간 행 추가 |

---

## Task 1: league_create_screen — state 및 submit 로직

**Files:**
- Modify: `lib/features/league/presentation/screens/league_create_screen.dart`

- [ ] **Step 1: `_startTime`, `_endTime` state 변수 추가**

`_LeagueCreateScreenState` 클래스의 state 변수 블록 (line ~41, `DateTimeRange? _dateRange;` 아래)에 추가:

```dart
TimeOfDay? _startTime;
TimeOfDay? _endTime;
```

- [ ] **Step 2: 편집 모드 initState에서 시간 복원**

`initState`의 편집 모드 블록 (line ~88, `_dateRange = DateTimeRange(...)` 아래)에 추가:

```dart
if (l.startTime.hour != 0 || l.startTime.minute != 0) {
  _startTime = TimeOfDay(hour: l.startTime.hour, minute: l.startTime.minute);
}
if (l.endTime.hour != 0 || l.endTime.minute != 0) {
  _endTime = TimeOfDay(hour: l.endTime.hour, minute: l.endTime.minute);
}
```

- [ ] **Step 3: submit 시 날짜+시간 조합 헬퍼 추가**

`_pickDateRange` 메서드 위에 private 헬퍼 추가:

```dart
DateTime _applyTime(DateTime date, TimeOfDay? time) {
  if (time == null) return date;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}
```

- [ ] **Step 4: `_submit` 에서 startTime/endTime을 조합값으로 교체**

`_submit` 메서드 안, `_dateRange!.start` / `_dateRange!.end`를 직접 쓰는 부분을 모두 `_applyTime(...)` 호출로 교체한다.

편집 모드 (line ~169):
```dart
startTime: _applyTime(_dateRange!.start, _startTime),
endTime: _applyTime(_dateRange!.end, _endTime),
```

생성 모드 (line ~205):
```dart
startTime: _applyTime(_dateRange!.start, _startTime),
endTime: _applyTime(_dateRange!.end, _endTime),
```

- [ ] **Step 5: 시간 picker 메서드 추가**

`_pickDateRange` 메서드 아래에 추가:

```dart
Future<void> _pickStartTime() async {
  final result = await showTimePicker(
    context: context,
    initialTime: _startTime ?? TimeOfDay.now(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
      child: child!,
    ),
  );
  if (result != null) setState(() => _startTime = result);
}

Future<void> _pickEndTime() async {
  final result = await showTimePicker(
    context: context,
    initialTime: _endTime ?? TimeOfDay.now(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
      child: child!,
    ),
  );
  if (result != null) setState(() => _endTime = result);
}
```

- [ ] **Step 6: 수동 확인**

`flutter analyze` 실행 후 에러 없는지 확인:
```bash
cd /Users/jun/Desktop/code/HUK/fishing_competition && flutter analyze lib/features/league/presentation/screens/league_create_screen.dart
```

- [ ] **Step 7: commit**

```bash
git add lib/features/league/presentation/screens/league_create_screen.dart
git commit -m "feat: 리그 개설 폼 시간 state/로직 추가"
```

---

## Task 2: league_create_screen — 시간 picker UI

**Files:**
- Modify: `lib/features/league/presentation/screens/league_create_screen.dart`

- [ ] **Step 1: 일정 섹션 날짜 picker 아래에 시간 행 UI 추가**

`league_create_screen.dart` 의 일정 섹션 (`_Section` 내부, `if (_showDateError)` 블록 아래, `], // mainAxisSize 닫기` 직전)에 추가:

```dart
const SizedBox(height: 10),
Row(
  children: [
    Expanded(
      child: GestureDetector(
        onTap: _pickStartTime,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: context.isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF8F8F8),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _startTime != null ? context.accentColor : divColor,
            ),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.clock, size: 14,
                  color: _startTime != null ? context.accentColor : sub),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _startTime != null
                      ? '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}'
                      : '시작 시간',
                  style: TextStyle(
                    fontSize: 13,
                    color: _startTime != null
                        ? (context.isDark ? Colors.white : Colors.black)
                        : sub,
                    fontWeight: _startTime != null ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (_startTime != null)
                GestureDetector(
                  onTap: () => setState(() => _startTime = null),
                  child: Icon(Icons.close_rounded, size: 14, color: sub),
                ),
            ],
          ),
        ),
      ),
    ),
    const SizedBox(width: 10),
    Expanded(
      child: GestureDetector(
        onTap: _pickEndTime,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: context.isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF8F8F8),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _endTime != null ? context.accentColor : divColor,
            ),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.clock, size: 14,
                  color: _endTime != null ? context.accentColor : sub),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _endTime != null
                      ? '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}'
                      : '종료 시간',
                  style: TextStyle(
                    fontSize: 13,
                    color: _endTime != null
                        ? (context.isDark ? Colors.white : Colors.black)
                        : sub,
                    fontWeight: _endTime != null ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (_endTime != null)
                GestureDetector(
                  onTap: () => setState(() => _endTime = null),
                  child: Icon(Icons.close_rounded, size: 14, color: sub),
                ),
            ],
          ),
        ),
      ),
    ),
  ],
),
```

**삽입 위치 정확히:** `league_create_screen.dart` line 761~769 사이:
```dart
// 이 코드 블록 바로 아래에 삽입
if (_showDateError)
  Padding(
    padding: const EdgeInsets.only(top: 6, left: 12),
    child: Text(
      '일정을 선택해주세요',
      style: TextStyle(fontSize: 12, color: AppColors.error),
    ),
  ),
],  // ← Column children 닫기
```

즉, `if (_showDateError)` Padding 블록 뒤, `],` 닫기 전에 삽입한다.

- [ ] **Step 2: analyze + 수동 확인**

```bash
cd /Users/jun/Desktop/code/HUK/fishing_competition && flutter analyze lib/features/league/presentation/screens/league_create_screen.dart
```

- [ ] **Step 3: commit**

```bash
git add lib/features/league/presentation/screens/league_create_screen.dart
git commit -m "feat: 리그 개설 폼 시작/종료 시간 picker UI 추가"
```

---

## Task 3: league_screen — 리스트 카드 시간 표시

**Files:**
- Modify: `lib/features/league/presentation/screens/league_screen.dart`

- [ ] **Step 1: `_LeagueItem`에 `startTime`, `endTime` 파라미터 추가**

`_LeagueItem` 클래스 (line ~221) 생성자 및 필드에 추가:

```dart
// 생성자 파라미터 추가
required this.startTime,
required this.endTime,

// 필드 추가
final DateTime startTime, endTime;
```

- [ ] **Step 2: `_LeagueItem` 카드 UI — 날짜 행 아래 시간 행 추가**

`build` 메서드 내 날짜 행 (`Icon(LucideIcons.calendar, ...)` Row) 아래에 추가:

```dart
if (startTime.hour != 0 || startTime.minute != 0 ||
    endTime.hour != 0 || endTime.minute != 0) ...[
  const SizedBox(height: 4),
  Row(
    children: [
      Icon(LucideIcons.clock, size: 12, color: sub),
      const SizedBox(width: 4),
      Text(
        '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}'
        ' ~ '
        '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
        style: TextStyle(fontSize: 12, color: sub),
      ),
    ],
  ),
],
```

- [ ] **Step 3: `_LeagueItem` 호출부에 파라미터 전달**

`league_screen.dart` 의 `_LeagueItem(...)` 호출 (line ~178)에 추가:

```dart
return _LeagueItem(
  id: l.id,
  title: l.title,
  location: l.location,
  date: startStr == endStr ? startStr : '$startStr ~ $endStr',
  participants: l.participantsCount,
  max: l.maxParticipants,
  prize: l.entryFee > 0
      ? '${NumberFormat('#,###').format(l.entryFee)}원'
      : '무료 참가',
  status: stat,
  rule: l.shortDescription ?? '',
  hostUsername: l.hostUsername,
  startTime: l.startTime,   // 추가
  endTime: l.endTime,       // 추가
);
```

- [ ] **Step 4: analyze**

```bash
cd /Users/jun/Desktop/code/HUK/fishing_competition && flutter analyze lib/features/league/presentation/screens/league_screen.dart
```

- [ ] **Step 5: commit**

```bash
git add lib/features/league/presentation/screens/league_screen.dart
git commit -m "feat: 리그 리스트 카드에 시간 표시"
```

---

## Task 4: my_league_screen — 카드 시간 표시

**Files:**
- Modify: `lib/features/my_league/presentation/screens/my_league_screen.dart`

### 4-A: `_ActiveLeagueCard` (참여 리그 카드, line ~392)

- [ ] **Step 1: `_ActiveLeagueCard` 날짜 행 아래 시간 행 추가**

`build` 메서드 내 날짜 행 (`Text('$startStr ~ $endStr', ...)`) 아래, `const SizedBox(height: 12),` 앞에 추가:

```dart
if (league.startTime.hour != 0 || league.startTime.minute != 0 ||
    league.endTime.hour != 0 || league.endTime.minute != 0) ...[
  const SizedBox(width: 12),
  Icon(LucideIcons.clock, size: 12, color: sub),
  const SizedBox(width: 4),
  Text(
    '${league.startTime.hour.toString().padLeft(2, '0')}:${league.startTime.minute.toString().padLeft(2, '0')}'
    ' ~ '
    '${league.endTime.hour.toString().padLeft(2, '0')}:${league.endTime.minute.toString().padLeft(2, '0')}',
    style: TextStyle(fontSize: 12, color: sub),
  ),
],
```

**삽입 위치:** `_ActiveLeagueCard.build` 의 "정보 행" `Row`의 children 마지막 (`Text('$startStr ~ $endStr', ...)` 뒤) 에 추가.

즉 line ~478 의 Row children:
```dart
Row(
  children: [
    Icon(LucideIcons.mapPin, ...),
    ...
    Text('$startStr ~ $endStr', ...),
    // ↑ 이 아래에 삽입
  ],
),
```

### 4-B: `_MyLeagueCard` (개설한 리그 카드, line ~1219)

- [ ] **Step 2: `_MyLeagueCard` 날짜 행 아래 시간 행 추가**

`_MyLeagueCard.build` 의 날짜 행 Row (`Text('$startStr ~ $endStr', ...)`) 뒤에 동일하게 추가:

```dart
if (league.startTime.hour != 0 || league.startTime.minute != 0 ||
    league.endTime.hour != 0 || league.endTime.minute != 0) ...[
  const SizedBox(width: 10),
  Icon(Icons.access_time_rounded, size: 12, color: sub),
  const SizedBox(width: 3),
  Text(
    '${league.startTime.hour.toString().padLeft(2, '0')}:${league.startTime.minute.toString().padLeft(2, '0')}'
    ' ~ '
    '${league.endTime.hour.toString().padLeft(2, '0')}:${league.endTime.minute.toString().padLeft(2, '0')}',
    style: TextStyle(fontSize: 12, color: sub),
  ),
],
```

**삽입 위치:** line ~1309 의 Row children 마지막.

- [ ] **Step 3: analyze**

```bash
cd /Users/jun/Desktop/code/HUK/fishing_competition && flutter analyze lib/features/my_league/presentation/screens/my_league_screen.dart
```

- [ ] **Step 4: commit**

```bash
git add lib/features/my_league/presentation/screens/my_league_screen.dart
git commit -m "feat: 나의 리그 카드에 시간 표시"
```

---

## Task 5: league_detail_screen — 상세 화면 시간 표시

**Files:**
- Modify: `lib/features/league/presentation/screens/league_detail_screen.dart`

- [ ] **Step 1: 날짜 Row 아래 시간 Row 추가**

`league_detail_screen.dart` line ~288~296 날짜 Row 바로 아래에 추가:

```dart
// 기존 날짜 행:
Row(children: [
  Icon(LucideIcons.calendar, size: 14, color: accent),
  const SizedBox(width: 4),
  Text(
    '${DateFormat('yyyy.MM.dd').format(league.startTime)}  ~  ${DateFormat('yyyy.MM.dd').format(league.endTime)}',
    style: TextStyle(fontSize: 13,
        color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub),
  ),
]),
// ↓ 아래에 추가
if (league.startTime.hour != 0 || league.startTime.minute != 0 ||
    league.endTime.hour != 0 || league.endTime.minute != 0) ...[
  const SizedBox(height: 4),
  Row(children: [
    Icon(LucideIcons.clock, size: 14, color: accent),
    const SizedBox(width: 4),
    Text(
      '${DateFormat('HH:mm').format(league.startTime)}  ~  ${DateFormat('HH:mm').format(league.endTime)}',
      style: TextStyle(fontSize: 13,
          color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub),
    ),
  ]),
],
```

- [ ] **Step 2: analyze**

```bash
cd /Users/jun/Desktop/code/HUK/fishing_competition && flutter analyze lib/features/league/presentation/screens/league_detail_screen.dart
```

- [ ] **Step 3: commit**

```bash
git add lib/features/league/presentation/screens/league_detail_screen.dart
git commit -m "feat: 리그 상세 화면에 시간 표시"
```

---

## Task 6: 최종 검증

- [ ] **Step 1: 전체 analyze**

```bash
cd /Users/jun/Desktop/code/HUK/fishing_competition && flutter analyze
```
오류 0개 확인.

- [ ] **Step 2: 수동 테스트 체크리스트**

1. 리그 개설 폼 → 날짜 선택 → 시작/종료 시간 버튼 표시 확인
2. 시작 시간 탭 → 24시간 형식 TimePicker 표시 → 선택 후 버튼에 시간 표시
3. X 버튼 탭 → 시간 초기화 확인
4. 시간 미설정 상태로 개설 → 카드에 시간 미표시 확인
5. 시간 설정 후 개설 → 리그 리스트 카드에 `⏰ 09:00 ~ 18:00` 표시 확인
6. 상세 화면에서 시간 행 표시 확인
7. 나의 리그 → 참여 리그 탭, 개설한 리그 탭 카드 시간 표시 확인
8. 편집 모드 진입 시 기존 시간 복원 확인
