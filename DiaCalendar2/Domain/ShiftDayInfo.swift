//
//  ShiftDayInfo.swift
//  DiaCalendar2
//

import Foundation

/// Aggregated shift info for a single day. Used by DayDetailSheet to render the work card.
struct ShiftDayInfo: Sendable {
    /// 휴가(근태) 표시 색상. HolidayPalette.red 와 동일.
    static let attendanceColorHex: String = "#D9322F"

    var date: Date
    var config: UserShiftConfigDTO?
    var schedule: ShiftScheduleDTO?
    var swap: ShiftSwapRecordDTO?
    var input: ShiftInputRecordDTO?
    var attendance: AttendanceRecordDTO?
    var dia: DiaRecordDTO?

    /// The base shift name from the rotating schedule.
    var baseShiftName: String { schedule?.shiftName ?? "" }

    /// 지근 근태 위에 충당이 올라온 경우(지근충당으로 근무 확정) 충당이 지근을 덮는다.
    /// 그 외 근태는 근태가 충당보다 우선.
    private var inputOverridesAttendance: Bool {
        attendance?.category == .jigeun && input != nil
    }

    /// The final shift name to display, after applying overlays.
    /// Priority: attendance > input > swap > base — 단, 지근 위 충당은 충당 우선.
    var effectiveShiftName: String {
        if let attendance, !inputOverridesAttendance { return attendance.shortName }
        if let input { return "\(input.targetShiftName)" }
        if let swap { return swap.swappedShiftName }
        return baseShiftName
    }

    /// Color hex for the effective shift display.
    var effectiveColorHex: String? {
        if let attendance, !inputOverridesAttendance { return attendance.category.colorHex }
        if let input { return input.colorHex }
        if let swap { return ShiftColor.colorHex(for: swap.swappedShiftName, isSwap: true) }
        return ShiftColor.colorHex(for: baseShiftName, isSwap: false)
    }
}
