//
//  ShiftSwapRecordDTO.swift
//  DiaCalendar2
//

import Foundation

struct ShiftSwapRecordDTO: Sendable, Hashable, Identifiable {
    var date: Date
    var originalShiftName: String
    var swappedShiftName: String
    var groupId: UUID
    var createdAt: Date

    var id: Date { date }
}
