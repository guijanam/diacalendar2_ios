//
//  CustomShift.swift
//  DiaCalendar2
//

import Foundation
import SwiftData

/// User-defined shift cycle (e.g. "4조2교대 / 주,야,비,휴").
@Model
final class CustomShift {
    @Attribute(.unique) var id: UUID
    var shiftName: String
    var shiftPatternCsv: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        shiftName: String,
        shiftPatternCsv: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.shiftName = shiftName
        self.shiftPatternCsv = shiftPatternCsv
        self.createdAt = createdAt
    }

    func toDTO() -> CustomShiftDTO {
        CustomShiftDTO(
            id: id,
            shiftName: shiftName,
            shiftPattern: csvToList(shiftPatternCsv),
            createdAt: createdAt
        )
    }
}
