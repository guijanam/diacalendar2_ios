//
//  WorkShift.swift
//  DiaCalendar2
//

import Foundation
import SwiftData

@Model
final class WorkShift {
    @Attribute(.unique) var id: UUID
    var supabaseId: UUID
    var date: Date
    var startTime: Date
    var endTime: Date
    var shiftCode: String
    var colorHex: String?
    var note: String?
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        supabaseId: UUID,
        date: Date,
        startTime: Date,
        endTime: Date,
        shiftCode: String,
        colorHex: String? = nil,
        note: String? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.supabaseId = supabaseId
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.shiftCode = shiftCode
        self.colorHex = colorHex
        self.note = note
        self.updatedAt = updatedAt
    }

    func toDTO() -> WorkShiftDTO {
        WorkShiftDTO(
            id: id,
            supabaseId: supabaseId,
            date: date,
            startTime: startTime,
            endTime: endTime,
            shiftCode: shiftCode,
            colorHex: colorHex,
            note: note,
            updatedAt: updatedAt
        )
    }
}
