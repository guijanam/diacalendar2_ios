//
//  CustomShiftRepository.swift
//  DiaCalendar2
//

import Foundation
import SwiftData

@ModelActor
actor CustomShiftRepository {
    func all() -> [CustomShiftDTO] {
        var d = FetchDescriptor<CustomShift>()
        d.sortBy = [SortDescriptor(\.createdAt, order: .forward)]
        return ((try? modelContext.fetch(d)) ?? []).map { $0.toDTO() }
    }

    func shift(id: UUID) -> CustomShiftDTO? {
        let predicate = #Predicate<CustomShift> { $0.id == id }
        return (try? modelContext.fetch(FetchDescriptor(predicate: predicate)).first)?.toDTO()
    }

    /// Returns the new (or existing) id.
    @discardableResult
    func upsert(id: UUID? = nil, shiftName: String, shiftPattern: [String]) -> UUID {
        let csv = listToCsv(shiftPattern)
        if let id, let existing = try? modelContext.fetch(FetchDescriptor(predicate: #Predicate<CustomShift> { $0.id == id })).first {
            existing.shiftName = shiftName
            existing.shiftPatternCsv = csv
            try? modelContext.save()
            return existing.id
        } else {
            let new = CustomShift(id: id ?? UUID(), shiftName: shiftName, shiftPatternCsv: csv)
            modelContext.insert(new)
            try? modelContext.save()
            return new.id
        }
    }

    func delete(id: UUID) {
        let predicate = #Predicate<CustomShift> { $0.id == id }
        if let existing = try? modelContext.fetch(FetchDescriptor(predicate: predicate)).first {
            modelContext.delete(existing)
            try? modelContext.save()
        }
    }

    /// 복원용: 모든 커스텀 근무 삭제.
    func deleteAll() {
        if let existing = try? modelContext.fetch(FetchDescriptor<CustomShift>()) {
            for r in existing { modelContext.delete(r) }
            try? modelContext.save()
        }
    }
}
