//
//  OfficeRecord.swift
//  DiaCalendar2
//

import Foundation
import SwiftData

/// Local copy of a Supabase `office` row.
/// Pattern lists are stored as CSV strings (matches Android `OfficeEntity`).
@Model
final class OfficeRecord {
    @Attribute(.unique) var officeCode: Int64
    var officeName: String
    var diaTurns1Csv: String
    var diaTurns2Csv: String
    var diaTurns3Csv: String
    var subTurnsCsv: String
    var diaSelectsCsv: String
    var updatedAt: Date

    init(
        officeCode: Int64,
        officeName: String,
        diaTurns1Csv: String = "",
        diaTurns2Csv: String = "",
        diaTurns3Csv: String = "",
        subTurnsCsv: String = "",
        diaSelectsCsv: String = "",
        updatedAt: Date = Date()
    ) {
        self.officeCode = officeCode
        self.officeName = officeName
        self.diaTurns1Csv = diaTurns1Csv
        self.diaTurns2Csv = diaTurns2Csv
        self.diaTurns3Csv = diaTurns3Csv
        self.subTurnsCsv = subTurnsCsv
        self.diaSelectsCsv = diaSelectsCsv
        self.updatedAt = updatedAt
    }

    func toDTO() -> OfficeRecordDTO {
        OfficeRecordDTO(
            officeCode: officeCode,
            officeName: officeName,
            diaTurns1: csvToList(diaTurns1Csv),
            diaTurns2: csvToList(diaTurns2Csv),
            diaTurns3: csvToList(diaTurns3Csv),
            subTurns: csvToList(subTurnsCsv),
            diaSelects: csvToList(diaSelectsCsv),
            updatedAt: updatedAt
        )
    }
}

nonisolated func csvToList(_ csv: String) -> [String] {
    csv.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
}

nonisolated func listToCsv(_ list: [String]) -> String {
    list.joined(separator: ",")
}
