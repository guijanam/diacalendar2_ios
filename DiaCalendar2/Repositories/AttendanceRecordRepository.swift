//
//  AttendanceRecordRepository.swift
//  DiaCalendar2
//

import Foundation
import SwiftData

@ModelActor
actor AttendanceRecordRepository {
    func records(in interval: DateInterval) -> [AttendanceRecordDTO] {
        let start = interval.start
        let end = interval.end
        let predicate = #Predicate<AttendanceRecord> { r in
            r.date >= start && r.date < end
        }
        return ((try? modelContext.fetch(FetchDescriptor(predicate: predicate))) ?? []).map { $0.toDTO() }
    }

    func record(on date: Date) -> AttendanceRecordDTO? {
        let day = ShiftRotationEngine.startOfDay(date)
        let predicate = #Predicate<AttendanceRecord> { $0.date == day }
        return (try? modelContext.fetch(FetchDescriptor(predicate: predicate)).first)?.toDTO()
    }

    /// `startDate`부터 `days` 일간 같은 휴가를 등록. 회전 없이 모든 날 동일한 name/shortName.
    /// 같은 날짜에 이미 휴가가 있으면 덮어쓰기. groupId로 묶음.
    func createRun(
        type: AttendanceTypeDTO,
        startDate: Date,
        days: Int,
        originalShiftLookup: (Date) -> String
    ) {
        guard days > 0 else { return }
        let groupId = UUID()
        let cal = ShiftRotationEngine.calendar
        let baseDay = cal.startOfDay(for: startDate)

        for offset in 0..<days {
            let day = cal.date(byAdding: .day, value: offset, to: baseDay) ?? baseDay
            let original = originalShiftLookup(day)

            let predicate = #Predicate<AttendanceRecord> { $0.date == day }
            if let existing = try? modelContext.fetch(FetchDescriptor(predicate: predicate)).first {
                existing.attendanceTypeId = type.id
                existing.name = type.name
                existing.shortName = type.shortName
                existing.originalShiftName = original
                existing.groupId = groupId
            } else {
                modelContext.insert(AttendanceRecord(
                    date: day,
                    attendanceTypeId: type.id,
                    name: type.name,
                    shortName: type.shortName,
                    originalShiftName: original,
                    groupId: groupId
                ))
            }
        }
        try? modelContext.save()
    }

    /// 지근/지휴 멀티데이 등록. AttendanceType 없이 고정 이름(category.displayName)으로 등록한다.
    /// 같은 날짜에 이미 근태가 있으면 덮어쓰기. groupId로 묶음.
    func createCategoryRun(
        category: AttendanceCategory,
        startDate: Date,
        days: Int,
        originalShiftLookup: (Date) -> String
    ) {
        guard days > 0, category != .normal else { return }
        let groupId = UUID()
        let cal = ShiftRotationEngine.calendar
        let baseDay = cal.startOfDay(for: startDate)
        let name = category.displayName

        for offset in 0..<days {
            let day = cal.date(byAdding: .day, value: offset, to: baseDay) ?? baseDay
            let original = originalShiftLookup(day)

            let predicate = #Predicate<AttendanceRecord> { $0.date == day }
            if let existing = try? modelContext.fetch(FetchDescriptor(predicate: predicate)).first {
                existing.attendanceTypeId = UUID()
                existing.name = name
                existing.shortName = name
                existing.originalShiftName = original
                existing.groupId = groupId
                existing.category = category
            } else {
                modelContext.insert(AttendanceRecord(
                    date: day,
                    attendanceTypeId: UUID(),
                    name: name,
                    shortName: name,
                    originalShiftName: original,
                    groupId: groupId,
                    category: category
                ))
            }
        }
        try? modelContext.save()
    }

    func delete(on date: Date) {
        let day = ShiftRotationEngine.startOfDay(date)
        let predicate = #Predicate<AttendanceRecord> { $0.date == day }
        if let existing = try? modelContext.fetch(FetchDescriptor(predicate: predicate)).first {
            modelContext.delete(existing)
            try? modelContext.save()
        }
    }

    func deleteGroup(_ groupId: UUID) {
        let predicate = #Predicate<AttendanceRecord> { $0.groupId == groupId }
        if let existing = try? modelContext.fetch(FetchDescriptor(predicate: predicate)) {
            for r in existing { modelContext.delete(r) }
            try? modelContext.save()
        }
    }
}
