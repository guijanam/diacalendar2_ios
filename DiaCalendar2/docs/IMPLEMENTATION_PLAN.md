# DiaCalendar2: SwiftData + EventKit + Supabase 통합 구현 계획

## Context

DiaCalendar2는 [Yotei](https://github.com/claustrofob/Yotei) SwiftUI 캘린더 라이브러리를 사용해 만들고 있는 iOS 26 타겟 일정/메모 앱이다. 현재 캘린더 UI(월/주/일/스케줄 뷰, 드래그 리스케줄, 타임존 선택, 탭바 애니메이션)는 거의 완성되었으나, **실제 데이터 저장이 없다.** [EventsLocalRepository](DiaCalendar2/Repositories/EventsLocalRepository.swift)는 30개 영문 더미 타이틀로 매번 랜덤 이벤트를 생성하는 mock generator일 뿐이며, 메모리에만 캐시되고 앱 재실행 시 사라진다. [EventData](DiaCalendar2/Domain/EventData.swift)는 빈 구조체이고, App 진입점에 ModelContainer가 없으며, Supabase/EventKit 코드는 전혀 없는 상태다.

이 계획은 그 위에:
1. **SwiftData**로 영구 저장소를 깔고 더미 코드를 완전히 제거한다.
2. **메모(날짜 메모 + 이벤트 노트)** 와 **이벤트** CRUD를 붙인다.
3. **iOS EventKit과 양방향 동기화**한다 (시스템 캘린더 ↔ 앱 일정).
4. **Supabase에서 근무시간표(WorkShift)** 를 별도 모델로 받아와 캘린더에 함께 표시한다.

목표 결과: 빈 캘린더로 시작 → 사용자가 일정/메모 직접 작성 → 시스템 캘린더와 자동 동기화 → 서버의 근무표가 자동 반영.

---

## 1. SwiftData 모델

`DiaCalendar2/Persistence/Models/` 신규 디렉토리에 정의. iOS 26 SwiftData에서 `@Model` 인스턴스는 `Sendable`이 아니므로, actor 경계 너머로는 항상 **Sendable DTO** 로 변환해 전달한다.

### Event (사용자 일정)
```
@Model final class Event {
    @Attribute(.unique) var id: UUID
    var title: String
    var start: Date
    var end: Date
    var isAllDay: Bool
    var notes: String?              // 이벤트별 노트
    var colorHex: String?
    var sourceRaw: String           // EventSource: .local / .eventKit
    var ekEventIdentifier: String?  // EventKit 매핑 키
    var ekCalendarIdentifier: String?
    var createdAt: Date
    var updatedAt: Date             // last-write-wins 충돌 해소
    var isDeletedTombstone: Bool    // EK 삭제 동기화용 soft delete
}
```

### WorkShift (Supabase 근무시간표 캐시)
```
@Model final class WorkShift {
    @Attribute(.unique) var id: UUID
    var supabaseId: UUID            // 서버 row와 1:1
    var date: Date                  // startOfDay
    var startTime: Date
    var endTime: Date
    var shiftCode: String           // "주간"/"야간"/"휴무" 등
    var colorHex: String?
    var note: String?
    var updatedAt: Date             // 서버 updated_at 비교용
}
```

### DateMemo (날짜 다이어리)
```
@Model final class DateMemo {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var dayKey: String  // "yyyy-MM-dd@TZID"
    var date: Date                          // startOfDay
    var body: String
    var updatedAt: Date
}
```
하루 1개 메모. `dayKey`로 빠른 lookup, 타임존 변경 시 키 일관성 유지.

### SyncState (싱글톤 메타)
```
@Model final class SyncState {
    @Attribute(.unique) var id: String = "singleton"
    var lastSupabaseShiftSyncAt: Date?
    var defaultEKCalendarIdentifier: String?
}
```

### 보조 값타입 (Sendable)
- `EventSource: String, Codable { case local, eventKit }`
- `EventDTO`, `WorkShiftDTO`, `DateMemoDTO`: `@Model` 누출 방지용 스냅샷 struct
- `EventDraft`: 에디터 입력 모델

---

## 2. Repository / Service 레이어

### `EventsLocalRepository` ([기존 파일 재작성](DiaCalendar2/Repositories/EventsLocalRepository.swift))
- `actor` → **`@ModelActor`** 로 전환
- 기존 `EventsLocalRepositoryProtocol` 시그니처 유지 (CalendarViewModel 변경 최소화)
- 추가 메서드: `createEvent(EventDraft)`, `deleteEvent(id:)`, `event(id:) -> EventDTO?`, `updateNotes(id:, notes:)`
- `events(in:calendar:)` 내부에서 `Event` + `WorkShift` 둘 다 fetch하여 `CalendarAggregator`로 합쳐 반환
- 더미 생성 코드 [EventsLocalRepository.swift:13-88](DiaCalendar2/Repositories/EventsLocalRepository.swift#L13-L88) 완전 제거

### `WorkShiftRepository` (`@ModelActor`, 신규)
- `shifts(in: DateInterval) -> [WorkShiftDTO]`, `upsert([WorkShiftDTO])`, `delete(supabaseIds:)`, `latestUpdatedAt() -> Date?`

### `DateMemoRepository` (`@ModelActor`, 신규)
- `memo(for date: Date, calendar: Calendar) -> DateMemoDTO?`
- `save(date:, body:)`, `delete(date:)`

### `CalendarAggregator` (struct, Sendable, 신규)
- 순수 변환기. SwiftData 의존성 없음
- `merge(events:[EventDTO], shifts:[WorkShiftDTO], in: DateInterval, calendar: Calendar) -> [Date: [YoteiEvent<EventData>]]`
- 변환 시 `EventData`에 `kind`(.event/.shift), `colorHex`, `notesPreview`, `originId`, `source` 채움
- `YoteiDaysSequence`로 각 이벤트를 일별 버킷에 분배 (기존 [EventsLocalRepository.swift:92-102](DiaCalendar2/Repositories/EventsLocalRepository.swift#L92-L102) 패턴 재사용)

### `EventKitSyncService` (actor, 신규)
- `EKEventStore` 보유, `requestFullAccessToEvents()` 사용 (iOS 17+)
- `pullFromEventKit(in: DateInterval)`: EK → 로컬 upsert (`ekEventIdentifier` 키)
  - 같은 interval에서 EK엔 없는데 로컬에 있는 항목 → tombstone
  - `EKEvent.lastModifiedDate > local.updatedAt`일 때만 업데이트
- `pushToEventKit(EventDTO)`: 로컬 변경을 EK에 반영, 신규는 생성 후 `eventIdentifier` 회수해 저장
- `observeChanges()`: `EKEventStoreChangedNotification` 구독 (0.5s 디바운스) → 자동 pull
- 충돌: **last-write-wins** (`max(local.updatedAt, ek.lastModifiedDate)`)

### `SupabaseSyncService` (actor, 신규)
- 가정 테이블: `work_shifts(id uuid pk, user_id uuid, work_date date, start_time timestamptz, end_time timestamptz, shift_code text, note text, color text, updated_at timestamptz)`, RLS `user_id = auth.uid()`
- `syncShifts(since: Date?)`: `updated_at > since` 인 row fetch → `WorkShiftRepository.upsert(byKey: supabaseId)` → `lastSupabaseShiftSyncAt` 갱신
- `signIn/signOut/currentUser`: SDK 위임, Keychain 세션
- 현 단계 read-only. push는 stub.

### `AppEnvironment` (`@Observable`, 신규)
- 위 서비스/리포지토리 인스턴스를 보유하는 루트 컨테이너. App 진입점에서 만들고 `.environment(...)`로 트리에 주입.

---

## 3. EventData 확장

[Domain/EventData.swift](DiaCalendar2/Domain/EventData.swift) — 현재 빈 구조체를 다음으로 교체:

```
struct EventData: Equatable, Sendable {
    enum Kind: String, Sendable { case event, shift }
    var kind: Kind
    var originId: UUID            // Event.id 또는 WorkShift.id
    var colorHex: String?
    var notesPreview: String?
    var source: EventSource
    var shiftCode: String?        // shift일 때만 사용
}
```

캘린더 셀에서 종류별 배지/색상 분기에 활용 (실제 렌더링 분기는 M2 이후).

---

## 4. CalendarViewModel 변경

[TabViews/Calendar/CalendarViewModel.swift](DiaCalendar2/TabViews/Calendar/CalendarViewModel.swift):

- `final class FullCalendarViewModelModel: ObservableObject` → `@Observable final class CalendarViewModel` (오타 정리, `@Published` 제거)
- 의존성 주입: `EventsLocalRepository`, `DateMemoRepository`, `EventKitSyncService`, `SupabaseSyncService`
- 신규 상태: `var presentedSheet: CalendarSheet?`
  - `enum CalendarSheet { case dayDetail(Date), eventDetail(UUID), eventEditor(EventDraft), memoEditor(Date), allDay(Date), timezone }`
- YoteiDelegate 콜백 라우팅:
  - `calendarDidSelectMonthDay(date)` → `.dayDetail(date)`
  - `calendarDidSelectEvent(id)` → `.eventDetail(uuid)`
  - `calendarDidSelectAllDay(date)` → `.allDay(date)`
  - `calendarDidSelect(dateInterval, completion)` → `.eventEditor(.new(start:end:))`, 저장 시 `completion()`
  - `calendarDidUpdateEvent` → repository update + 출처가 `.eventKit`이면 `EventKitSyncService.pushToEventKit`
- `viewDidChangeFocusedDate`: 기존 fetch 흐름 유지 + 해당 interval에 대한 EK pull 트리거
- 타임존 기본값(Asia/Seoul) 초기화 [CalendarViewModel.swift:31-37](DiaCalendar2/TabViews/Calendar/CalendarViewModel.swift#L31-L37)는 유지

---

## 5. 앱 진입점 / 탭

### [DiaCalendar2App.swift](DiaCalendar2/DiaCalendar2App.swift)
```
@main struct DiaCalendar2App: App {
    @State private var env = AppEnvironment()
    var body: some Scene {
        WindowGroup { ContentView().environment(env) }
            .modelContainer(for: [Event.self, WorkShift.self, DateMemo.self, SyncState.self])
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { env.onForeground() }
            }
    }
}
```
- `AppEnvironment.onForeground()`: EK pull + Supabase shift sync 트리거

### [ContentView.swift](DiaCalendar2/ContentView.swift)
- `Notifications`/`Settings` stub `Text(...)`을 별도 View로 교체:
  - `TabViews/Settings/SettingsView.swift`: EK 권한 토글, Supabase 로그인 폼 placeholder, 타임존 선택, 기본 EK 캘린더 선택
  - `TabViews/Notifications/NotificationsView.swift`: 빈 stub

### Info.plist
- `NSCalendarsFullAccessUsageDescription` 추가 ("일정 동기화를 위해 캘린더 접근이 필요합니다")

---

## 6. EventKit 양방향 동기화 전략

- **권한**: 첫 SettingsView 진입 시 또는 사용자 토글 → `requestFullAccessToEvents()`. 거부 시 로컬 전용으로 폴백.
- **ID 매핑**: `Event.ekEventIdentifier` ↔ `EKEvent.eventIdentifier`
- **Pull 트리거**:
  1. 앱 첫 active 진입
  2. 포그라운드 복귀
  3. `EKEventStoreChangedNotification` (0.5s 디바운스)
  4. `viewDidChangeFocusedDate`에서 새 month interval 들어올 때 (interval 단위 pull)
- **Push 트리거**: 로컬 CRUD 직후. `source == .local`인 신규는 push, `.eventKit` 출처는 update만
- **충돌**: `max(local.updatedAt, ek.lastModifiedDate)` 승. 드래그 리스케줄로 양쪽 동시 변경 시 디바운스로 회피
- **삭제**: 로컬에서 삭제 → EK에서도 remove. EK에서 사라짐 감지 → 로컬 tombstone

---

## 7. Supabase 동기화 전략

- 단방향(서버 → 로컬), incremental: `updated_at > lastSupabaseShiftSyncAt`
- 트리거:
  1. 앱 active 진입
  2. SettingsView "지금 동기화" 버튼
  3. 캘린더 month 이동 시 (5분 throttle)
- 삭제 동기화는 후속 (서버에 soft-delete 컬럼 또는 `deleted_work_shifts` 테이블 가정)
- 로그인 미완료 상태에서는 sync skip

---

## 8. UX 흐름 (YoteiDelegate → 화면)

| 사용자 액션 | Yotei 콜백 | 띄울 화면 |
|---|---|---|
| 월 셀 탭 | `calendarDidSelectMonthDay` | `DayDetailSheet` (그날 이벤트/근무/메모 list + 메모 편집 버튼) |
| 이벤트 탭 | `calendarDidSelectEvent` | `EventDetailSheet` (제목/시간/노트/색상/소스, 편집 버튼 → `EventEditorSheet`) |
| 시간 그리드 드래그 | `calendarDidSelect(interval, completion)` | `EventEditorSheet(.new)` — 저장 시 `completion()` |
| 드래그 리스케줄 | `calendarDidUpdateEvent` | 즉시 저장 + 필요 시 EK push |
| All-day 헤더 탭 | `calendarDidSelectAllDay` | `AllDayListSheet` |

---

## 9. 마일스톤

- **M1: SwiftData 기반 빈 캘린더** — 모델 4종 + container + `@ModelActor` 리포지토리 + Aggregator + 더미 제거. 빈 캘린더가 4개 뷰 모두 정상 동작.
- **M2: 이벤트 CRUD UI** — `EventEditorSheet`, `EventDetailSheet`, `DayDetailSheet`, `AllDayListSheet`. YoteiDelegate 콜백 4종 모두 시트 연결. drag 리스케줄 영속화.
- **M3: 메모** — `MemoEditorSheet`, EventEditor에 notes 필드. DayDetail에 메모 미리보기.
- **M4: EventKit 양방향 동기화** — 권한, pull/push, 변경 노티 구독, SettingsView 토글.
- **M5: Supabase 근무 동기화** — SDK 연동, 로그인 stub, `WorkShift` pull, Aggregator에서 다른 색상/배지로 표시.

---

## 10. 검증

| 마일스톤 | 검증 방법 |
|---|---|
| M1 | 시뮬레이터에서 캘린더 비어 있음 확인. 4개 뷰 전환 정상. SwiftData 컨테이너 파일이 `Application Support`에 생성됨. focusedDate 변경 시 fetch 로그. |
| M2 | 시간 드래그 → 시트 → 저장 → 즉시 반영. 앱 재시작 후에도 영속. drag 리스케줄도 재시작 후 유지. |
| M3 | 같은 날짜 메모 두 번 저장 시 update (unique dayKey). 타임존 변경 후에도 메모 매핑 일관성. |
| M4 | iOS 캘린더 앱에서 추가/수정/삭제 → 앱 포그라운드 복귀 시 반영. 반대 방향도. 권한 거부 시 로컬 전용 폴백. |
| M5 | 테스트 Supabase 프로젝트에 row 삽입 → 풀 트리거 → 캘린더에 다른 색상으로 표시. `updated_at` 갱신 시 incremental sync. |

---

## 11. 수정/생성 파일

### 수정
- [DiaCalendar2App.swift](DiaCalendar2/DiaCalendar2App.swift) — modelContainer + AppEnvironment + scenePhase
- [ContentView.swift](DiaCalendar2/ContentView.swift) — Notifications/Settings 별도 View로 교체
- [Domain/EventData.swift](DiaCalendar2/Domain/EventData.swift) — kind/originId/colorHex/notesPreview/source 추가
- [Repositories/EventsLocalRepository.swift](DiaCalendar2/Repositories/EventsLocalRepository.swift) — `@ModelActor` 재작성, 더미 제거
- [Repositories/EventsLocalRepositoryProtocol.swift](DiaCalendar2/Repositories/EventsLocalRepositoryProtocol.swift) — create/delete/get/notes 메서드 추가
- [TabViews/Calendar/CalendarViewModel.swift](DiaCalendar2/TabViews/Calendar/CalendarViewModel.swift) — `@Observable`, 의존성 주입, sheet 라우팅
- [TabViews/Calendar/CalendarView.swift](DiaCalendar2/TabViews/Calendar/CalendarView.swift) — sheet bindings 추가
- `Info.plist` — `NSCalendarsFullAccessUsageDescription`

### 신규
- `Domain/EventSource.swift`
- `Domain/EventDTO.swift`, `Domain/WorkShiftDTO.swift`, `Domain/DateMemoDTO.swift`
- `Domain/EventDraft.swift`
- `Persistence/Models/Event.swift`
- `Persistence/Models/WorkShift.swift`
- `Persistence/Models/DateMemo.swift`
- `Persistence/Models/SyncState.swift`
- `Repositories/WorkShiftRepository.swift`
- `Repositories/DateMemoRepository.swift`
- `Services/CalendarAggregator.swift`
- `Services/EventKitSyncService.swift`
- `Services/SupabaseSyncService.swift`
- `Services/AppEnvironment.swift`
- `TabViews/Calendar/Sheets/EventEditorSheet.swift`
- `TabViews/Calendar/Sheets/EventDetailSheet.swift`
- `TabViews/Calendar/Sheets/DayDetailSheet.swift`
- `TabViews/Calendar/Sheets/MemoEditorSheet.swift`
- `TabViews/Calendar/Sheets/AllDayListSheet.swift`
- `TabViews/Settings/SettingsView.swift`
- `TabViews/Notifications/NotificationsView.swift`

### 외부 의존성 추가 (Xcode SPM)
- `https://github.com/supabase-community/supabase-swift` (M5에서 추가)

---

## 재사용할 기존 패턴

- [EventsLocalRepository.swift:92-102](DiaCalendar2/Repositories/EventsLocalRepository.swift#L92-L102)의 `YoteiDaysSequence` 기반 일별 버킷 분배 로직 → `CalendarAggregator`에서 그대로 차용
- [CalendarViewModel.swift:36-68](DiaCalendar2/TabViews/Calendar/CalendarViewModel.swift) `viewDidChangeFocusedDate`의 monthInterval/dateInterval 계산 + dateLoadingInterval 표시 흐름 유지
- [CalendarViewModel.swift:113-126](DiaCalendar2/TabViews/Calendar/CalendarViewModel.swift) `viewDidSelectTimezone`의 `resetCache()` + 재페치 패턴 → 타임존 변경 시 동일하게 사용
- [Helpers/TimezoneSelectorView.swift](DiaCalendar2/Helpers/TimezoneSelectorView.swift) — SettingsView에서 재사용
