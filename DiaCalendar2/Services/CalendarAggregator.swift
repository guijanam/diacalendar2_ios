//
//  CalendarAggregator.swift
//  DiaCalendar2
//

import Foundation
import Yotei

// 월간 그리드 셀의 근무 pill에 필요한 최소 정보.
struct ShiftCellData: Equatable, Sendable {
    let label: String
    let colorHex: String?
}

// Aggregator 결과: 전체 이벤트 bucket + 월간 셀 pill용 근무 dict.
struct CalendarMergeResult: Sendable {
    var events: [Date: [YoteiEvent<EventData>]]
    var shiftsByDay: [Date: ShiftCellData]
}

struct CalendarAggregator: Sendable {
    func merge(
        events: [EventDTO],
        shifts: [ShiftScheduleDTO],
        swaps: [ShiftSwapRecordDTO] = [],
        inputs: [ShiftInputRecordDTO] = [],
        attendances: [AttendanceRecordDTO] = [],
        memos: [DateMemoDTO] = [],
        in interval: DateInterval,
        calendar: Calendar,
        ekCalendarColors: [String: String] = [:]
    ) -> CalendarMergeResult {
        var bucket = [Date: [YoteiEvent<EventData>]]()
        var shiftsByDay = [Date: ShiftCellData]()

        for date in YoteiDaysSequence(interval: interval, calendar: calendar) {
            bucket[date] = []
        }

        // 종일 이벤트는 Yotei가 UTC 자정 기준으로 날짜를 해석하므로,
        // 사용자 timezone의 (year, month, day)를 UTC 자정으로 다시 매핑해 하루 밀림을 방지한다.
        var utcCalendar = Calendar(identifier: calendar.identifier)
        utcCalendar.timeZone = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0)!

        for event in events {
            let resolvedColorHex = event.ekCalendarIdentifier.flatMap { ekCalendarColors[$0] }

            let mappedStart: Date
            let mappedEnd: Date
            if event.isAllDay {
                // EventKit이 외부 캘린더(Google 등)에서 종일 이벤트의 startDate/endDate를
                // 사용자 로컬 timezone(KST) 자정으로 반환하면, Yotei가 UTC로 해석하면서 전날로 밀린다.
                // memo/shift와 동일하게 day component만 추출해 utcCalendar 자정으로 재매핑한다.
                let startComponents = calendar.dateComponents([.year, .month, .day], from: event.start)
                // endDate가 다음 날 자정(exclusive end)이면 -1일 한 day가 inclusive 종료일.
                // 그렇지 않으면(예: 23:59:59) endDate의 day가 inclusive 종료일.
                let endRaw = event.end
                let endIsMidnight = calendar.startOfDay(for: endRaw) == endRaw
                let inclusiveEndDate = endIsMidnight
                    ? (calendar.date(byAdding: .day, value: -1, to: endRaw) ?? endRaw)
                    : endRaw
                let endComponents = calendar.dateComponents([.year, .month, .day], from: inclusiveEndDate)
                guard let utcStart = utcCalendar.date(from: startComponents),
                      let utcEndDay = utcCalendar.date(from: endComponents),
                      let utcEndExclusive = utcCalendar.date(byAdding: .day, value: 1, to: utcEndDay) else {
                    continue
                }
                mappedStart = utcStart
                mappedEnd = utcEndExclusive
            } else {
                mappedStart = event.start
                mappedEnd = event.end
            }

            let yoteiEvent = YoteiEvent(
                id: event.id,
                title: event.title,
                start: mappedStart,
                end: mappedEnd,
                isAllDay: event.isAllDay,
                data: EventData(
                    kind: .event,
                    originId: event.ekEventIdentifier,
                    colorHex: resolvedColorHex,
                    notesPreview: notesPreview(from: event.notes),
                    shiftCode: nil,
                    ekCalendarIdentifier: event.ekCalendarIdentifier
                )
            )
            distribute(event: yoteiEvent, into: &bucket, calendar: calendar)
        }

        // Index overlays by user-timezone day component for cheap lookup.
        func dayKey(_ date: Date) -> Date? {
            let components = calendar.dateComponents([.year, .month, .day], from: date)
            return utcCalendar.date(from: components)
        }
        let swapByDay: [Date: ShiftSwapRecordDTO] = swaps.reduce(into: [:]) { acc, s in
            if let key = dayKey(s.date) { acc[key] = s }
        }
        let inputByDay: [Date: ShiftInputRecordDTO] = inputs.reduce(into: [:]) { acc, i in
            if let key = dayKey(i.date) { acc[key] = i }
        }
        let attendanceByDay: [Date: AttendanceRecordDTO] = attendances.reduce(into: [:]) { acc, a in
            if let key = dayKey(a.date) { acc[key] = a }
        }

        // Convert each base ShiftSchedule into an all-day YoteiEvent.
        // 종일 이벤트는 Yotei가 UTC 자정 기준으로 날짜를 해석하므로,
        // 사용자 timezone의 날짜 컴포넌트를 UTC 자정으로 다시 매핑해 하루 밀림을 방지한다.
        // Priority (high→low): Attendance → ShiftInput → ShiftSwap → base ShiftSchedule.
        // 단, 지근(jigeun) 근태 위에 충당이 올라오면(지근충당) 충당이 지근을 덮는다.
        // 휴가가 등록된 날은 ShiftSchedule이 없어도 표시되도록 처리한다.
        var processedDays = Set<Date>()
        for shift in shifts {
            guard let utcDay = dayKey(shift.date),
                  let utcEnd = utcCalendar.date(byAdding: .day, value: 1, to: utcDay) else { continue }
            processedDays.insert(utcDay)
            let baseName = shift.shiftName

            let attendance = attendanceByDay[utcDay]
            let input = inputByDay[utcDay]
            // 지근 위에 충당이 있으면 충당이 우선(지근충당으로 근무 확정). 그 외 근태는 근태 우선.
            let inputOverridesAttendance = attendance?.category == .jigeun && input != nil

            let effective: (label: String, colorHex: String?)
            if let attendance, !inputOverridesAttendance {
                effective = (attendance.shortName, attendance.category.colorHex)
            } else if let input {
                effective = ("\(input.targetShiftName)", input.colorHex)
            } else if let swap = swapByDay[utcDay] {
                effective = (swap.swappedShiftName, ShiftColor.colorHex(for: swap.swappedShiftName, isSwap: true))
            } else {
                effective = (baseName, ShiftColor.colorHex(for: baseName, isSwap: false))
            }

            let yoteiEvent = YoteiEvent(
                id: "shift-\(utcDay.timeIntervalSince1970)",
                title: effective.label,
                start: utcDay,
                end: utcEnd,
                isAllDay: true,
                data: EventData(
                    kind: .shift,
                    originId: ISO8601DateFormatter.dayString(from: shift.date),
                    colorHex: effective.colorHex,
                    notesPreview: nil,
                    shiftCode: effective.label,
                    ekCalendarIdentifier: nil
                )
            )
            distribute(event: yoteiEvent, into: &bucket, calendar: calendar)
            shiftsByDay[utcDay] = ShiftCellData(label: effective.label, colorHex: effective.colorHex)
        }

        // ShiftSchedule이 없는 날에 휴가만 있을 수도 있으므로 (CustomShift 미설정 또는 startDate 이전 등),
        // attendance-only 일자도 별도로 종일 이벤트를 만들어 표시한다.
        for (utcDay, attendance) in attendanceByDay where !processedDays.contains(utcDay) {
            guard let utcEnd = utcCalendar.date(byAdding: .day, value: 1, to: utcDay) else { continue }
            let yoteiEvent = YoteiEvent(
                id: "shift-\(utcDay.timeIntervalSince1970)",
                title: attendance.shortName,
                start: utcDay,
                end: utcEnd,
                isAllDay: true,
                data: EventData(
                    kind: .shift,
                    originId: ISO8601DateFormatter.dayString(from: attendance.date),
                    colorHex: attendance.category.colorHex,
                    notesPreview: nil,
                    shiftCode: attendance.shortName,
                    ekCalendarIdentifier: nil
                )
            )
            distribute(event: yoteiEvent, into: &bucket, calendar: calendar)
            shiftsByDay[utcDay] = ShiftCellData(label: attendance.shortName, colorHex: attendance.category.colorHex)
        }

        for memo in memos {
            // 종일 이벤트는 Yotei가 UTC 자정 기준으로 날짜를 해석하므로,
            // 사용자 timezone의 날짜 컴포넌트를 UTC 자정으로 다시 매핑한다.
            if let recurrence = memo.recurrence {
                // 반복 메모: occurrence 날짜들을 전개해 각각 YoteiEvent로 배포
                let occurrences = memoOccurrenceDates(
                    recurrence: recurrence,
                    startDate: memo.startDate,
                    in: interval,
                    calendar: calendar
                )
                for occurrenceDate in occurrences {
                    let dateString = ISO8601DateFormatter.dayString(from: occurrenceDate)
                    let startComponents = calendar.dateComponents([.year, .month, .day], from: occurrenceDate)
                    guard let utcStart = utcCalendar.date(from: startComponents),
                          let utcEndExclusive = utcCalendar.date(byAdding: .day, value: 1, to: utcStart) else {
                        continue
                    }
                    let yoteiEvent = YoteiEvent(
                        id: "memo-\(memo.id.uuidString)-\(dateString)",
                        title: memo.title.isEmpty ? "메모" : memo.title,
                        start: utcStart,
                        end: utcEndExclusive,
                        isAllDay: true,
                        data: EventData(
                            kind: .memo,
                            originId: memo.id.uuidString,
                            colorHex: memo.colorHex,
                            notesPreview: notesPreview(from: memo.body),
                            shiftCode: nil,
                            ekCalendarIdentifier: nil,
                            isDone: memo.isDone
                        )
                    )
                    distribute(event: yoteiEvent, into: &bucket, calendar: calendar)
                }
            } else {
                // 일반 메모: startDate~endDate span 그대로 배포
                let startComponents = calendar.dateComponents([.year, .month, .day], from: memo.startDate)
                let endComponents = calendar.dateComponents([.year, .month, .day], from: memo.endDate)
                guard let utcStart = utcCalendar.date(from: startComponents),
                      let utcEndDay = utcCalendar.date(from: endComponents),
                      let utcEndExclusive = utcCalendar.date(byAdding: .day, value: 1, to: utcEndDay) else {
                    continue
                }
                let yoteiEvent = YoteiEvent(
                    id: "memo-\(memo.id.uuidString)",
                    title: memo.title.isEmpty ? "메모" : memo.title,
                    start: utcStart,
                    end: utcEndExclusive,
                    isAllDay: true,
                    data: EventData(
                        kind: .memo,
                        originId: memo.id.uuidString,
                        colorHex: memo.colorHex,
                        notesPreview: notesPreview(from: memo.body),
                        shiftCode: nil,
                        ekCalendarIdentifier: nil,
                        isDone: memo.isDone
                    )
                )
                distribute(event: yoteiEvent, into: &bucket, calendar: calendar)
            }
        }

        return CalendarMergeResult(events: bucket, shiftsByDay: shiftsByDay)
    }

    private func distribute(
        event: YoteiEvent<EventData>,
        into bucket: inout [Date: [YoteiEvent<EventData>]],
        calendar: Calendar
    ) {
        let interval = event.displayableDateInterval()
        for date in YoteiDaysSequence(interval: interval, calendar: calendar) {
            bucket[date, default: []].append(event)
        }
    }

    private func memoOccurrenceDates(
        recurrence: EventRecurrence,
        startDate: Date,
        in interval: DateInterval,
        calendar: Calendar
    ) -> [Date] {
        var dates: [Date] = []
        var current = calendar.startOfDay(for: startDate)
        var count = 0

        let component: Calendar.Component
        switch recurrence.frequency {
        case .daily:   component = .day
        case .weekly:  component = .weekOfYear
        case .monthly: component = .month
        case .yearly:  component = .year
        }

        while current <= interval.end {
            count += 1

            switch recurrence.end {
            case .afterCount(let max) where count > max:
                return dates
            case .onDate(let endDate) where current > calendar.startOfDay(for: endDate):
                return dates
            default:
                break
            }

            if current >= interval.start {
                dates.append(current)
            }

            guard let next = calendar.date(byAdding: component, value: recurrence.interval, to: current) else { break }
            current = next
        }
        return dates
    }

    private func notesPreview(from notes: String?) -> String? {
        guard let notes, !notes.isEmpty else { return nil }
        return notes.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: true)
            .first
            .map(String.init)
    }
}
