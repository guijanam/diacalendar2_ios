//
//  HolidayRecordDTO.swift
//  DiaCalendar2
//

import Foundation

struct HolidayRecordDTO: Sendable, Hashable, Identifiable {
    var date: Date      // KST 자정
    var name: String

    var id: Date { date }
}
