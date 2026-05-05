# 리그 대회 시간 필드 추가 디자인

**날짜**: 2026-05-05  
**상태**: 승인됨

## 개요

리그 개설 폼에 대회 시작/종료 시간을 선택할 수 있는 UI를 추가하고, 리그 리스트 카드·나의 리그 카드·리그 상세 화면에서 시간을 표시한다. DB 스키마 변경 없음 (`startTime`/`endTime`이 이미 `DateTime`).

## 요구사항

- 시간 입력은 **선택(optional)** — 미입력 시 기존과 동일하게 동작
- 시간이 설정된 경우 카드/상세 화면에 `⏰ HH:mm ~ HH:mm` 형태로 표시
- 편집 모드에서 기존 시간값 복원

## 수정 파일 (4개)

### 1. `league_create_screen.dart`

**State 추가**
```dart
TimeOfDay? _startTime;
TimeOfDay? _endTime;
```

**initState 편집 모드 복원**
```dart
// hour/minute이 0이 아닐 때만 복원
if (l.startTime.hour != 0 || l.startTime.minute != 0) {
  _startTime = TimeOfDay(hour: l.startTime.hour, minute: l.startTime.minute);
}
if (l.endTime.hour != 0 || l.endTime.minute != 0) {
  _endTime = TimeOfDay(hour: l.endTime.hour, minute: l.endTime.minute);
}
```

**UI — 일정 섹션 날짜 picker 아래에 추가**
```
[ 📅  2026.05.10  ~  2026.05.11  ]
[ ⏰  [시작 시간 미설정 / 09:00 ✕]   [종료 시간 미설정 / 18:00 ✕] ]
```
- 두 버튼을 Row로 나란히 배치
- 탭 → `showTimePicker`
- 설정된 경우 X 아이콘으로 개별 초기화

**submit 시 날짜+시간 조합**
```dart
final start = _startTime != null
  ? DateTime(dateRange.start.year, dateRange.start.month, dateRange.start.day,
      _startTime!.hour, _startTime!.minute)
  : dateRange.start;
final end = _endTime != null
  ? DateTime(dateRange.end.year, dateRange.end.month, dateRange.end.day,
      _endTime!.hour, _endTime!.minute)
  : dateRange.end;
```

### 2. `league_screen.dart`

**`_LeagueItem` 파라미터 추가**
```dart
final DateTime startTime;
final DateTime endTime;
```

**카드 UI — 날짜 행 아래 조건부 시간 행**
```dart
if (startTime.hour != 0 || startTime.minute != 0 ||
    endTime.hour != 0 || endTime.minute != 0) ...[
  const SizedBox(height: 4),
  Row(children: [
    Icon(LucideIcons.clock, size: 12, color: sub),
    const SizedBox(width: 4),
    Text('${_fmtTime(startTime)} ~ ${_fmtTime(endTime)}',
        style: TextStyle(fontSize: 12, color: sub)),
  ]),
]
```

### 3. `my_league_screen.dart`

`_ActiveLeagueCard` 및 `_MyLeaguesTab` 카드 (392, 1219번 줄 근처) 동일하게 시간 행 추가.

### 4. `league_detail_screen.dart`

날짜 Row (289번 줄) 아래에 시간 Row 추가:
```dart
if (league.startTime.hour != 0 || league.startTime.minute != 0 ||
    league.endTime.hour != 0 || league.endTime.minute != 0) ...[
  const SizedBox(height: 4),
  Row(children: [
    Icon(LucideIcons.clock, size: 14, color: accent),
    const SizedBox(width: 4),
    Text(
      '${DateFormat('HH:mm').format(league.startTime)}  ~  ${DateFormat('HH:mm').format(league.endTime)}',
      style: TextStyle(fontSize: 13, color: ...),
    ),
  ]),
]
```

## 시간 표시 헬퍼

```dart
String _fmtTime(DateTime dt) => DateFormat('HH:mm').format(dt);
```

## 비고

- DB 변경 없음
- 기존 데이터(시간=00:00)는 시간 미표시로 처리되어 하위 호환 유지
