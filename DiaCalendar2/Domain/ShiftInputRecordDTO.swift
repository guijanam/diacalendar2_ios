//
//  ShiftInputRecordDTO.swift
//  DiaCalendar2
//

import Foundation

struct ShiftInputRecordDTO: Sendable, Hashable, Identifiable {
    var date: Date
    var shiftInputTypeId: UUID
    var shortName: String
    var colorHex: String
    var targetShiftName: String
    var originalShiftName: String
    var groupId: UUID
    var createdAt: Date

    var id: Date { date }
}
