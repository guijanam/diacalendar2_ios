//
//  LunarAnniversaryRepository.swift
//  DiaCalendar2
//

import Foundation
import SwiftData

@ModelActor
actor LunarAnniversaryRepository {

    func all() -> [LunarAnniversaryDTO] {
        var d = FetchDescriptor<LunarAnniversary>()
        d.sortBy = [SortDescriptor(\.createdAt, order: .forward)]
        return ((try? modelContext.fetch(d)) ?? []).map { $0.toDTO() }
    }

    @discardableResult
    func upsert(_ dto: LunarAnniversaryDTO) -> LunarAnniversaryDTO? {
        let id = dto.id
        if let existing = try? modelContext.fetch(
            FetchDescriptor(predicate: #Predicate<LunarAnniversary> { $0.id == id })
        ).first {
            existing.title = dto.title
            existing.lunarMonth = dto.lunarMonth
            existing.lunarDay = dto.lunarDay
            existing.isLeapMonth = dto.isLeapMonth
            existing.colorHex = dto.colorHex
            try? modelContext.save()
            return existing.toDTO()
        }
        let new = LunarAnniversary(
            id: dto.id,
            title: dto.title,
            lunarMonth: dto.lunarMonth,
            lunarDay: dto.lunarDay,
            isLeapMonth: dto.isLeapMonth,
            colorHex: dto.colorHex,
            createdAt: dto.createdAt
        )
        modelContext.insert(new)
        try? modelContext.save()
        return new.toDTO()
    }

    func delete(id: UUID) {
        let predicate = #Predicate<LunarAnniversary> { $0.id == id }
        if let existing = try? modelContext.fetch(FetchDescriptor(predicate: predicate)).first {
            modelContext.delete(existing)
            try? modelContext.save()
        }
    }

    /// 복원용: 모든 기념일 삭제.
    func deleteAll() {
        if let existing = try? modelContext.fetch(FetchDescriptor<LunarAnniversary>()) {
            for r in existing { modelContext.delete(r) }
            try? modelContext.save()
        }
    }
}
