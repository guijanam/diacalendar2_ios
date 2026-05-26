//
//  WorkShiftDTO.swift
//  DiaCalendar2
//

import Foundation

struct WorkShiftDTO: Sendable, Identifiable, Equatable {
    let id: UUID
    var supabaseId: UUID
    var date: Date
    var startTime: Date
    var endTime: Date
    var shiftCode: String
    var colorHex: String?
    var note: String?
    var updatedAt: Date
}
