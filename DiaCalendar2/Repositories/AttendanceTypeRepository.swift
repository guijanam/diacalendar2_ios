//
//  AttendanceTypeRepository.swift
//  DiaCalendar2
//

import Foundation
import SwiftData

@ModelActor
actor AttendanceTypeRepository {
    /// 첫 실행에만 시드 (이미 있으면 no-op).
    func seedDefaultsIfNeeded() {
        let count = (try? modelContext.fetchCount(FetchDescriptor<AttendanceType>())) ?? 0
        guard count == 0 else { return }
        for entry in AttendanceDefaults.entries {
            modelContext.insert(AttendanceType(name: entry.name, shortName: entry.shortName))
        }
        try? modelContext.save()
    }

    func all() -> [AttendanceTypeDTO] {
        var d = FetchDescriptor<AttendanceType>()
        d.sortBy = [SortDescriptor(\.createdAt, order: .forward)]
        return ((try? modelContext.fetch(d)) ?? []).map { $0.toDTO() }
    }

    func type(id: UUID) -> AttendanceTypeDTO? {
        let predicate = #Predicate<AttendanceType> { $0.id == id }
        return (try? modelContext.fetch(FetchDescriptor(predicate: predicate)).first)?.toDTO()
    }

    /// 신규 생성 또는 기존 편집. 반환값은 식별자.
    @discardableResult
    func upsert(
        id: UUID? = nil,
        name: String,
        shortName: String,
        limitCount: Int? = nil,
        resetMonth: Int? = 1,
        resetDay: Int? = 1,
        resetYear: Int? = nil,
        resetCycleYears: Int = 1
    ) -> UUID {
        if let id, let existing = try? modelContext.fetch(FetchDescriptor(predicate: #Predicate<AttendanceType> { $0.id == id })).first {
            existing.name = name
            existing.shortName = shortName
            existing.limitCount = limitCount
            existing.resetMonth = resetMonth
            existing.resetDay = resetDay
            existing.resetYear = resetYear
            existing.resetCycleYears = resetCycleYears
            try? modelContext.save()
            return existing.id
        }
        let new = AttendanceType(
            id: id ?? UUID(),
            name: name,
            shortName: shortName,
            limitCount: limitCount,
            resetMonth: resetMonth,
            resetDay: resetDay,
            resetYear: resetYear,
            resetCycleYears: resetCycleYears
        )
        modelContext.insert(new)
        try? modelContext.save()
        return new.id
    }

    func delete(id: UUID) {
        let predicate = #Predicate<AttendanceType> { $0.id == id }
        if let existing = try? modelContext.fetch(FetchDescriptor(predicate: predicate)).first {
            modelContext.delete(existing)
            try? modelContext.save()
        }
    }
}
