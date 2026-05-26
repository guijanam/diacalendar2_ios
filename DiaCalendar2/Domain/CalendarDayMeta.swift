//
//  CalendarDayMeta.swift
//  DiaCalendar2
//
//  공휴일 / 주말 색상 규칙 한 곳에서 관리.
//

import Foundation
import SwiftUI

enum WeekdayKind: Sendable {
    case sunday, saturday, weekday

    static func of(_ date: Date, calendar: Calendar) -> WeekdayKind {
        switch calendar.component(.weekday, from: date) {
        case 1: return .sunday
        case 7: return .saturday
        default: return .weekday
        }
    }
}

enum HolidayPalette {
    /// 공휴일 / 일요일 빨강
    static let red = Color(red: 0.85, green: 0.20, blue: 0.20)
    /// 토요일 파랑
    static let blue = Color(red: 0.20, green: 0.40, blue: 0.85)
}

enum HolidayColors {
    /// 날짜 숫자 색을 한 규칙으로 결정.
    /// 우선순위: out-of-month > today > focused > 공휴일/일요일 > 토요일 > 평일
    static func dayNumberColor(
        date: Date,
        isEnabled: Bool,
        isToday: Bool,
        isFocused: Bool,
        isHoliday: Bool,
        calendar: Calendar
    ) -> Color {
        if !isEnabled { return .secondary.opacity(0.5) }
        if isToday { return .white }                // tint 배경 위에 흰 글씨
        if isFocused { return .secondary }          // 라이트 tint 원 위에 회색
        if isHoliday { return HolidayPalette.red }

        switch WeekdayKind.of(date, calendar: calendar) {
        case .sunday: return HolidayPalette.red
        case .saturday: return HolidayPalette.blue
        case .weekday: return .primary
        }
    }
}
