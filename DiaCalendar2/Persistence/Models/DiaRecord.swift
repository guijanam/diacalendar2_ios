//
//  DiaRecord.swift
//  DiaCalendar2
//

import Foundation
import SwiftData

/// Local copy of a Supabase `dia` row — work-detail content for a (office, dia_id, type_name) tuple.
@Model
final class DiaRecord {
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

    init(
        officeName: String,
        officeCode: Int64,
        diaId: String,
        typeName: String? = nil,
        firstTime: String? = nil,
        numTr1: String? = nil,
        numTr2: String? = nil,
        secondTime: String? = nil,
        thirdTime: String? = nil,
        totalTime: String? = nil,
        workTime: String? = nil,
        updatedAt: Date = Date()
    ) {
        self.officeName = officeName
        self.officeCode = officeCode
        self.diaId = diaId
        self.typeName = typeName
        self.firstTime = firstTime
        self.numTr1 = numTr1
        self.numTr2 = numTr2
        self.secondTime = secondTime
        self.thirdTime = thirdTime
        self.totalTime = totalTime
        self.workTime = workTime
        self.updatedAt = updatedAt
    }

    func toDTO() -> DiaRecordDTO {
        DiaRecordDTO(
            officeName: officeName,
            officeCode: officeCode,
            diaId: diaId,
            typeName: typeName,
            firstTime: firstTime,
            numTr1: numTr1,
            numTr2: numTr2,
            secondTime: secondTime,
            thirdTime: thirdTime,
            totalTime: totalTime,
            workTime: workTime,
            updatedAt: updatedAt
        )
    }
}
