//
//  ShiftSwapRecord.swift
//  DiaCalendar2
//

import Foundation
import SwiftData

/// One-off swap that replaces the base ShiftSchedule on a specific date.
@Model
final class ShiftSwapRecord {
    @Attribute(.unique) var date: Date
    var originalShiftName: String
    var swappedShiftName: String
    var groupId: UUID
    var createdAt: Date

    init(
        date: Date,
        originalShiftName: String,
        swappedShiftName: String,
        groupId: UUID = UUID(),
        createdAt: Date = Date()
    ) {
        self.date = date
        self.originalShiftName = originalShiftName
        self.swappedShiftName = swappedShiftName
        self.groupId = groupId
        self.createdAt = createdAt
    }

    func toDTO() -> ShiftSwapRecordDTO {
        ShiftSwapRecordDTO(
            date: date,
            originalShiftName: originalShiftName,
            swappedShiftName: swappedShiftName,
            groupId: groupId,
            createdAt: createdAt
        )
    }
}
