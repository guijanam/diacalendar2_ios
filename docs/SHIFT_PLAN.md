# DiaCalendar2 iOS — 교번(교대)근무 관리 기능

> 상태: ✅ **1차 구현 완료** (2026-05-11, iPhone 17 시뮬레이터 빌드 성공)
> 다음 작업은 이 문서의 "다음 작업" 섹션부터 이어가면 됨.

---

## 1. 배경 / 목적

DiaCalendar2 iOS 앱(SwiftUI + SwiftData + Yotei)에 **열차승무원 교번근무 관리 기능**을 추가했다.
- Android 리빌드 프로젝트(`/Users/heebum/Desktop/MyProject/playstore/DiaCalendar2`)의 검증된 구현을 포팅
- 기존 iOS 앱(`/Users/heebum/Documents/AppStore Project/DiaCalendar`)에서 Supabase 네트워크 코드 패턴 차용
- Supabase 백엔드는 `https://srsyxsddjbojnwvjoera.supabase.co` 그대로 사용

## 2. 핵심 흐름

1. Supabase `office`, `dia` 두 테이블에서 승무소/근무 마스터 데이터를 fetch
2. 사용자가 Settings → 교번근무 설정에서 5단계 입력
   (승무소 → 포지션 → 시작일 → 기준일+기준근무 → 생성)
3. 회전 알고리즘으로 3년치 일자별 근무 스케줄 생성 후 SwiftData에 저장
4. CalendarAggregator가 ShiftScheduleRepository를 조회해 캘린더 셀에 교번 뱃지 표시
5. 날짜를 탭하면 DayDetailSheet에 Dia 정보(출근시간, 전반/후반, 열차번호, 근무표 이미지) 표시
6. 교번교체(Swap) / 충당(ShiftInput) 오버레이 기능 사용 가능

---

## 3. 결정사항 (최종)

| 항목 | 결정 |
|------|------|
| 작업 범위 | 전체 기능 (5단계 설정 + 회전 + 캘린더 표시 + 날짜 상세 + 교체/충당 + 커스텀 교번) |
| 설정 UI 위치 | Settings 탭 안에 "근무 설정" 섹션 |
| Supabase 접근 | URLSession + Codable (Supabase SDK 미사용) |
| 데이터 모델 | Android와 동일 구조로 신규 설계 (기존 `WorkShift`는 schema에만 남기고 미사용) |
| 캘린더 표시 | CalendarAggregator에서 ShiftSchedule을 직접 조회해 종일 EventData(.shift) 생성 |
| 환경변수 | `SupabaseConfig.swift` 상수 (추후 `.xcconfig` 이동 예정) |
| 시간대 | 모든 일자 계산은 `Asia/Seoul` Calendar 기준. ShiftSchedule.date는 KST 자정 |

---

## 4. 추가/수정된 파일 (구현 완료)

### A. 신규 파일

**Network / Domain**
- `DiaCalendar2/Network/SupabaseConfig.swift` — URL/anonKey 상수
- `DiaCalendar2/Network/SupabaseAPI.swift` — `listOffices()`, `office(named:)`, `dias(officeName:)`
- `DiaCalendar2/Domain/OfficeDTO.swift` — Supabase row + PostgreSQL/JSON 배열 디코딩
- `DiaCalendar2/Domain/DiaDTO.swift`
- `DiaCalendar2/Domain/OfficeRecordDTO.swift`, `DiaRecordDTO.swift`
- `DiaCalendar2/Domain/UserShiftConfigDTO.swift` (with `ShiftPosition` enum)
- `DiaCalendar2/Domain/ShiftScheduleDTO.swift`
- `DiaCalendar2/Domain/ShiftSwapRecordDTO.swift`
- `DiaCalendar2/Domain/ShiftInputTypeDTO.swift` (with `ShiftInputDefaults`)
- `DiaCalendar2/Domain/ShiftInputRecordDTO.swift`
- `DiaCalendar2/Domain/CustomShiftDTO.swift`
- `DiaCalendar2/Domain/ShiftDayInfo.swift` — DayDetail용 집계 모델

**SwiftData 모델 (8종)** — `DiaCalendar2/Persistence/Models/`
- `OfficeRecord` — `@Attribute(.unique) officeCode: Int64`, dia_turnsN/sub_turns/dia_selects는 CSV로 저장
- `DiaRecord` — office별 근무 상세 (출근시간, 전반/후반, 열차번호, 근무표 이미지 URL 등)
- `UserShiftConfig` — singleton(id="singleton"), position/패턴/시작일/기준일/기준근무
- `ShiftSchedule` — `@Attribute(.unique) date: Date`, `shiftName: String` (3년치)
- `ShiftSwapRecord` — 날짜별 교번교체 1건
- `ShiftInputType` — 충당 유형 catalog (대기/휴무/지근)
- `ShiftInputRecord` — 날짜별 충당 기록 (그룹 ID로 멀티데이 묶음)
- `CustomShift` — 사용자 정의 교번 (예: 4조2교대)

CSV 변환 헬퍼: `csvToList(_:)`, `listToCsv(_:)` (OfficeRecord.swift에 nonisolated로 선언)

**Services**
- `Services/ShiftPatternParser.swift` — `parse(_:)` 한 함수로 PostgreSQL `{}` / JSON `[]` / CSV / 큰따옴표 모두 처리
- `Services/ShiftRotationEngine.swift` — **회전 알고리즘 핵심**. `rotate(pattern:startDate:referenceDate:todayShift:todayShiftIndex:years:)`. 음수 모듈러 안전 처리 (`((x % n) + n) % n`). `nonisolated`로 표시해 actor 컨텍스트에서 자유롭게 호출 가능
- `Services/ShiftColor.swift` — Android `ShiftBadge.kt`의 색상 매핑 포팅. `ShiftColor.colorHex(for:isSwap:)`
- `Services/ShiftSyncService.swift` — Supabase 호출 + Office/Dia upsert

**Repositories (8종)** — `DiaCalendar2/Repositories/`, 모두 `@ModelActor`
- `OfficeRecordRepository` — `all()`, `office(code:)`, `office(name:)`, `upsert(_:)`
- `DiaRecordRepository` — `replaceAll(forOffice:with:)`, `dias(forOffice:)`, `dia(officeName:diaId:)`
- `UserShiftConfigRepository` — singleton load/save/clear
- `ShiftScheduleRepository` — `schedules(in:)`, `schedule(on:)`, `count()`, `deleteFrom(date:)`, `deleteAll()`, `upsert(_:)`, **`generateAndSave(...)`** (회전 + 1000개 chunk 저장)
- `ShiftSwapRecordRepository` — `swap(on:)`, `swaps(in:)`, `upsert(...)`, `delete(on:)`
- `ShiftInputTypeRepository` — `seedDefaultsIfNeeded()`, `all()`, `type(id:)`
- `ShiftInputRecordRepository` — `record(on:)`, `records(in:)`, `createRun(...)` (회전 충당), `delete(on:)`, `deleteGroup(_:)`
- `CustomShiftRepository` — `all()`, `shift(id:)`, `upsert(...)`, `delete(id:)`

**UI**
- `TabViews/Settings/Shift/ShiftSetupView.swift` — 5단계 설정 폼 (서버 승무소) / 4단계 (커스텀)
- `TabViews/Settings/Shift/ShiftSetupViewModel.swift` — `@Observable`. 상태 + bootstrap + selectOffice + save
- `TabViews/Settings/Shift/CustomShiftListView.swift` — 교대근무 목록 + `CustomShiftEditView` (이름/패턴 CSV 편집)
- `TabViews/Calendar/Sheets/ShiftSwapSheet.swift` — 교번교체
- `TabViews/Calendar/Sheets/ShiftInputSheet.swift` — 충당 등록 (유형/일수/대상 교번)

### B. 수정된 파일

- `DiaCalendar2App.swift` — ModelContainer schema에 8개 신규 모델 등록 (WorkShift는 유지)
- `Services/AppEnvironment.swift` — 8개 신규 repository + `ShiftSyncService` 추가. 부팅 시 `seedDefaultsIfNeeded()` 호출. `Notification.Name.shiftScheduleDidUpdate` 정의
- `ContentView.swift` — FullCalendarView에 신규 repository 7종 주입, Preview schema 갱신
- `TabViews/Settings/SettingsView.swift` — "근무 설정" Section 추가 (`ShiftSetupView`, `CustomShiftListView`로 NavigationLink)
- `TabViews/Calendar/CalendarView.swift` — FullCalendarView init 시그니처 확장, `.shiftScheduleDidUpdate` 노티 구독, `ShiftSwapSheet`/`ShiftInputSheet` 케이스 sheetContent에 추가
- `TabViews/Calendar/CalendarViewModel.swift` — repo prop 추가, `CalendarSheet`에 `.shiftSwap`/`.shiftInput` 케이스, `shiftDayInfo(on:)`, `createSwap`, `createShiftInput`, `deleteOverlay`, `pickBestDia`(요일 가중치) 메서드
- `Services/CalendarAggregator.swift` — `merge` 시그니처 변경 (`shifts: [ShiftScheduleDTO]`, `swaps`, `inputs` 추가). 종일 이벤트 UTC 자정 매핑 (메모 패턴 그대로)
- `TabViews/Calendar/Sheets/DayDetailSheet.swift` — `loadShiftInfo`, `onCreateSwap`, `onCreateInput`, `onDeleteOverlay` prop 추가. 근무 섹션 추가 (`shiftHeader`, `diaDetail` — `firstTime+numTr1`, `secondTime+numTr2`, `thirdTime`이 URL이면 `AsyncImage`)

---

## 5. 회전 알고리즘 (요약)

`ShiftRotationEngine.rotate(...)` 핵심:

```swift
let refIndex = todayShiftIndex ?? pattern.firstIndex(of: todayShift)!
let daysFromRefToStart = cal.dateComponents([.day], from: refDay, to: startDay).day ?? 0
let totalDays = cal.dateComponents([.day], from: startDay, to: endDay).day! + 1

for offset in 0..<totalDays {
    let totalOffset = daysFromRefToStart + offset
    let raw = (refIndex + totalOffset) % size
    let idx = (raw + size) % size  // 음수 보정
    out.append(ShiftScheduleDTO(date: cal.date(byAdding: .day, value: offset, to: startDay)!,
                                shiftName: pattern[idx]))
}
```

`ShiftScheduleRepository.generateAndSave(...)`는:
- `startDate` 이전 스케줄은 **보존**
- `startDate` 이후만 `deleteFrom(date:)` → rotate 결과를 1000개 chunk로 upsert
- `NotificationCenter`에 `.shiftScheduleDidUpdate` 발송 → CalendarView 자동 리로드

---

## 6. 효과적 교번 우선순위 (오버레이)

CalendarAggregator와 DayDetailSheet에서 동일 로직:

```
priority high → low
1. ShiftInputRecord (충당)         → shortName 표시, colorHex 사용
2. ShiftSwapRecord (교번교체)      → swappedShiftName 표시, 주황색
3. ShiftSchedule (기본 생성근무)   → shiftName 표시, ShiftColor 매핑
```

`ShiftDayInfo.effectiveShiftName` / `effectiveColorHex` 가 이 우선순위를 캡슐화한다.

---

## 7. 해결한 함정

### Yotei 종일 이벤트의 UTC 해석
**증상:**
1. 11일 36근무가 캘린더에 10일에 표시됨 (shift)
2. 동기화된 외부 캘린더(Google 공휴일 등)의 종일 이벤트가 5/15 → 5/14로 하루 전 표시됨 (EK 이벤트)

**원인:** Yotei는 `isAllDay: true` 이벤트의 `start`를 **UTC 자정 기준**으로 해석한다.
- ShiftSchedule.date는 KST 자정(=UTC 15:00 전날)이라 하루 전으로 인식.
- EventKit도 외부 계정의 종일 이벤트 `startDate`/`endDate`를 사용자 로컬 timezone(KST) 자정으로 반환하므로 같은 함정.

**해결:** `CalendarAggregator.swift`에서 모든 종일 이벤트(shift / memo / EK 이벤트 셋 다)의 `start`를 `calendar.dateComponents([.year,.month,.day], from: date)` → `utcCalendar.date(from:)` 로 다시 매핑. swap/input lookup key도 같은 UTC day로 통일.

EK 이벤트의 경우 `endDate`가 다음 날 자정(exclusive end)으로 올 수도 있고 23:59:59로 올 수도 있어, `endIsMidnight` 체크로 inclusive 종료일을 계산한 뒤 `+1일` 해 exclusive end로 다시 만듦.

```swift
func dayKey(_ date: Date) -> Date? {
    let components = calendar.dateComponents([.year, .month, .day], from: date)
    return utcCalendar.date(from: components)
}
```

확인된 케이스:
- ✅ shift 뱃지 (직접 생성한 ShiftSchedule)
- ✅ memo (사용자가 등록한 종일 메모)
- ✅ EK 동기화 종일 이벤트 (Google 공휴일 캘린더 5/15 → 5/15로 표시 확인, 2026-05-11)

### actor / @MainActor 격리 경고
ShiftRotationEngine과 csv 헬퍼들이 `@MainActor` 컨텍스트에서 호출되면 actor repository에서 경고가 났다. `nonisolated` 키워드로 명시해 정리.

---

## 8. 검증 절차

### 빌드
```bash
cd "/Users/heebum/Documents/AppStore Project/DiaCalendar2"
xcodebuild -scheme DiaCalendar2 \
  -destination "platform=iOS Simulator,name=iPhone 17,OS=26.2" \
  -configuration Debug build
```
✅ 경고 0 / 에러 0 / **BUILD SUCCEEDED**

### 시뮬레이터 수동 테스트 (완료)
1. Settings 탭 → "교번근무 설정" 진입
2. 승무소 선택 (Supabase에서 fetch, 검색 가능)
3. 포지션 (기관사/차장/4조2교대) → 자동으로 패턴 표시
4. 시작일 / 기준일 / 기준교번 선택
5. "근무 생성" → 캘린더 탭으로 돌아가 셀에 교번 표시
6. ✅ 날짜 탭 → DayDetailSheet에 Dia 정보(출근/전반/후반/이미지) 표시
7. ✅ 교번교체 / 충당 버튼 → 시트로 등록 가능

---

## 9. 다음 작업 (TODO)

### 우선순위 높음
1. **Supabase anon key 분리** — 현재 `SupabaseConfig.swift` 상수. `.xcconfig` + `Info.plist`로 이동
2. **회전 알고리즘 단위 테스트** — `ShiftRotationEngineTests`:
   - pattern=["A","B","C"], refDate=2026-05-11, todayShift="A", startDate=2026-05-11 → 첫 7일 ["A","B","C","A","B","C","A"]
   - startDate가 referenceDate보다 과거일 때 (음수 모듈러)
   - `ShiftPatternParser` 테스트: `"{1,2,비}"`, `"[\"1\",\"2\",\"비\"]"`, `"1,2,비"`, nil, `"{}"`, `"[]"`

### 우선순위 중간
3. **충당 originalShift 백필** — `CalendarViewModel.createShiftInput`에서 현재 빈 문자열로 두는 originalShiftName을 미리 fetch해서 넘기도록 (한 번의 actor 호출로)
4. **충당 그룹 단위 삭제 UI** — 멀티데이 충당을 하루만 지우는 게 아니라 그룹 전체 삭제 옵션 (`deleteGroup(_:)`는 이미 있음)
5. **시작일 변경 시 알림** — 기존 설정이 있을 때 "시작일 이전 스케줄은 유지됩니다" 안내를 좀 더 명확히

### 우선순위 낮음
6. **레거시 `WorkShift` 모델 완전 제거** — 현재 schema에만 남아있고 미사용. 마이그레이션 안정성 확인 후 제거
7. **기본 캘린더 뷰 옵션** — 교번을 항상 보여주는 사람을 위한 "캘린더 진입 시 기본 뷰" 설정
8. **위젯/Wear OS 연동** — Android PRD에서 Premium 기능으로 명시됨
9. **`.diacal` 파일 import/export** — Android PRD에 있는 P2P 공유 포맷
10. **소속/직급/이름 같은 사용자 프로필 입력** — 일정 공유 시 필요

### 기술 부채
- **CustomShift의 officeCode 매핑** — 현재 UUID hash 일부를 음수 Int64로 변환. 충돌 가능성 낮지만 결정론적이지 않을 수 있음. UserShiftConfig에 별도 `customShiftId: UUID?` 필드 추가하는 게 더 안전
- **Sheet 전환 시 pendingSheet 패턴** — DayDetailSheet → ShiftSwapSheet 전환 시 dismiss → onDismiss → pending 의존. 깔끔하지만 race가 있을 수 있으므로 SwiftUI iOS 17+의 `sheet(item:onDismiss:)` 동작을 다시 확인 필요

---

## 10. 관련 파일 빠른 인덱스

| 파일 | 역할 |
|------|------|
| `Services/ShiftRotationEngine.swift` | 회전 알고리즘 (단위 테스트 후보) |
| `Services/ShiftSyncService.swift` | Supabase ↔ 로컬 동기화 |
| `Services/CalendarAggregator.swift:46-95` | 종일 이벤트 UTC 매핑 + 우선순위 오버레이 |
| `Repositories/ShiftScheduleRepository.swift:66-86` | `generateAndSave` 진입점 |
| `TabViews/Settings/Shift/ShiftSetupView.swift` | 5단계 UI |
| `TabViews/Calendar/CalendarViewModel.swift` | `shiftDayInfo`, swap/input 액션 |
| `TabViews/Calendar/Sheets/DayDetailSheet.swift` | 근무 카드 (Dia 정보 렌더) |
| `Domain/UserShiftConfigDTO.swift` | `ShiftPosition` enum + `pattern(in:)` |
| `Domain/ShiftDayInfo.swift` | 우선순위 캡슐화 |

---

## 11. Supabase 테이블 메모 (참고용)

### `office`
- `office_code: Int8` (PK), `office_name: text`
- `dia_turns1: text` (기관사 패턴, PostgreSQL `{}` 또는 JSON `[]` 형식)
- `dia_turns2: text` (차장 패턴)
- `dia_turns3: text` (기타)
- `sub_turns: text` (4조2교대 패턴)
- `dia_selects: text` (기준교번 선택 옵션. 비어있으면 패턴 사용)

### `dia`
- `id: Int8` (PK), `dia_id: text` (교번명, 예: "36"), `office_name: text`, `office_id: Int4`
- `type_name: text` (평일/토/일/휴 등 — 같은 dia_id에 여러 row 있을 수 있음)
- `work_time`, `first_time`, `num_tr1`, `second_time`, `num_tr2`, `third_time`, `total_time`
- `third_time`이 URL이면 근무표 이미지 (DayDetailSheet에서 AsyncImage로 표시)

### `holidays`
- `locdate: text` ("yyyy-MM-dd" 또는 "yyyyMMdd")
- `datename: text` (한국어 공휴일 이름)

---

## 12. 공휴일 표시 기능 (✅ 완료)

대한민국 공휴일을 Supabase `holidays` 테이블에서 fetch 해 캘린더에 빨강으로 강조.

### 동작
- 부팅 시 `HolidaySyncService.refreshIfNeeded()` — `SyncState.lastHolidaySyncAt` 이 24h 이상 경과면 fetch (`SupabaseAPI.listHolidays()` → `HolidayDTO` → KST 자정 Date 로 정규화 → `HolidayRepository.replaceAll(...)`)
- `Notification.Name.holidaysDidUpdate` 발송 → CalendarView 가 받아 `viewModel.loadHolidays()` + `reloadEvents()`
- `FullCalendarViewModelModel.holidaysByDate: [Date: String]` 메모리 맵 / `holidayName(on:)` 헬퍼
- 월 셀 / 주 헤더 셀이 cell view 안에서 holidayLookup 클로저로 룩업해 색을 결정

### 색 우선순위 (`HolidayColors.dayNumberColor(...)`)
out-of-month > today > focused > 공휴일/일요일 (red) > 토요일 (blue) > 평일 (primary)

### 주요 파일
| 파일 | 역할 |
|------|------|
| `Network/SupabaseAPI.swift:74-77` | `listHolidays()` |
| `Services/HolidaySyncService.swift` | 24h refresh + Date 파싱 |
| `Repositories/HolidayRepository.swift` | `replaceAll`, `map()` |
| `Persistence/Models/HolidayRecord.swift` | SwiftData 모델 (date unique, KST 자정) |
| `Persistence/Models/SyncState.swift` | `lastHolidaySyncAt` 추가 |
| `Domain/CalendarDayMeta.swift` | `WeekdayKind`, `HolidayPalette`, `HolidayColors.dayNumberColor(...)` |
| `TabViews/Calendar/Factories/CalendarViewFactories.swift` | `DiaMonthViewFactory`(holidayLookup, calendar), `DiaWeekdayViewFactory` 신규 |
| `TabViews/Calendar/Factories/Components/DiaMonthDayCellView.swift` | 월 셀 — 숫자 색 + 아래에 작은 빨강 공휴일 이름 |
| `TabViews/Calendar/Factories/Components/DiaWeekdayDayCellView.swift` | 주 헤더 — 색만 |
| `TabViews/Calendar/CalendarView.swift` | factory computed property + `YoteiWeekdaysView(... viewFactory: weekdayFactory)` + `.holidaysDidUpdate` 구독 |
| `TabViews/Calendar/CalendarViewModel.swift` | `holidaysByDate`, `loadHolidays()`, `holidayName(on:)` |

### 검증
- 부팅 → 콘솔에서 fetch (네트워크 가능 시)
- 월간 뷰: 신정/삼일절/광복절/추석 등이 빨강, 그 아래 작은 빨강 이름. 일요일 빨강, 토요일 파랑
- 주 뷰: 헤더 날짜 셀에 같은 색 규칙 적용 (이름 없음)
- Today 가 공휴일이어도 today highlight 우선

### 한계 / 다음 작업 후보
- 일(Day) 뷰의 strip 헤더는 Yotei `YoteiStripContainerView` 내부 컴포넌트로 직접 커스터마이즈 불가
- 스케줄 뷰의 section header (formatted date string) 도 별도 처리 필요 — 현재 미적용
- `holidays.isHoliday`("Y"/"N") 컬럼은 일단 무시 (전체 row를 공휴일로 취급)

---

## 13. 근태 (휴가) 기능 (✅ 완료)

연차/병가/경조사/출장 등 휴가를 일자별로 등록해 캘린더에 빨강으로 표시. 충당 파이프라인을 미러링했지만 회전 없이 모든 날 같은 휴가명이 적용되며, 종류는 사용자가 직접 CRUD (이름 + 약어, 색은 빨강 고정).

### 동작
- 부팅 시 `AttendanceTypeRepository.seedDefaultsIfNeeded()`로 연차/병가/경조사/출장 4종 자동 시드 (이미 있으면 skip)
- Settings → "휴가 종류 편집" 에서 추가/편집/삭제 (`AttendanceTypeListView` + `AttendanceTypeEditView`)
- 캘린더 셀 탭 → DayDetailSheet → "근태" 액션 버튼 (CustomShift 모드 포함 항상 표시)
- AttendanceSheet: 시작일(disabled) + 휴가 종류 picker + 일수 picker(1~10)
- `AttendanceRecordRepository.createRun(...)` — groupId로 묶인 N개 record 생성, 모든 날 동일한 name/shortName
- 오버레이 우선순위: **휴가 > 충당 > 교번교체 > 베이스** (`CalendarAggregator` + `ShiftDayInfo`)
- "되돌리기" 버튼이 attendance 도 같이 제거

### 데이터 스냅샷
`AttendanceRecord` 는 `attendanceTypeId` 외에 `name`/`shortName` 도 별도 저장 (스냅샷). 사용자가 종류를 삭제해도 이미 등록된 휴가는 정상 표시 유지.

### 색상
모든 휴가는 `HolidayPalette.red` (`#D9322F`) 로 고정. `ShiftDayInfo.attendanceColorHex` 상수로 단일화.

### 주요 파일
| 파일 | 역할 |
|------|------|
| `Persistence/Models/AttendanceType.swift` | 사용자 정의 휴가 종류 |
| `Persistence/Models/AttendanceRecord.swift` | 일자별 휴가 (스냅샷 필드 포함) |
| `Domain/AttendanceTypeDTO.swift` | DTO + `AttendanceDefaults` 시드 |
| `Domain/AttendanceRecordDTO.swift` | DTO |
| `Repositories/AttendanceTypeRepository.swift` | CRUD + seedDefaultsIfNeeded |
| `Repositories/AttendanceRecordRepository.swift` | `createRun`(회전 없음), `delete`, `deleteGroup` |
| `Services/AppEnvironment.swift` | 두 repo + seed |
| `Services/CalendarAggregator.swift` | `attendances` 파라미터 + 최상위 우선순위 + ShiftSchedule 없는 attendance-only 일자도 별도 셀 생성 |
| `Domain/ShiftDayInfo.swift` | `attendance` 필드 + `effectiveShiftName`/`effectiveColorHex` 최상위 분기 |
| `TabViews/Calendar/CalendarViewModel.swift` | `createAttendance`, `availableAttendanceTypes`, `.attendance` enum, shiftDayInfo/deleteOverlay 확장 |
| `TabViews/Calendar/CalendarView.swift` | init 확장, `.attendance` 시트 케이스, `.dayDetail` onCreateAttendance |
| `TabViews/Calendar/Sheets/AttendanceSheet.swift` | 등록 시트 |
| `TabViews/Calendar/Sheets/DayDetailSheet.swift` | "근태" 버튼 + restoreButton 조건 확장 |
| `TabViews/Settings/Shift/AttendanceTypeListView.swift` | CRUD 화면 |
| `TabViews/Settings/SettingsView.swift` | "휴가 종류 편집" 진입점 |
| `DiaCalendar2App.swift` / `ContentView.swift` | schema + repo 주입 |

### 검증
1. 첫 부팅 → Settings → "휴가 종류 편집" → 연차/병가/경조사/출장 4종 확인
2. 캘린더 셀 → DayDetailSheet → "근태" → "연차" + 3일 → 시작일부터 3일 빨강 "연" 표시
3. 같은 날 이미 충당/교번교체 등록되어 있어도 휴가가 가장 위로 표시
4. 휴가 종류 편집/추가/삭제 모두 동작 + 이미 등록된 휴가는 스냅샷 필드로 정상 표시 유지
5. "되돌리기" 탭 시 휴가/충당/교체 모두 제거
