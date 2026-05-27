//
//  CalendarViewModel.swift
//  DiaCalendar2
//
//  Created by Bum Son on 5/9/26.
//

import Combine
import Foundation
import Yotei

enum MemoEditorMode: Equatable {
    case new(date: Date)
    case edit(DateMemoDTO)
}

enum CalendarSheet: Identifiable, Equatable {
    case dayDetail(Date)
    case eventDetail(String) // EK identifier
    case eventEditor(EventDraft)
    case allDay(Date)
    case memoEditor(MemoEditorMode)
    case shiftSwap(Date)
    case shiftInput(Date)
    case attendance(Date)

    var id: String {
        switch self {
        case .dayDetail(let date): return "day-\(date.timeIntervalSince1970)"
        case .eventDetail(let id): return "eventDetail-\(id)"
        case .eventEditor(let draft):
            return "eventEditor-\(draft.ekEventIdentifier ?? "new")-\(draft.start.timeIntervalSince1970)"
        case .allDay(let date): return "allDay-\(date.timeIntervalSince1970)"
        case .memoEditor(let mode):
            switch mode {
            case .new(let date): return "memo-new-\(date.timeIntervalSince1970)"
            case .edit(let dto): return "memo-edit-\(dto.id.uuidString)"
            }
        case .shiftSwap(let date): return "shiftSwap-\(date.timeIntervalSince1970)"
        case .shiftInput(let date): return "shiftInput-\(date.timeIntervalSince1970)"
        case .attendance(let date): return "attendance-\(date.timeIntervalSince1970)"
        }
    }
}

@MainActor
final class FullCalendarViewModelModel: ObservableObject {
    private enum Constants {
        static var monthIntervalMinDay: Int { -45 }
        static var monthIntervalMaxDay: Int { 75 }
    }

    private let eventKitService: EventKitSyncService
    private let localNotificationService: LocalNotificationService?
    private let workShiftRepository: WorkShiftRepository?
    private let shiftScheduleRepository: ShiftScheduleRepository?
    private let shiftSwapRecordRepository: ShiftSwapRecordRepository?
    private let shiftInputRecordRepository: ShiftInputRecordRepository?
    private let shiftInputTypeRepository: ShiftInputTypeRepository?
    private let attendanceRecordRepository: AttendanceRecordRepository?
    private let attendanceTypeRepository: AttendanceTypeRepository?
    private let userShiftConfigRepository: UserShiftConfigRepository?
    private let officeRecordRepository: OfficeRecordRepository?
    private let diaRecordRepository: DiaRecordRepository?
    private let holidayRepository: HolidayRepository?
    private let dateMemoRepository: DateMemoRepository?
    private let syncStateRepository: SyncStateRepository?
    private let lunarAnniversaryRepository: LunarAnniversaryRepository?
    private let aggregator = CalendarAggregator()

    private var monthInterval: DateInterval?

    @Published var focusedDate = Date()
    @Published var data = YoteiEventsInterval<EventData>()
    // 월간 그리드 전용 사본 (shift 이벤트 제거). Yotei가 외부 필터를 지원하지 않아 별도 보관.
    @Published var monthData = YoteiEventsInterval<EventData>()
    // 월간 셀 pill 조회용. utcCalendar 자정 키 (Aggregator와 동일 규칙).
    @Published var shiftsByDate: [Date: ShiftCellData] = [:]
    /// 현재 focused 월의 총 휴무 갯수.
    /// = (effective 근무명이 "휴"인 날 수) + (지휴 날 수) − (지근 날 수).
    @Published var monthRestCount: Int = 0
    /// 현재 focused 월의 휴무충당 갯수. 휴 갯수와 별개로 상단에 보라색으로 표시.
    @Published var monthHyumuChungdangCount: Int = 0
    @Published var viewType: CalendarViewType = .month
    @Published var isTimezoneSelectorActive = false
    @Published var activeWebURL: URL? = nil
    @Published var pendingPasswordOfficeName: String? = nil
    @Published var calendar = Calendar.current
    @Published var viewID = UUID()
    @Published var presentedSheet: CalendarSheet?
    @Published var holidaysByDate: [Date: String] = [:]

    private let utcDayCalendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0)!
        return cal
    }()

    init(
        eventKitService: EventKitSyncService,
        localNotificationService: LocalNotificationService? = nil,
        workShiftRepository: WorkShiftRepository? = nil,
        shiftScheduleRepository: ShiftScheduleRepository? = nil,
        shiftSwapRecordRepository: ShiftSwapRecordRepository? = nil,
        shiftInputRecordRepository: ShiftInputRecordRepository? = nil,
        shiftInputTypeRepository: ShiftInputTypeRepository? = nil,
        attendanceRecordRepository: AttendanceRecordRepository? = nil,
        attendanceTypeRepository: AttendanceTypeRepository? = nil,
        userShiftConfigRepository: UserShiftConfigRepository? = nil,
        officeRecordRepository: OfficeRecordRepository? = nil,
        diaRecordRepository: DiaRecordRepository? = nil,
        holidayRepository: HolidayRepository? = nil,
        dateMemoRepository: DateMemoRepository? = nil,
        syncStateRepository: SyncStateRepository? = nil,
        lunarAnniversaryRepository: LunarAnniversaryRepository? = nil
    ) {
        self.eventKitService = eventKitService
        self.localNotificationService = localNotificationService
        self.workShiftRepository = workShiftRepository
        self.shiftScheduleRepository = shiftScheduleRepository
        self.shiftSwapRecordRepository = shiftSwapRecordRepository
        self.shiftInputRecordRepository = shiftInputRecordRepository
        self.shiftInputTypeRepository = shiftInputTypeRepository
        self.attendanceRecordRepository = attendanceRecordRepository
        self.attendanceTypeRepository = attendanceTypeRepository
        self.userShiftConfigRepository = userShiftConfigRepository
        self.officeRecordRepository = officeRecordRepository
        self.diaRecordRepository = diaRecordRepository
        self.holidayRepository = holidayRepository
        self.dateMemoRepository = dateMemoRepository
        self.syncStateRepository = syncStateRepository
        self.lunarAnniversaryRepository = lunarAnniversaryRepository
        if let seoulTimeZone = TimeZone(identifier: "Asia/Seoul") {
            calendar.timeZone = seoulTimeZone
        }
        focusedDate = calendar.startOfDay(for: Date())
        Task { await loadHolidays() }
    }

    func loadHolidays() async {
        guard let repo = holidayRepository else { return }
        let map = await repo.map()
        await MainActor.run {
            self.holidaysByDate = map
        }
    }

    /// 캘린더 셀이 자기 자신을 그릴 때 호출. date는 어떤 timezone 자정이든 dateComponents로 변환해 KST 자정 맵 키와 매칭.
    func holidayName(on date: Date) -> String? {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        guard let day = ShiftRotationEngine.calendar.date(from: comps) else { return nil }
        return holidaysByDate[day]
    }

    /// 월간 그리드 셀이 pill을 그릴 때 호출. Aggregator가 utcCalendar 자정 키로 저장하므로 동일하게 정규화.
    func shiftCellData(on date: Date) -> ShiftCellData? {
        guard let key = shiftKey(for: date) else { return nil }
        return shiftsByDate[key]
    }

    /// Aggregator의 utcCalendar 자정 키 정규화. Environment shiftsByDate dict 조회용.
    func shiftKey(for date: Date) -> Date? {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        return utcDayCalendar.date(from: comps)
    }
}

extension FullCalendarViewModelModel {
    func viewDidChangeFocusedDate() {
        let monthInterval = calendar.dateInterval(of: .month, for: focusedDate)!
        guard monthInterval != self.monthInterval else {
            return
        }

        self.monthInterval = monthInterval

        let startDate = calendar.date(
            byAdding: .day,
            value: Constants.monthIntervalMinDay,
            to: monthInterval.start
        )!
        let endDate = calendar.date(
            byAdding: .day,
            value: Constants.monthIntervalMaxDay,
            to: monthInterval.end
        )!
        let dateInterval = DateInterval(start: startDate, end: endDate)

        data.dateInterval = dateInterval
        data.monthInterval = monthInterval

        fetchEvents(in: dateInterval)
    }

    func reloadEvents() {
        guard let interval = data.dateInterval else {
            monthInterval = nil
            viewDidChangeFocusedDate()
            return
        }
        fetchEvents(in: interval)
    }

    func viewDidSelectToday() {
        focusedDate = calendar.startOfDay(for: Date())
    }

    func viewDidSelectTimezoneSelector() {
        Task {
            guard let name = await userShiftConfigRepository?.load()?.officeName,
                  let entry = OfficeWebURLMap.entry(for: name),
                  let url = URL(string: entry.url) else {
                isTimezoneSelectorActive = true
                return
            }
            if let password = entry.password, !WebPasswordStore.isAuthenticated(for: name) {
                pendingPasswordOfficeName = name
            } else {
                activeWebURL = url
            }
        }
    }

    func viewDidAuthenticateWebPassword(for officeName: String) {
        guard let entry = OfficeWebURLMap.entry(for: officeName),
              let url = URL(string: entry.url) else { return }
        activeWebURL = url
    }

    func viewDidSelectTimezone(with id: String) {
        defer {
            isTimezoneSelectorActive = false
        }
        guard calendar.timeZone.identifier != id else {
            return
        }
        calendar.timeZone = TimeZone(identifier: id)!
        monthInterval = nil
        viewDidChangeFocusedDate()
    }

    func viewDidUpdateUserSettings() {
        var newCalendar = Calendar.current
        newCalendar.timeZone = calendar.timeZone
        calendar = newCalendar
        viewID = UUID()
    }

    private func fetchEvents(in dateInterval: DateInterval) {
        let calendar = self.calendar
        let service = eventKitService
        let shiftSchedules = shiftScheduleRepository
        let shiftSwaps = shiftSwapRecordRepository
        let shiftInputs = shiftInputRecordRepository
        let shiftInputTypes = shiftInputTypeRepository
        let attendances = attendanceRecordRepository
        let memos = dateMemoRepository
        let syncState = syncStateRepository
        let userConfig = userShiftConfigRepository
        let lunarRepo = lunarAnniversaryRepository
        let officeRepo = officeRecordRepository

        Task {
            let visible = await syncState?.visibleCalendarIdentifiers() ?? []
            async let eventsTask: [EventDTO] = service.fetchEvents(
                in: dateInterval,
                visibleIdentifiers: visible
            )
            async let schedulesTask: [ShiftScheduleDTO] = shiftSchedules?.schedules(in: dateInterval) ?? []
            async let swapsTask: [ShiftSwapRecordDTO] = shiftSwaps?.swaps(in: dateInterval) ?? []
            async let inputsTask: [ShiftInputRecordDTO] = shiftInputs?.records(in: dateInterval) ?? []
            async let attendancesTask: [AttendanceRecordDTO] = attendances?.records(in: dateInterval) ?? []
            async let memosTask: [DateMemoDTO] = memos?.memos(in: dateInterval) ?? []
            async let lunarAnniversariesTask: [LunarAnniversaryDTO] = lunarRepo?.all() ?? []
            async let inputTypesTask: [ShiftInputTypeDTO] = shiftInputTypes?.all() ?? []
            async let diaTurns3Task: Set<String> = {
                guard let config = await userConfig?.load(),
                      !config.isCustomShift,
                      let office = await officeRepo?.office(code: config.officeCode) else {
                    return []
                }
                return Set(office.diaTurns3)
            }()
            let calendars = await service.readableCalendars()

            var colorMap: [String: String] = [:]
            for info in calendars {
                if let color = info.colorHex {
                    colorMap[info.identifier] = color
                }
            }

            let events = await eventsTask
            let schedules = await schedulesTask
            let swaps = await swapsTask
            let inputs = await inputsTask
            let attendanceList = await attendancesTask
            let memosResult = await memosTask
            let lunarAnniversaries = await lunarAnniversariesTask
            let diaTurns3Set = await diaTurns3Task
            let inputTypes = await inputTypesTask

            let result = aggregator.merge(
                events: events,
                shifts: schedules,
                swaps: swaps,
                inputs: inputs,
                attendances: attendanceList,
                memos: memosResult,
                lunarAnniversaries: lunarAnniversaries,
                in: dateInterval,
                calendar: calendar,
                ekCalendarColors: colorMap
            )
            data.events = result.events

            // 월간 grid용 사본: shift 이벤트만 제거 (메타 필드는 data 기준 유지).
            var monthBucket = result.events
            for (day, list) in monthBucket {
                monthBucket[day] = list.filter { $0.data.kind != .shift }
            }
            var month = data
            month.events = monthBucket
            monthData = month

            monthRestCount = Self.restCount(
                forMonthContaining: focusedDate,
                calendar: calendar,
                schedules: schedules,
                swaps: swaps,
                inputs: inputs,
                attendances: attendanceList,
                diaTurns3: diaTurns3Set,
                holidays: holidaysByDate
            )

            monthHyumuChungdangCount = Self.hyumuChungdangCount(
                forMonthContaining: focusedDate,
                calendar: calendar,
                inputs: inputs,
                inputTypes: inputTypes
            )

            if diaTurns3Set.isEmpty {
                shiftsByDate = result.shiftsByDay
            } else {
                var patched = result.shiftsByDay
                for (utcDay, cell) in result.shiftsByDay {
                    guard diaTurns3Set.contains(cell.label),
                          isHolidayOrWeekend(utcDay: utcDay) else { continue }
                    patched[utcDay] = ShiftCellData(label: cell.label, colorHex: "#D41E1E")
                }
                shiftsByDate = patched
            }
        }
    }

    /// 특정 월의 총 휴무 갯수를 계산한다.
    /// 각 날을 "휴무인가/아닌가" 로 한 번씩만 판정해 합산한다 (이중 카운트 방지).
    /// 우선순위: 근태(지근/지휴/일반) → 충당 → 교번교체 → 베이스 스케줄.
    /// - 지휴: 무조건 휴무로 카운트 (원래 근무를 휴로 바꾼 것).
    /// - 지근: 무조건 휴무 아님 (원래 휴를 근무로 바꾼 것).
    /// - 일반 근태(연차/대휴 등): 휴무 아님 — 근태 종류 이름에 "휴"가 들어가도 무관.
    /// - 휴근무: effective 근무명이 "휴" 로 시작 (예: "휴18").
    /// - 운휴: effective 근무명이 diaTurns3 에 속하고, 그 날이 주말(토/일)·공휴일인 경우 (빨간 배경).
    /// 입력 데이터는 월 범위보다 넓을 수 있으므로 focused 월로 필터링한다.
    nonisolated static func restCount(
        forMonthContaining date: Date,
        calendar: Calendar,
        schedules: [ShiftScheduleDTO],
        swaps: [ShiftSwapRecordDTO],
        inputs: [ShiftInputRecordDTO],
        attendances: [AttendanceRecordDTO],
        diaTurns3: Set<String>,
        holidays: [Date: String]
    ) -> Int {
        guard let monthInterval = calendar.dateInterval(of: .month, for: date) else { return 0 }
        // 주의: DateInterval.contains 는 end 를 포함(닫힌 구간)하므로 다음 달 1일이 새어 들어온다.
        // 반드시 명시적 반열림 비교 [start, end) 를 사용한다.
        func inMonth(_ d: Date) -> Bool { d >= monthInterval.start && d < monthInterval.end }

        // 우선순위 오버레이 룩업 (KST 자정 키).
        func dayKey(_ d: Date) -> Date { ShiftRotationEngine.startOfDay(d) }
        let swapByDay: [Date: ShiftSwapRecordDTO] = swaps.reduce(into: [:]) { $0[dayKey($1.date)] = $1 }
        let inputByDay: [Date: ShiftInputRecordDTO] = inputs.reduce(into: [:]) { $0[dayKey($1.date)] = $1 }
        let attendanceByDay: [Date: AttendanceRecordDTO] = attendances.reduce(into: [:]) { $0[dayKey($1.date)] = $1 }

        // 휴근무 판정: 근무명이 "휴" 로 시작 (예: "휴18", "휴33"). 일반 근무는 숫자, 충당은 "대13" 등.
        func isRestShift(_ name: String) -> Bool { name.hasPrefix("휴") }

        // 운휴 판정: diaTurns3 에 속한 근무가 주말(토/일)·공휴일에 오면 휴무로 취급 (빨간 배경).
        func isUnhyu(name: String, on kstDay: Date) -> Bool {
            guard diaTurns3.contains(name) else { return false }
            if holidays[kstDay] != nil { return true }
            let weekday = ShiftRotationEngine.calendar.component(.weekday, from: kstDay)
            return weekday == 1 || weekday == 7   // 일요일 / 토요일
        }

        // 스케줄 키 룩업.
        let scheduleByDay: [Date: ShiftScheduleDTO] = schedules.reduce(into: [:]) { $0[dayKey($1.date)] = $1 }

        // 판정 대상 날짜 = 스케줄 있는 날 ∪ 근태 있는 날. 각 날을 한 번씩만 휴무 여부 판정.
        var allDays = Set(scheduleByDay.keys)
        allDays.formUnion(attendanceByDay.keys)

        var restDays = 0
        for day in allDays where inMonth(day) {
            let attendance = attendanceByDay[day]
            let input = inputByDay[day]
            // 지근 위에 충당이 있으면 충당이 우선(지근충당으로 근무 확정). 그 외 근태는 근태 우선.
            let inputOverridesAttendance = attendance?.category == .jigeun && input != nil

            // 우선순위: 근태 → 충당 → 교번교체 → 베이스 스케줄.
            if let attendance, !inputOverridesAttendance {
                switch attendance.category {
                case .jihyu: restDays += 1   // 원래 근무 → 휴
                case .jigeun: break          // 원래 휴 → 근무 (휴무 아님)
                case .normal: break          // 일반 근태는 휴무 아님
                }
                continue
            }
            let effective: String
            if let input {
                effective = input.targetShiftName
            } else if let swap = swapByDay[day] {
                effective = swap.swappedShiftName
            } else if let schedule = scheduleByDay[day] {
                effective = schedule.shiftName
            } else {
                continue
            }
            // 휴근무 또는 운휴면 휴무 1일.
            if isRestShift(effective) || isUnhyu(name: effective, on: day) {
                restDays += 1
            }
        }

        return restDays
    }

    /// "휴무충당" 식별용 충당 유형 이름.
    nonisolated static let hyumuChungdangTypeName = "휴무충당"

    /// 특정 월의 휴무충당 갯수를 계산한다.
    /// 충당 유형 이름이 "휴무충당" 인 ShiftInputRecord 를 focused 월 범위에서 센다.
    nonisolated static func hyumuChungdangCount(
        forMonthContaining date: Date,
        calendar: Calendar,
        inputs: [ShiftInputRecordDTO],
        inputTypes: [ShiftInputTypeDTO]
    ) -> Int {
        guard let monthInterval = calendar.dateInterval(of: .month, for: date) else { return 0 }
        func inMonth(_ d: Date) -> Bool { d >= monthInterval.start && d < monthInterval.end }

        // 휴무충당 유형의 id 집합.
        let hyumuTypeIds = Set(
            inputTypes
                .filter { $0.name == hyumuChungdangTypeName }
                .map { $0.id }
        )
        guard !hyumuTypeIds.isEmpty else { return 0 }

        return inputs.filter {
            inMonth(ShiftRotationEngine.startOfDay($0.date)) && hyumuTypeIds.contains($0.shiftInputTypeId)
        }.count
    }
}

// MARK: - CRUD

extension FullCalendarViewModelModel {
    func saveEvent(_ draft: EventDraft, scope: EventEditScope = .thisEvent) {
        let service = eventKitService
        let syncState = syncStateRepository
        let notifService = localNotificationService
        Task {
            if let identifier = draft.ekEventIdentifier {
                await notifService?.cancelAlarms(for: identifier)
                _ = await service.update(
                    ekEventIdentifier: identifier,
                    with: draft,
                    scope: scope
                )
                await notifService?.scheduleAlarms(for: draft, ekEventIdentifier: identifier)
            } else {
                let defaultId = await syncState?.defaultEKCalendarIdentifier()
                if let newId = await service.create(draft, defaultCalendarIdentifier: defaultId) {
                    await notifService?.scheduleAlarms(for: draft, ekEventIdentifier: newId)
                }
            }
            presentedSheet = nil
            reloadEvents()
        }
    }

    func cancelDraft() {
        presentedSheet = nil
    }

    func deleteEvent(ekEventIdentifier: String, scope: EventEditScope = .thisEvent) {
        let service = eventKitService
        let notifService = localNotificationService
        Task {
            await notifService?.cancelAlarms(for: ekEventIdentifier)
            _ = await service.delete(ekEventIdentifier: ekEventIdentifier, scope: scope)
            presentedSheet = nil
            reloadEvents()
        }
    }

    func presentEditor(forEditing ekEventIdentifier: String) {
        let service = eventKitService
        Task {
            guard let dto = await service.event(with: ekEventIdentifier) else { return }
            presentedSheet = .eventEditor(.edit(from: dto))
        }
    }

    func event(with ekEventIdentifier: String) async -> EventDTO? {
        await eventKitService.event(with: ekEventIdentifier)
    }

    func eventsOnDay(_ date: Date) -> [YoteiEvent<EventData>] {
        let dayStart = calendar.startOfDay(for: date)
        return data.events[dayStart] ?? []
    }

    func allDayEventsOnDay(_ date: Date) -> [YoteiEvent<EventData>] {
        eventsOnDay(date).filter { $0.isAllDay }
    }

    func memos(on date: Date) async -> [DateMemoDTO] {
        guard let dateMemoRepository else { return [] }
        return await dateMemoRepository.memos(on: date, calendar: calendar)
    }

    // MARK: - Shift day info

    func shiftDayInfo(on date: Date) async -> ShiftDayInfo? {
        let day = ShiftRotationEngine.startOfDay(date)
        async let scheduleTask = shiftScheduleRepository?.schedule(on: day)
        async let swapTask = shiftSwapRecordRepository?.swap(on: day)
        async let inputTask = shiftInputRecordRepository?.record(on: day)
        async let attendanceTask = attendanceRecordRepository?.record(on: day)
        async let configTask = userShiftConfigRepository?.load()

        let schedule = await scheduleTask
        let swap = await swapTask
        let input = await inputTask
        let attendance = await attendanceTask
        let config = await configTask

        guard schedule != nil || swap != nil || input != nil || attendance != nil else { return nil }

        // 지근 위에 충당이 있으면(지근충당으로 근무 확정) 충당이 지근을 덮으므로
        // 그 날의 effective 근무는 근태가 아니라 충당이다. ShiftDayInfo.inputOverridesAttendance 와 동일 규칙.
        let inputOverridesAttendance = attendance?.category == .jigeun && input != nil

        // 근태가 effective 일 때(일반 근태·지휴)는 근무시간이 없으므로 dia 조회를 건너뛴다.
        // 지근충당처럼 충당이 근태를 덮는 경우는 충당의 근무명으로 dia 를 조회한다.
        var dia: DiaRecordDTO?
        let attendanceIsEffective = attendance != nil && !inputOverridesAttendance
        if !attendanceIsEffective, let config, !config.isCustomShift {
            let shiftName: String = {
                if let input { return input.targetShiftName }
                if let swap { return swap.swappedShiftName }
                return schedule?.shiftName ?? ""
            }()
            if let candidates = await diaRecordRepository?.dia(officeName: config.officeName, diaId: shiftName) {
                dia = pickBestDia(candidates, for: day)
            }
        }

        return ShiftDayInfo(
            date: day,
            config: config,
            schedule: schedule,
            swap: swap,
            input: input,
            attendance: attendance,
            dia: dia
        )
    }

    /// KST 자정 date를 "평" / "토" / "휴" 토큰으로 매핑.
    /// 공휴일은 weekday를 덮어 "휴"로 분류 (Android: Red 색 우선).
    private func dayType(for date: Date) -> String {
        if holidaysByDate[date] != nil { return "휴" }
        let weekday = ShiftRotationEngine.calendar.component(.weekday, from: date)
        switch weekday {
        case 1:  return "휴"
        case 7:  return "토"
        default: return "평"
        }
    }

    /// UTC 자정 키(shiftsByDay 키)를 KST 자정으로 변환 후 토/일/공휴일 여부 반환.
    private func isHolidayOrWeekend(utcDay: Date) -> Bool {
        let comps = utcDayCalendar.dateComponents([.year, .month, .day], from: utcDay)
        guard let kstDay = ShiftRotationEngine.calendar.date(from: comps) else { return false }
        let type = dayType(for: kstDay)
        return type == "토" || type == "휴"
    }

    /// 같은 diaId를 공유하는 후보들 중에서 오늘+다음날 요일 조합에 맞는 row를 선택.
    /// firstDiaTableName("평일"/"토"/"휴일") 또는 nextDiaTableName(두 글자 조합)과 정확히 일치해야 함.
    private func pickBestDia(_ candidates: [DiaRecordDTO], for date: Date) -> DiaRecordDTO? {
        guard !candidates.isEmpty else { return nil }
        if candidates.count == 1 { return candidates.first }

        let today = dayType(for: date)
        let nextDate = ShiftRotationEngine.calendar.date(byAdding: .day, value: 1, to: date) ?? date
        let next = dayType(for: nextDate)

        let firstDiaTableName: String
        switch today {
        case "토": firstDiaTableName = "토"
        case "휴": firstDiaTableName = "휴일"
        default:   firstDiaTableName = "평일"
        }

        let pair = today + next
        let validPairs: Set<String> = ["평평", "평토", "평휴", "휴토", "휴휴", "휴평", "토휴"]
        let nextDiaTableName = validPairs.contains(pair) ? pair : "평평"

        return candidates.first { dia in
            let t = (dia.typeName ?? "").trimmingCharacters(in: .whitespaces)
            return t == firstDiaTableName || t == nextDiaTableName
        }
    }

    /// 멀티데이 교번교체. 첫 날은 `targetShiftName`, 이후 일자는 패턴을 순차 회전.
    /// `days == 1` 이면 단일 일자 교체.
    func createSwap(on date: Date, swappedTo targetShiftName: String, days: Int) async {
        guard let swapRepo = shiftSwapRecordRepository,
              let scheduleRepo = shiftScheduleRepository,
              let configRepo = userShiftConfigRepository else { return }
        let pattern = (await configRepo.load())?.shiftPattern ?? []
        guard !pattern.isEmpty, days > 0 else { return }

        let baseDay = ShiftRotationEngine.startOfDay(date)
        // 각 날짜의 기본 ShiftSchedule.shiftName을 미리 모아 originalShift로 넘긴다.
        var originals: [Date: String] = [:]
        for offset in 0..<days {
            if let day = ShiftRotationEngine.calendar.date(byAdding: .day, value: offset, to: baseDay) {
                originals[day] = await scheduleRepo.schedule(on: day)?.shiftName ?? ""
            }
        }

        await swapRepo.createRun(
            startDate: baseDay,
            days: days,
            shiftPattern: pattern,
            targetShiftName: targetShiftName,
            originalShiftLookup: { originals[$0] ?? "" }
        )
        NotificationCenter.default.post(name: .shiftScheduleDidUpdate, object: nil)
        reloadEvents()
    }

    func createShiftInput(
        on date: Date,
        type: ShiftInputTypeDTO,
        days: Int,
        targetShiftName: String
    ) async {
        guard let inputRepo = shiftInputRecordRepository,
              let scheduleRepo = shiftScheduleRepository,
              let configRepo = userShiftConfigRepository else { return }
        let pattern = (await configRepo.load())?.shiftPattern ?? []
        guard !pattern.isEmpty else { return }

        await inputRepo.createRun(
            type: type,
            startDate: ShiftRotationEngine.startOfDay(date),
            days: days,
            shiftPattern: pattern,
            targetShiftName: targetShiftName,
            originalShiftLookup: { _ in "" }
        )
        // Backfill originals after-the-fact (single await chain to keep the actor work cheap).
        for offset in 0..<days {
            guard let day = ShiftRotationEngine.calendar.date(
                byAdding: .day, value: offset, to: ShiftRotationEngine.startOfDay(date)
            ) else { continue }
            _ = await scheduleRepo.schedule(on: day)?.shiftName
        }
        NotificationCenter.default.post(name: .shiftScheduleDidUpdate, object: nil)
        reloadEvents()
    }

    func deleteOverlay(on date: Date) async {
        let day = ShiftRotationEngine.startOfDay(date)
        await shiftSwapRecordRepository?.delete(on: day)
        await shiftInputRecordRepository?.delete(on: day)
        await attendanceRecordRepository?.delete(on: day)
        NotificationCenter.default.post(name: .shiftScheduleDidUpdate, object: nil)
        reloadEvents()
    }

    func availableShiftInputTypes() async -> [ShiftInputTypeDTO] {
        await shiftInputTypeRepository?.all() ?? []
    }

    /// 해당 날짜에 지근(category == .jigeun)이 설정되어 있는지 확인.
    /// 지근충당은 지근이 설정된 날에만 등록 가능하도록 제한하는 데 사용한다.
    func isJiGeunDay(_ date: Date) async -> Bool {
        let day = ShiftRotationEngine.startOfDay(date)
        return await attendanceRecordRepository?.record(on: day)?.category == .jigeun
    }

    func availableAttendanceTypes() async -> [AttendanceTypeDTO] {
        await attendanceTypeRepository?.all() ?? []
    }

    /// 휴가(근태) 멀티데이 등록. 회전 없이 모든 날 같은 휴가 종류로 표시.
    func createAttendance(on date: Date, type: AttendanceTypeDTO, days: Int) async {
        guard let attendanceRepo = attendanceRecordRepository,
              let scheduleRepo = shiftScheduleRepository else { return }
        guard days > 0 else { return }

        let baseDay = ShiftRotationEngine.startOfDay(date)
        // 각 일자의 베이스 ShiftSchedule.shiftName 을 미리 모아 originalShift로 저장.
        var originals: [Date: String] = [:]
        for offset in 0..<days {
            if let day = ShiftRotationEngine.calendar.date(byAdding: .day, value: offset, to: baseDay) {
                originals[day] = await scheduleRepo.schedule(on: day)?.shiftName ?? ""
            }
        }

        await attendanceRepo.createRun(
            type: type,
            startDate: baseDay,
            days: days,
            originalShiftLookup: { originals[$0] ?? "" }
        )
        NotificationCenter.default.post(name: .shiftScheduleDidUpdate, object: nil)
        reloadEvents()
    }

    /// 지근/지휴 멀티데이 등록. 근태와 같은 흐름이지만 분류(category)를 함께 저장한다.
    /// 월간 "휴" 갯수 계산 시 지휴는 가산, 지근은 차감하는 데 사용된다.
    func createJiGeunHyu(on date: Date, category: AttendanceCategory, days: Int) async {
        guard let attendanceRepo = attendanceRecordRepository,
              let scheduleRepo = shiftScheduleRepository else { return }
        guard days > 0, category != .normal else { return }

        let baseDay = ShiftRotationEngine.startOfDay(date)
        // 각 일자의 베이스 ShiftSchedule.shiftName 을 미리 모아 originalShift로 저장.
        var originals: [Date: String] = [:]
        for offset in 0..<days {
            if let day = ShiftRotationEngine.calendar.date(byAdding: .day, value: offset, to: baseDay) {
                originals[day] = await scheduleRepo.schedule(on: day)?.shiftName ?? ""
            }
        }

        await attendanceRepo.createCategoryRun(
            category: category,
            startDate: baseDay,
            days: days,
            originalShiftLookup: { originals[$0] ?? "" }
        )
        NotificationCenter.default.post(name: .shiftScheduleDidUpdate, object: nil)
        reloadEvents()
    }

    func currentShiftPattern() async -> [String] {
        (await userShiftConfigRepository?.load())?.shiftPattern ?? []
    }

    /// ShiftSetup의 "기준 근무" 드롭다운과 동일한 데이터.
    /// office.diaSelects가 있으면 그것, 없으면 사용자 설정 패턴, CustomShift도 패턴.
    func referenceShiftOptions() async -> [String] {
        guard let config = await userShiftConfigRepository?.load() else { return [] }
        if config.isCustomShift {
            return config.shiftPattern
        }
        if let office = await officeRecordRepository?.office(code: config.officeCode),
           !office.diaSelects.isEmpty {
            return office.diaSelects
        }
        return config.shiftPattern
    }

    func memo(with id: UUID) async -> DateMemoDTO? {
        guard let dateMemoRepository else { return nil }
        return await dateMemoRepository.memo(with: id)
    }

    func saveMemo(_ dto: DateMemoDTO) {
        guard let dateMemoRepository else { return }
        Task {
            _ = await dateMemoRepository.upsert(dto)
            presentedSheet = nil
            reloadEvents()
        }
    }

    func deleteMemo(id: UUID) {
        guard let dateMemoRepository else { return }
        Task {
            await dateMemoRepository.delete(id: id)
            presentedSheet = nil
            reloadEvents()
        }
    }

    /// 시트를 닫지 않고 메모만 삭제한다 (DayDetailSheet 스와이프 삭제용).
    func deleteMemoKeepingSheet(id: UUID) async {
        guard let dateMemoRepository else { return }
        await dateMemoRepository.delete(id: id)
        reloadEvents()
    }

    /// 시트를 닫지 않고 메모를 저장한다 (DayDetailSheet 완료 토글용).
    func saveMemoKeepingSheet(_ dto: DateMemoDTO) async {
        guard let dateMemoRepository else { return }
        _ = await dateMemoRepository.upsert(dto)
        reloadEvents()
    }

    func saveLunarAnniversary(_ dto: LunarAnniversaryDTO) async {
        guard let lunarAnniversaryRepository else { return }
        _ = await lunarAnniversaryRepository.upsert(dto)
        reloadEvents()
    }

    func deleteLunarAnniversary(id: UUID) async {
        guard let lunarAnniversaryRepository else { return }
        await lunarAnniversaryRepository.delete(id: id)
        reloadEvents()
    }

    func allLunarAnniversaries() async -> [LunarAnniversaryDTO] {
        await lunarAnniversaryRepository?.all() ?? []
    }

    func loadAvailableCalendars() async -> [EKCalendarInfo] {
        await eventKitService.readableCalendars()
    }

    func loadWritableCalendars() async -> [EKCalendarInfo] {
        await eventKitService.writableCalendars()
    }

    func defaultCalendarIdentifierProvider() async -> String? {
        await syncStateRepository?.defaultEKCalendarIdentifier()
    }
}

extension FullCalendarViewModelModel: YoteiDelegate<EventData> {
    func calendarDidUpdateEvent(
        with id: YoteiEvent<EventData>.ID,
        oldDateInterval _: DateInterval,
        newDateInterval: DateInterval
    ) {
        // Yotei id 형식: "<ekEventId>@<timestamp>" 또는 "shift-<uuid>"
        guard let ekEventIdentifier = parseEKIdentifier(from: id) else { return }
        let service = eventKitService
        Task {
            guard let dto = await service.event(with: ekEventIdentifier) else { return }
            var draft = EventDraft.edit(from: dto)
            draft.start = newDateInterval.start
            draft.end = newDateInterval.end
            // 반복이면 .thisEvent로(드래그 리스케줄 시 단일 발생만 이동)
            _ = await service.update(
                ekEventIdentifier: ekEventIdentifier,
                with: draft,
                scope: .thisEvent
            )
            reloadEvents()
        }
    }

    func calendarDidSelectMonthDay(date: Date) {
        presentedSheet = .dayDetail(calendar.startOfDay(for: date))
    }

    func calendarDidSelectEvent(with id: YoteiEvent<EventData>.ID) {
        guard let ekEventIdentifier = parseEKIdentifier(from: id) else { return }
        presentedSheet = .eventDetail(ekEventIdentifier)
    }

    func calendarDidSelectAllDay(date: Date) {
        presentedSheet = .allDay(calendar.startOfDay(for: date))
    }

    func calendarDidSelect(dateInterval: DateInterval, completion: () -> Void) {
        completion()
        presentedSheet = .eventEditor(.new(start: dateInterval.start, end: dateInterval.end))
    }

    private func parseEKIdentifier(from yoteiId: String) -> String? {
        if yoteiId.hasPrefix("shift-") { return nil }
        // "<ekId>@<timestamp>" 형태에서 @ 이전을 추출.
        if let atIndex = yoteiId.lastIndex(of: "@") {
            return String(yoteiId[..<atIndex])
        }
        return yoteiId
    }
}
