//
//  ShiftInputRecordRepository.swift
//  DiaCalendar2
//

import Foundation
import SwiftData

@ModelActor
actor ShiftInputRecordRepository {
    func records(in interval: DateInterval) -> [ShiftInputRecordDTO] {
        let start = interval.start
        let end = interval.end
        let predicate = #Predicate<ShiftInputRecord> { r in
            r.date >= start && r.date < end
        }
        return ((try? modelContext.fetch(FetchDescriptor(predicate: predicate))) ?? []).map { $0.toDTO() }
    }

    func record(on date: Date) -> ShiftInputRecordDTO? {
        let day = ShiftRotationEngine.startOfDay(date)
        let predicate = #Predicate<ShiftInputRecord> { $0.date == day }
        return (try? modelContext.fetch(FetchDescriptor(predicate: predicate)).first)?.toDTO()
    }

    /// 백업용: 전체 조회.
    func all() -> [ShiftInputRecordDTO] {
        ((try? modelContext.fetch(FetchDescriptor<ShiftInputRecord>())) ?? []).map { $0.toDTO() }
    }

    /// 복원용: 기존 데이터를 모두 지우고 DTO의 모든 스냅샷 필드를 그대로 insert.
    func restoreAll(_ dtos: [ShiftInputRecordDTO]) {
        if let existing = try? modelContext.fetch(FetchDescriptor<ShiftInputRecord>()) {
            for r in existing { modelContext.delete(r) }
        }
        for dto in dtos {
            modelContext.insert(ShiftInputRecord(
                date: dto.date,
                shiftInputTypeId: dto.shiftInputTypeId,
                shortName: dto.shortName,
                colorHex: dto.colorHex,
                targetShiftName: dto.targetShiftName,
                originalShiftName: dto.originalShiftName,
                groupId: dto.groupId,
                createdAt: dto.createdAt
            ))
        }
        try? modelContext.save()
    }

    /// Insert a multi-day shift-input run using the rotating pattern (mirrors Android logic).
    /// - For each day from `startDate` to `startDate + days - 1`:
    ///   - The displayed target shift is taken from the pattern at offset.
    ///   - The "original" shift is the existing ShiftSchedule on that day if any.
    func createRun(
        type: ShiftInputTypeDTO,
        startDate: Date,
        days: Int,
        shiftPattern: [String],
        targetShiftName: String,
        originalShiftLookup: (Date) -> String
    ) {
        guard !shiftPattern.isEmpty, days > 0 else { return }
        let groupId = UUID()
        // 패턴에 있는 근무면 회전, 없으면 (예: diaSelects에만 있는 특수 근무) 전 일자 동일 적용.
        let targetIndex = shiftPattern.firstIndex(of: targetShiftName)
        let cal = ShiftRotationEngine.calendar
        let baseDay = cal.startOfDay(for: startDate)
        let size = shiftPattern.count

        for offset in 0..<days {
            let day = cal.date(byAdding: .day, value: offset, to: baseDay) ?? baseDay
            let mappedShift: String
            if let targetIndex {
                let raw = (targetIndex + offset) % size
                let idx = (raw + size) % size
                mappedShift = shiftPattern[idx]
            } else {
                mappedShift = targetShiftName
            }
            let original = originalShiftLookup(day)

            let predicate = #Predicate<ShiftInputRecord> { $0.date == day }
            if let existing = try? modelContext.fetch(FetchDescriptor(predicate: predicate)).first {
                existing.shiftInputTypeId = type.id
                existing.shortName = type.shortName
                existing.colorHex = type.colorHex
                existing.targetShiftName = mappedShift
                existing.originalShiftName = original
                existing.groupId = groupId
            } else {
                modelContext.insert(ShiftInputRecord(
                    date: day,
                    shiftInputTypeId: type.id,
                    shortName: type.shortName,
                    colorHex: type.colorHex,
                    targetShiftName: mappedShift,
                    originalShiftName: original,
                    groupId: groupId
                ))
            }
        }
        try? modelContext.save()
    }

    func delete(on date: Date) {
        let day = ShiftRotationEngine.startOfDay(date)
        let predicate = #Predicate<ShiftInputRecord> { $0.date == day }
        if let existing = try? modelContext.fetch(FetchDescriptor(predicate: predicate)).first {
            modelContext.delete(existing)
            try? modelContext.save()
        }
    }

    func deleteGroup(_ groupId: UUID) {
        let predicate = #Predicate<ShiftInputRecord> { $0.groupId == groupId }
        if let existing = try? modelContext.fetch(FetchDescriptor(predicate: predicate)) {
            for r in existing { modelContext.delete(r) }
            try? modelContext.save()
        }
    }
}
