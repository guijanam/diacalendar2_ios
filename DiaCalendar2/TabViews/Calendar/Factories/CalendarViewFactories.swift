//
//  CalendarViewFactories.swift
//  DiaCalendar2
//
//  Yotei의 기본 이벤트 뷰들이 항상 `.tint`(시스템 파란색)을 사용해서
//  이벤트가 한 가지 색으로만 보이는 문제를 해결하기 위한 팩토리들.
//  EventData.colorHex가 있으면 해당 색을 .tint로 적용하고,
//  나머지 default view 동작은 그대로 유지.
//

import SwiftUI
import Yotei

// MARK: - DayEvents

struct DiaDayEventsViewFactory: YoteiDayEventsViewFactoryProtocol {
    typealias Data = EventData

    func eventView(event: YoteiEvent<EventData>) -> some View {
        DiaDayEventsEventView(event: event)
    }
}

// MARK: - AllDay (top strip)

struct DiaAllDayEventsTopViewFactory: YoteiAllDayEventsTopViewFactoryProtocol {
    typealias Data = EventData

    func eventView(event: YoteiEvent<EventData>) -> some View {
        DiaAllDayEventView(event: event)
    }
}

// MARK: - Schedule (list)

struct DiaScheduleViewFactory: YoteiScheduleViewFactoryProtocol {
    typealias Data = EventData

    func eventCellView(date: Date, event: YoteiEvent<EventData>) -> some View {
        DiaScheduleEventCellView(cellDate: date, event: event)
    }

    func allDayEventCellView(date: Date, event: YoteiEvent<EventData>) -> some View {
        DiaScheduleAllDayEventCellView(cellDate: date, event: event)
    }
}

// MARK: - Shift lookup environment

// 월간 셀이 viewModel의 shiftsByDate 변경을 즉시 반영하도록 Environment 경유로 dict을 흘려준다.
// Yotei 페이지가 캐시되어도 EnvironmentValues 변경이 셀의 자동 invalidate를 트리거.
private struct ShiftsByDateKey: EnvironmentKey {
    static let defaultValue: [Date: ShiftCellData] = [:]
}

extension EnvironmentValues {
    var shiftsByDate: [Date: ShiftCellData] {
        get { self[ShiftsByDateKey.self] }
        set { self[ShiftsByDateKey.self] = newValue }
    }
}

// MARK: - Month grid

struct DiaMonthViewFactory: YoteiPagesMonthViewFactoryProtocol {
    typealias Data = EventData

    var holidayLookup: (Date) -> String? = { _ in nil }
    /// date -> shiftsByDate dict 키(UTC 자정 Date) 변환 closure. 셀은 Environment의 dict에서 직접 조회.
    var shiftKey: (Date) -> Date? = { _ in nil }
    var calendar: Calendar = .current

    func dayCellView(
        date: Date,
        todayDate: Date,
        focusedDate: Date?,
        isEnabled: Bool
    ) -> some View {
        DiaMonthDayCellView(
            date: date,
            todayDate: todayDate,
            focusedDate: focusedDate,
            isEnabled: isEnabled,
            holidayName: holidayLookup(date),
            shiftKey: shiftKey(date),
            calendar: calendar
        )
        .padding(.top, -4)
    }

    func eventView(event: YoteiEvent<EventData>) -> some View {
        DiaMonthEventView(event: event)
    }
}

// MARK: - Weekday header (week view)

struct DiaWeekdayViewFactory: YoteiWeekdayViewFactoryProtocol {
    var holidayLookup: (Date) -> Bool = { _ in false }
    var calendar: Calendar = .current

    func dayCellView(date: Date, todayDate: Date) -> some View {
        DiaWeekdayDayCellView(
            date: date,
            todayDate: todayDate,
            isHoliday: holidayLookup(date),
            calendar: calendar
        )
    }
}
