//
//  WorkShiftRepository.swift
//  DiaCalendar2
//

import Foundation
import SwiftData

@ModelActor
actor WorkShiftRepository {
    func shifts(in interval: DateInterval) -> [WorkShiftDTO] {
        let start = interval.start
        let end = interval.end
        let predicate = #Predicate<WorkShift> { shift in
            shift.startTime < end && shift.endTime > start
        }
        let descriptor = FetchDescriptor(predicate: predicate)
        return ((try? modelContext.fetch(descriptor)) ?? []).map { $0.toDTO() }
    }

    func upsert(_ dtos: [WorkShiftDTO]) {
        for dto in dtos {
            let supabaseId = dto.supabaseId
            let predicate = #Predicate<WorkShift> { $0.supabaseId == supabaseId }
            if let existing = try? modelContext.fetch(FetchDescriptor(predicate: predicate)).first {
                existing.date = dto.date
                existing.startTime = dto.startTime
                existing.endTime = dto.endTime
                existing.shiftCode = dto.shiftCode
                existing.colorHex = dto.colorHex
                existing.note = dto.note
                existing.updatedAt = dto.updatedAt
            } else {
                modelContext.insert(WorkShift(
                    id: dto.id,
                    supabaseId: dto.supabaseId,
                    date: dto.date,
                    startTime: dto.startTime,
                    endTime: dto.endTime,
                    shiftCode: dto.shiftCode,
                    colorHex: dto.colorHex,
                    note: dto.note,
                    updatedAt: dto.updatedAt
                ))
            }
        }
        try? modelContext.save()
    }

    func delete(supabaseIds: [UUID]) {
        for supabaseId in supabaseIds {
            let predicate = #Predicate<WorkShift> { $0.supabaseId == supabaseId }
            if let shift = try? modelContext.fetch(FetchDescriptor(predicate: predicate)).first {
                modelContext.delete(shift)
            }
        }
        try? modelContext.save()
    }

    func latestUpdatedAt() -> Date? {
        var descriptor = FetchDescriptor<WorkShift>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return (try? modelContext.fetch(descriptor))?.first?.updatedAt
    }
}
