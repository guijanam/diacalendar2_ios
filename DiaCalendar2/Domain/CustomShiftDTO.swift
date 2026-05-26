//
//  CustomShiftDTO.swift
//  DiaCalendar2
//

import Foundation

struct CustomShiftDTO: Sendable, Hashable, Identifiable {
    var id: UUID
    var shiftName: String
    var shiftPattern: [String]
    var createdAt: Date
}
