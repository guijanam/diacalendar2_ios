//
//  ShiftInputRecord.swift
//  DiaCalendar2
//

import Foundation
import SwiftData

/// One concrete "충당" entry for a specific date.
@Model
final class ShiftInputRecord {
    @Attribute(.unique) var date: Date
    var shiftInputTypeId: UUID
    var shortName: String
    var colorHex: String
    var targetShiftName: String      // 교체할 교번
    var originalShiftName: String    // 원래 교번
    var groupId: UUID
    var createdAt: Date

    init(
        date: Date,
        shiftInputTypeId: UUID,
        shortName: String,
        colorHex: String,
        targetShiftName: String,
        originalShiftName: String,
        groupId: UUID = UUID(),
        createdAt: Date = Date()
    ) {
        self.date = date
        self.shiftInputTypeId = shiftInputTypeId
        self.shortName = shortName
        self.colorHex = colorHex
        self.targetShiftName = targetShiftName
        self.originalShiftName = originalShiftName
        self.groupId = groupId
        self.createdAt = createdAt
    }

    func toDTO() -> ShiftInputRecordDTO {
        ShiftInputRecordDTO(
            date: date,
            shiftInputTypeId: shiftInputTypeId,
            shortName: shortName,
            colorHex: colorHex,
            targetShiftName: targetShiftName,
            originalShiftName: originalShiftName,
            groupId: groupId,
            createdAt: createdAt
        )
    }
}
