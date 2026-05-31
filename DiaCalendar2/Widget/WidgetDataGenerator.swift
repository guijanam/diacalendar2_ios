//
//  WidgetDataGenerator.swift
//  DiaCalendar2
//
//  메인 앱이 SwiftData에서 근무 데이터를 읽어 가공한 뒤 App Group 컨테이너의
//  widget_data.json 으로 저장하고 위젯 타임라인을 새로고침한다.
//  (위젯은 SwiftData를 직접 열지 않고 이 JSON 스냅샷만 읽는다 — 구버전 DiaCalendar 패턴 포팅)
//
//  근무명/색은 CalendarAggregator.shiftsByDay(우선순위 적용됨)를 재사용하고,
//  근무시간(workTime)은 office의 dia 목록에서 요일 조합으로 매칭해 채운다.
//

import Foundation
import WidgetKit

enum WidgetDataGenerator {

    /// KST 자정 기준 calendar (앱 전역에서 쓰는 것과 동일).
    private static var calendar: Calendar { ShiftRotationEngine.calendar }

    /// AppEnvironment의 repository들로 위젯 데이터를 생성/저장한다.
    /// 데이터 변경/포그라운드 시 메인 앱에서 호출.
    static func generateAndSave(using env: AppEnvironment) async {
        let cal = calendar
        let today = cal.startOfDay(for: Date())

        // 이번 달 전체 + 다음 달 첫 7일을 모두 포함하는 조회 구간.
        guard let monthInterval = cal.dateInterval(of: .month, for: today),
              let nextMonthStart = cal.date(byAdding: .month, value: 1, to: monthInterval.start),
              let fetchEnd = cal.date(byAdding: .day, value: 7, to: nextMonthStart) else {
            return
        }
        let fetchInterval = DateInterval(start: monthInterval.start, end: fetchEnd)

        // 1. 근무 관련 데이터 병렬 로드 (CalendarViewModel.fetchEvents 와 동일한 소스).
        async let schedulesTask = env.shiftScheduleRepository.schedules(in: fetchInterval)
        async let swapsTask = env.shiftSwapRecordRepository.swaps(in: fetchInterval)
        async let inputsTask = env.shiftInputRecordRepository.records(in: fetchInterval)
        async let attendancesTask = env.attendanceRecordRepository.records(in: fetchInterval)
        async let holidayTask = env.holidayRepository.map()
        async let configTask = env.userShiftConfigRepository.load()

        let schedules = await schedulesTask
        let swaps = await swapsTask
        let inputs = await inputsTask
        let attendances = await attendancesTask
        let holidayMap = await holidayTask
        let config = await configTask

        // 2. CalendarAggregator로 일자별 effective 근무(label+color)를 구한다.
        //    (이벤트/메모/음력 등 위젯에 불필요한 것은 비우고 근무 관련만 넘긴다.)
        let aggregator = CalendarAggregator()
        let merged = aggregator.merge(
            events: [],
            shifts: schedules,
            swaps: swaps,
            inputs: inputs,
            attendances: attendances,
            memos: [],
            lunarAnniversaries: [],
            in: fetchInterval,
            calendar: cal
        )

        // shiftsByDay 키는 UTC 자정. KST 자정으로 다시 매핑해 lookup dict 구성.
        var utcCal = Calendar(identifier: cal.identifier)
        utcCal.timeZone = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0)!
        func kstDay(fromUTC utcDay: Date) -> Date? {
            let comps = utcCal.dateComponents([.year, .month, .day], from: utcDay)
            return cal.date(from: comps)
        }
        var shiftByKSTDay: [Date: String] = [:]
        for (utcDay, cell) in merged.shiftsByDay {
            if let day = kstDay(fromUTC: utcDay) {
                shiftByKSTDay[day] = cell.label
            }
        }

        // 3. workTime 조회용: office의 dia 목록을 한 번만 로드해 diaId -> 후보 그룹으로 묶는다.
        var diasByTurn: [String: [DiaRecordDTO]] = [:]
        if let config, !config.isCustomShift {
            let allDias = await env.diaRecordRepository.dias(forOffice: config.officeName)
            diasByTurn = Dictionary(grouping: allDias, by: { $0.diaId })
        }

        // 4. 달력 일자 배열 생성: 이번 달(앞 빈칸 포함) + 다음 달 첫 7일.
        let holidayDayKeys = Set(holidayMap.keys.map { cal.startOfDay(for: $0) })
        func workTime(forTurn turn: String, on date: Date) -> String {
            guard !turn.isEmpty, let candidates = diasByTurn[turn] else { return "" }
            return pickBestDia(candidates, for: date, holidayDayKeys: holidayDayKeys)?.workTime ?? ""
        }
        func dayString(_ date: Date) -> SimpleCalendarDay {
            let turn = shiftByKSTDay[date] ?? ""
            return SimpleCalendarDay(date: date, dia: turn, workTime: workTime(forTurn: turn, on: date))
        }

        var calendarDays: [SimpleCalendarDay] = []

        // MonthView 앞 빈칸 (이번 달 1일의 요일만큼).
        let firstWeekday = cal.component(.weekday, from: monthInterval.start)
        for _ in 1..<firstWeekday {
            calendarDays.append(SimpleCalendarDay(date: .distantPast, dia: "", workTime: ""))
        }
        // 이번 달 전체.
        let daysInMonth = cal.range(of: .day, in: .month, for: monthInterval.start)?.count ?? 0
        for offset in 0..<daysInMonth {
            guard let d = cal.date(byAdding: .day, value: offset, to: monthInterval.start) else { continue }
            calendarDays.append(dayString(cal.startOfDay(for: d)))
        }
        // 다음 달 첫 7일 (WeekView가 월말~다음달 초를 이어 보여줄 때 필요).
        for offset in 0..<7 {
            guard let d = cal.date(byAdding: .day, value: offset, to: nextMonthStart) else { continue }
            calendarDays.append(dayString(cal.startOfDay(for: d)))
        }

        // 5. 오늘/내일 요약.
        let todayTurn = shiftByKSTDay[today] ?? ""
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today) ?? today
        let tomorrowTurn = shiftByKSTDay[tomorrow] ?? ""

        let widgetData = WidgetData(
            date: today,
            calendarDays: calendarDays,
            holidayInfo: holidayMap.reduce(into: [Date: String]()) { $0[cal.startOfDay(for: $1.key)] = $1.value },
            todayDia: todayTurn.isEmpty ? "근무없음" : todayTurn,
            todayWorkTime: workTime(forTurn: todayTurn, on: today),
            tomorrowDia: tomorrowTurn.isEmpty ? "근무없음" : tomorrowTurn,
            tomorrowWorkTime: workTime(forTurn: tomorrowTurn, on: tomorrow)
        )

        // 6. JSON 저장 + 위젯 새로고침.
        guard let url = WidgetSharedStore.fileURL else { return }
        do {
            let encoded = try JSONEncoder().encode(widgetData)
            try encoded.write(to: url, options: .atomic)
            WidgetCenter.shared.reloadTimelines(ofKind: "DiaCalendar2Widget")
        } catch {
            // 저장 실패는 무시(다음 호출에서 재시도).
        }
    }

    /// 같은 diaId 후보 중 오늘+다음날 요일 조합에 맞는 row 선택.
    /// CalendarViewModel.pickBestDia 와 동일 규칙(요일/공휴일 → 테이블명 매칭).
    private static func pickBestDia(
        _ candidates: [DiaRecordDTO],
        for date: Date,
        holidayDayKeys: Set<Date>
    ) -> DiaRecordDTO? {
        guard !candidates.isEmpty else { return nil }
        if candidates.count == 1 { return candidates.first }

        func dayType(_ d: Date) -> String {
            if holidayDayKeys.contains(calendar.startOfDay(for: d)) { return "휴" }
            switch calendar.component(.weekday, from: d) {
            case 1:  return "휴"
            case 7:  return "토"
            default: return "평"
            }
        }

        let today = dayType(date)
        let nextDate = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        let next = dayType(nextDate)

        let firstName: String
        switch today {
        case "토": firstName = "토"
        case "휴": firstName = "휴일"
        default:   firstName = "평일"
        }

        let pair = today + next
        let validPairs: Set<String> = ["평평", "평토", "평휴", "휴토", "휴휴", "휴평", "토휴"]
        let nextName = validPairs.contains(pair) ? pair : "평평"

        return candidates.first { dia in
            let t = (dia.typeName ?? "").trimmingCharacters(in: .whitespaces)
            return t == firstName || t == nextName
        } ?? candidates.first
    }
}
