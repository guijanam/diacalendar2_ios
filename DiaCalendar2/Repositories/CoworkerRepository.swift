//
//  CoworkerRepository.swift
//  DiaCalendar2
//

import Foundation
import SwiftData

@ModelActor
actor CoworkerRepository {

    // MARK: - Coworker

    func allCoworkers() -> [CoworkerDTO] {
        var d = FetchDescriptor<Coworker>()
        d.sortBy = [SortDescriptor(\.sortOrder, order: .forward),
                    SortDescriptor(\.createdAt, order: .forward)]
        return ((try? modelContext.fetch(d)) ?? []).map { $0.toDTO() }
    }

    func coworker(id: UUID) -> CoworkerDTO? {
        let predicate = #Predicate<Coworker> { $0.id == id }
        return (try? modelContext.fetch(FetchDescriptor(predicate: predicate)).first)?.toDTO()
    }

    /// Insert or update. Returns the (new or existing) id.
    @discardableResult
    func upsertCoworker(_ dto: CoworkerDTO) -> UUID {
        let id = dto.id
        if let existing = try? modelContext.fetch(FetchDescriptor(predicate: #Predicate<Coworker> { $0.id == id })).first {
            existing.name = dto.name
            existing.sortOrder = dto.sortOrder
            existing.groupIdsCsv = uuidListToCsv(dto.groupIds)
            existing.shiftPatternCsv = listToCsv(dto.shiftPattern)
            existing.referenceDate = dto.referenceDate
            existing.referenceShift = dto.referenceShift
            existing.referenceShiftIndex = dto.referenceShiftIndex
            try? modelContext.save()
            return existing.id
        } else {
            let new = Coworker(
                id: dto.id,
                name: dto.name,
                sortOrder: dto.sortOrder,
                groupIdsCsv: uuidListToCsv(dto.groupIds),
                shiftPatternCsv: listToCsv(dto.shiftPattern),
                referenceDate: dto.referenceDate,
                referenceShift: dto.referenceShift,
                referenceShiftIndex: dto.referenceShiftIndex,
                createdAt: dto.createdAt
            )
            modelContext.insert(new)
            try? modelContext.save()
            return new.id
        }
    }

    func deleteCoworker(id: UUID) {
        let predicate = #Predicate<Coworker> { $0.id == id }
        if let existing = try? modelContext.fetch(FetchDescriptor(predicate: predicate)).first {
            modelContext.delete(existing)
            try? modelContext.save()
        }
    }

    /// Persist a new ordering (sortOrder follows the array index).
    func updateCoworkerSortOrders(orderedIds: [UUID]) {
        let all = (try? modelContext.fetch(FetchDescriptor<Coworker>())) ?? []
        let byId = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
        for (index, id) in orderedIds.enumerated() {
            byId[id]?.sortOrder = index
        }
        try? modelContext.save()
    }

    // MARK: - Group

    func allGroups() -> [CoworkerGroupDTO] {
        var d = FetchDescriptor<CoworkerGroup>()
        d.sortBy = [SortDescriptor(\.sortOrder, order: .forward),
                    SortDescriptor(\.createdAt, order: .forward)]
        return ((try? modelContext.fetch(d)) ?? []).map { $0.toDTO() }
    }

    @discardableResult
    func upsertGroup(id: UUID? = nil, name: String) -> UUID {
        if let id, let existing = try? modelContext.fetch(FetchDescriptor(predicate: #Predicate<CoworkerGroup> { $0.id == id })).first {
            existing.name = name
            try? modelContext.save()
            return existing.id
        } else {
            let maxOrder = ((try? modelContext.fetch(FetchDescriptor<CoworkerGroup>())) ?? [])
                .map { $0.sortOrder }.max() ?? -1
            let new = CoworkerGroup(id: id ?? UUID(), name: name, sortOrder: maxOrder + 1)
            modelContext.insert(new)
            try? modelContext.save()
            return new.id
        }
    }

    /// Delete a group and strip its id from every coworker's `groupIds`.
    func deleteGroup(id: UUID) {
        let groupPredicate = #Predicate<CoworkerGroup> { $0.id == id }
        if let group = try? modelContext.fetch(FetchDescriptor(predicate: groupPredicate)).first {
            modelContext.delete(group)
        }
        let all = (try? modelContext.fetch(FetchDescriptor<Coworker>())) ?? []
        for coworker in all {
            let ids = csvToUUIDList(coworker.groupIdsCsv)
            if ids.contains(id) {
                coworker.groupIdsCsv = uuidListToCsv(ids.filter { $0 != id })
            }
        }
        try? modelContext.save()
    }

    // MARK: - Schedule calculation (runtime only, not persisted)

    /// Returns a `date -> shiftName` map for the given month, mirroring Android
    /// `CoworkerRepositoryImpl.calculateScheduleForMonth`.
    nonisolated static func scheduleForMonth(
        _ coworker: CoworkerDTO,
        year: Int,
        month: Int
    ) -> [Date: String] {
        let pattern = coworker.shiftPattern
        guard !pattern.isEmpty else { return [:] }

        let cal = ShiftRotationEngine.calendar
        guard let firstDay = cal.date(from: DateComponents(year: year, month: month, day: 1)) else { return [:] }
        let firstOfMonth = cal.startOfDay(for: firstDay)
        let range = cal.range(of: .day, in: .month, for: firstOfMonth) ?? 1..<2
        let daysInMonth = range.count

        // Same index math as `ShiftRotationEngine.rotate`, restricted to this month's span.
        var result: [Date: String] = [:]
        let refDay = cal.startOfDay(for: coworker.referenceDate)
        let size = pattern.count
        let refIndex: Int
        if let idx = coworker.referenceShiftIndex, idx >= 0, idx < size {
            refIndex = idx
        } else if let found = pattern.firstIndex(of: coworker.referenceShift) {
            refIndex = found
        } else {
            return [:]
        }

        for dayOffset in 0..<daysInMonth {
            guard let date = cal.date(byAdding: .day, value: dayOffset, to: firstOfMonth) else { continue }
            let daysFromRef = cal.dateComponents([.day], from: refDay, to: date).day ?? 0
            let raw = (refIndex + daysFromRef) % size
            let idx = (raw + size) % size
            result[date] = pattern[idx]
        }
        return result
    }
}
