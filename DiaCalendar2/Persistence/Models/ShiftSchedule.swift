//
//  ShiftSchedule.swift
//  DiaCalendar2
//

import Foundation
import SwiftData

/// One row per day: the generated rotating shift assignment.
/// `date` is stored at start-of-day in `Asia/Seoul`.
@Model
final class ShiftSchedule {
    @Attribute(.unique) var date: Date
    var shiftName: String

    init(date: Date, shiftName: String) {
        self.date = date
        self.shiftName = shiftName
    }

    func toDTO() -> ShiftScheduleDTO {
        ShiftScheduleDTO(date: date, shiftName: shiftName)
    }
}
