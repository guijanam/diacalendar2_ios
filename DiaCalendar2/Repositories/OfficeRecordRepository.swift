//
//  OfficeRecordRepository.swift
//  DiaCalendar2
//

import Foundation
import SwiftData

@ModelActor
actor OfficeRecordRepository {
    func all() -> [OfficeRecordDTO] {
        var d = FetchDescriptor<OfficeRecord>()
        d.sortBy = [SortDescriptor(\.officeName, order: .forward)]
        return ((try? modelContext.fetch(d)) ?? []).map { $0.toDTO() }
    }

    func office(code: Int64) -> OfficeRecordDTO? {
        let predicate = #Predicate<OfficeRecord> { $0.officeCode == code }
        return (try? modelContext.fetch(FetchDescriptor(predicate: predicate)).first)?.toDTO()
    }

    func office(name: String) -> OfficeRecordDTO? {
        let predicate = #Predicate<OfficeRecord> { $0.officeName == name }
        return (try? modelContext.fetch(FetchDescriptor(predicate: predicate)).first)?.toDTO()
    }

    func upsert(_ items: [OfficeRecordDTO]) {
        let now = Date()
        for dto in items {
            let code = dto.officeCode
            let predicate = #Predicate<OfficeRecord> { $0.officeCode == code }
            if let existing = try? modelContext.fetch(FetchDescriptor(predicate: predicate)).first {
                existing.officeName = dto.officeName
                existing.diaTurns1Csv = listToCsv(dto.diaTurns1)
                existing.diaTurns2Csv = listToCsv(dto.diaTurns2)
                existing.diaTurns3Csv = listToCsv(dto.diaTurns3)
                existing.subTurnsCsv = listToCsv(dto.subTurns)
                existing.diaSelectsCsv = listToCsv(dto.diaSelects)
                existing.updatedAt = now
            } else {
                modelContext.insert(OfficeRecord(
                    officeCode: dto.officeCode,
                    officeName: dto.officeName,
                    diaTurns1Csv: listToCsv(dto.diaTurns1),
                    diaTurns2Csv: listToCsv(dto.diaTurns2),
                    diaTurns3Csv: listToCsv(dto.diaTurns3),
                    subTurnsCsv: listToCsv(dto.subTurns),
                    diaSelectsCsv: listToCsv(dto.diaSelects),
                    updatedAt: now
                ))
            }
        }
        try? modelContext.save()
    }
}
