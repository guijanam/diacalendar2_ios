//
//  ShiftColor.swift
//  DiaCalendar2
//

import Foundation

/// Maps shift names to a representative hex color, mirroring Android `ShiftBadge.kt`.
enum ShiftColor {
    /// Returns a `#RRGGBB` string, or `nil` to fall back to the default theme color.
    static func colorHex(for shiftName: String, isSwap: Bool) -> String? {
        if isSwap { return "#F57C00" }                        // 교번교체 (주황)
        if shiftName == "지근" { return "#007AFF" }           // 지근 (하늘)
        if shiftName == "지휴" { return "#C62828" }           // 지휴 (빨강)
        if shiftName.contains("휴") { return "#D41E1E" }      // 휴 (빨강 계열)
        if shiftName.contains("대") { return "#278F2C" }      // 대 (초록)
        return nil                                            // 기본 — 테마 primaryContainer 사용
    }
}

extension ISO8601DateFormatter {
    /// Stable yyyy-MM-dd string used as an originId for shift days.
    static func dayString(from date: Date) -> String {
        let f = DateFormatter()
        f.calendar = ShiftRotationEngine.calendar
        f.timeZone = ShiftRotationEngine.calendar.timeZone
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}
