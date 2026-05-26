//
//  ShiftScheduleRepository.swift
//  DiaCalendar2
//

import Foundation
import SwiftData

@ModelActor
actor ShiftScheduleRepository {
    /// All schedules whose `date` falls within `interval`.
    func schedules(in interval: DateInterval) -> [ShiftScheduleDTO] {
        let start = interval.start
        let end = interval.end
        let predicate = #Predicate<ShiftSchedule> { s in
            s.date >= start && s.date < end
        }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.date, order: .forward)]
        return ((try? modelContext.fetch(descriptor)) ?? []).map { $0.toDTO() }
    }

    /// Single schedule for `date` (interpreted at start-of-day).
    func schedule(on date: Date) -> ShiftScheduleDTO? {
        let day = ShiftRotationEngine.startOfDay(date)
        let predicate = #Predicate<ShiftSchedule> { $0.date == day }
        return (try? modelContext.fetch(FetchDescriptor(predicate: predicate)).first)?.toDTO()
    }

    func count() -> Int {
        (try? modelContext.fetchCount(FetchDescriptor<ShiftSchedule>())) ?? 0
    }

    /// Delete every schedule on/after `date`. Past records are preserved.
    func deleteFrom(date: Date) {
        let from = ShiftRotationEngine.startOfDay(date)
        let predicate = #Predicate<ShiftSchedule> { $0.date >= from }
        if let matches = try? modelContext.fetch(FetchDescriptor<ShiftSchedule>(predicate: predicate)) {
            for s in matches { modelContext.delete(s) }
            try? modelContext.save()
        }
    }

    func deleteAll() {
        if let all = try? modelContext.fetch(FetchDescriptor<ShiftSchedule>()) {
            for s in all { modelContext.delete(s) }
            try? modelContext.save()
        }
    }

    /// Bulk upsert (unique on `date`).
    func upsert(_ items: [ShiftScheduleDTO]) {
        for dto in items {
            let date = dto.date
            let predicate = #Predicate<ShiftSchedule> { $0.date == date }
            if let existing = try? modelContext.fetch(FetchDescriptor(predicate: predicate)).first {
                existing.shiftName = dto.shiftName
            } else {
                modelContext.insert(ShiftSchedule(date: dto.date, shiftName: dto.shiftName))
            }
        }
        try? modelContext.save()
    }

    /// Run rotation and persist results. Past entries (date < startDate) are kept.
    @discardableResult
    func generateAndSave(
        pattern: [String],
        startDate: Date,
        referenceDate: Date,
        todayShift: String,
        todayShiftIndex: Int? = nil,
        years: Int = 3
    ) throws -> Int {
        deleteFrom(date: startDate)
        let rows = try ShiftRotationEngine.rotate(
            pattern: pattern,
            startDate: startDate,
            referenceDate: referenceDate,
            todayShift: todayShift,
            todayShiftIndex: todayShiftIndex,
            years: years
        )
        for chunk in ShiftRotationEngine.chunk(rows, size: 1000) {
            upsert(chunk)
        }
        return rows.count
    }
}
