//
//  ShiftInputTypeRepository.swift
//  DiaCalendar2
//

import Foundation
import SwiftData

@ModelActor
actor ShiftInputTypeRepository {
    /// Seed defaults if the table is empty. Idempotent.
    func seedDefaultsIfNeeded() {
        let count = (try? modelContext.fetchCount(FetchDescriptor<ShiftInputType>())) ?? 0
        guard count == 0 else { return }
        for entry in ShiftInputDefaults.entries {
            modelContext.insert(ShiftInputType(
                name: entry.name,
                shortName: entry.shortName,
                colorHex: entry.colorHex,
                requiresLateWork: entry.requiresLateWork
            ))
        }
        try? modelContext.save()
    }

    func all() -> [ShiftInputTypeDTO] {
        var d = FetchDescriptor<ShiftInputType>()
        d.sortBy = [SortDescriptor(\.createdAt, order: .forward)]
        return ((try? modelContext.fetch(d)) ?? []).map { $0.toDTO() }
    }

    func type(id: UUID) -> ShiftInputTypeDTO? {
        let predicate = #Predicate<ShiftInputType> { $0.id == id }
        return (try? modelContext.fetch(FetchDescriptor(predicate: predicate)).first)?.toDTO()
    }
}
