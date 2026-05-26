//
//  DiaRecordRepository.swift
//  DiaCalendar2
//

import Foundation
import SwiftData

@ModelActor
actor DiaRecordRepository {
    /// Replace every dia row for `officeName` with `items`.
    func replaceAll(forOffice officeName: String, with items: [DiaRecordDTO]) {
        let predicate = #Predicate<DiaRecord> { $0.officeName == officeName }
        if let existing = try? modelContext.fetch(FetchDescriptor(predicate: predicate)) {
            for r in existing { modelContext.delete(r) }
        }
        let now = Date()
        for dto in items {
            modelContext.insert(DiaRecord(
                officeName: dto.officeName,
                officeCode: dto.officeCode,
                diaId: dto.diaId,
                typeName: dto.typeName,
                firstTime: dto.firstTime,
                numTr1: dto.numTr1,
                numTr2: dto.numTr2,
                secondTime: dto.secondTime,
                thirdTime: dto.thirdTime,
                totalTime: dto.totalTime,
                workTime: dto.workTime,
                updatedAt: now
            ))
        }
        try? modelContext.save()
    }

    /// All dia rows for the given office name.
    func dias(forOffice officeName: String) -> [DiaRecordDTO] {
        let predicate = #Predicate<DiaRecord> { $0.officeName == officeName }
        return ((try? modelContext.fetch(FetchDescriptor(predicate: predicate))) ?? []).map { $0.toDTO() }
    }

    /// Best matching dia for a (office, shift code) tuple — caller can further filter by typeName.
    func dia(officeName: String, diaId: String) -> [DiaRecordDTO] {
        let predicate = #Predicate<DiaRecord> { r in
            r.officeName == officeName && r.diaId == diaId
        }
        return ((try? modelContext.fetch(FetchDescriptor(predicate: predicate))) ?? []).map { $0.toDTO() }
    }
}
