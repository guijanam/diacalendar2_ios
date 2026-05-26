//
//  OfficeRecordDTO.swift
//  DiaCalendar2
//

import Foundation

struct OfficeRecordDTO: Sendable, Hashable, Identifiable {
    var officeCode: Int64
    var officeName: String
    var diaTurns1: [String]
    var diaTurns2: [String]
    var diaTurns3: [String]
    var subTurns: [String]
    var diaSelects: [String]
    var updatedAt: Date

    var id: Int64 { officeCode }
}
