//
//  DiaRecordDTO.swift
//  DiaCalendar2
//

import Foundation

struct DiaRecordDTO: Sendable, Hashable {
    var officeName: String
    var officeCode: Int64
    var diaId: String
    var typeName: String?
    var firstTime: String?
    var numTr1: String?
    var numTr2: String?
    var secondTime: String?
    var thirdTime: String?
    var totalTime: String?
    var workTime: String?
    var updatedAt: Date
}
