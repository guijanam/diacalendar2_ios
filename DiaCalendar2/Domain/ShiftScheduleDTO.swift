//
//  ShiftScheduleDTO.swift
//  DiaCalendar2
//

import Foundation

struct ShiftScheduleDTO: Sendable, Hashable, Identifiable {
    var date: Date
    var shiftName: String

    var id: Date { date }
}
