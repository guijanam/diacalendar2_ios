//
//  ShiftSwapRecordRepository.swift
//  DiaCalendar2
//

import Foundation
import SwiftData

@ModelActor
actor ShiftSwapRecordRepository {
    func swaps(in interval: DateInterval) -> [ShiftSwapRecordDTO] {
        let start = interval.start
        let end = interval.end
        let predicate = #Predicate<ShiftSwapRecord> { r in
            r.date >= start && r.date < end
        }
        return ((try? modelContext.fetch(FetchDescriptor(predicate: predicate))) ?? []).map { $0.toDTO() }
    }

    func swap(on date: Date) -> ShiftSwapRecordDTO? {
        let day = ShiftRotationEngine.startOfDay(date)
        let predicate = #Predicate<ShiftSwapRecord> { $0.date == day }
        return (try? modelContext.fetch(FetchDescriptor(predicate: predicate)).first)?.toDTO()
    }

    /// Insert or replace a swap on `date`.
    func upsert(date: Date, originalShiftName: String, swappedShiftName: String) {
        let day = ShiftRotationEngine.startOfDay(date)
        let predicate = #Predicate<ShiftSwapRecord> { $0.date == day }
        if let existing = try? modelContext.fetch(FetchDescriptor(predicate: predicate)).first {
            existing.originalShiftName = originalShiftName
            existing.swappedShiftName = swappedShiftName
        } else {
            modelContext.insert(ShiftSwapRecord(
                date: day,
                originalShiftName: originalShiftName,
                swappedShiftName: swappedShiftName
            ))
        }
        try? modelContext.save()
    }

    func delete(on date: Date) {
        let day = ShiftRotationEngine.startOfDay(date)
        let predicate = #Predicate<ShiftSwapRecord> { $0.date == day }
        if let existing = try? modelContext.fetch(FetchDescriptor(predicate: predicate)).first {
            modelContext.delete(existing)
            try? modelContext.save()
        }
    }

    func deleteGroup(_ groupId: UUID) {
        let predicate = #Predicate<ShiftSwapRecord> { $0.groupId == groupId }
        if let existing = try? modelContext.fetch(FetchDescriptor(predicate: predicate)) {
            for r in existing { modelContext.delete(r) }
            try? modelContext.save()
        }
    }

    /// 멀티데이 교번교체. `startDate` 부터 `days` 일간 패턴을 순환하며 교체한다.
    /// 예: pattern=["A","B","C"], targetShiftName="B", days=3
    ///   Day0 → B, Day1 → C, Day2 → A
    /// `originalShiftLookup` 은 해당 날짜의 기본 ShiftSchedule.shiftName 을 돌려준다.
    func createRun(
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
            let swappedName: String
            if let targetIndex {
                let raw = (targetIndex + offset) % size
                let idx = (raw + size) % size
                swappedName = shiftPattern[idx]
            } else {
                swappedName = targetShiftName
            }
            let original = originalShiftLookup(day)

            let predicate = #Predicate<ShiftSwapRecord> { $0.date == day }
            if let existing = try? modelContext.fetch(FetchDescriptor(predicate: predicate)).first {
                existing.originalShiftName = original
                existing.swappedShiftName = swappedName
                existing.groupId = groupId
            } else {
                modelContext.insert(ShiftSwapRecord(
                    date: day,
                    originalShiftName: original,
                    swappedShiftName: swappedName,
                    groupId: groupId
                ))
            }
        }
        try? modelContext.save()
    }
}
