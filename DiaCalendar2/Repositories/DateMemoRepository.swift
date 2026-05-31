//
//  DateMemoRepository.swift
//  DiaCalendar2
//

import Foundation
import SwiftData

@ModelActor
actor DateMemoRepository {
    /// 주어진 날짜를 포함하는 모든 메모를 반환.
    /// 반복 메모는 startDate가 조회 구간 밖에 있어도 Aggregator가 occurrence를 전개하므로
    /// startDate < dayEnd 조건만으로 전체를 가져온다.
    func memos(on date: Date, calendar: Calendar) -> [DateMemoDTO] {
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        let predicate = #Predicate<DateMemo> {
            ($0.startDate < dayEnd && $0.endDate >= dayStart) || $0.recurrenceData != nil
        }
        let descriptor = FetchDescriptor<DateMemo>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.startDate)]
        )
        return (try? modelContext.fetch(descriptor).map { $0.toDTO() }) ?? []
    }

    /// 주어진 구간에 걸친 모든 메모를 반환.
    /// 반복 메모는 startDate가 조회 구간 밖에 있어도 Aggregator가 occurrence를 전개하므로
    /// startDate < end 조건만으로 전체를 가져온다.
    func memos(in interval: DateInterval) -> [DateMemoDTO] {
        let start = interval.start
        let end = interval.end
        let predicate = #Predicate<DateMemo> {
            ($0.startDate < end && $0.endDate >= start) || $0.recurrenceData != nil
        }
        let descriptor = FetchDescriptor<DateMemo>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.startDate)]
        )
        return (try? modelContext.fetch(descriptor).map { $0.toDTO() }) ?? []
    }

    /// id로 단건 조회.
    func memo(with id: UUID) -> DateMemoDTO? {
        let predicate = #Predicate<DateMemo> { $0.id == id }
        return try? modelContext.fetch(FetchDescriptor(predicate: predicate)).first?.toDTO()
    }

    /// 백업용: 전체 조회(반복 메모 포함).
    func all() -> [DateMemoDTO] {
        ((try? modelContext.fetch(FetchDescriptor<DateMemo>())) ?? []).map { $0.toDTO() }
    }

    /// 복원용: 모든 메모 삭제.
    func deleteAll() {
        if let existing = try? modelContext.fetch(FetchDescriptor<DateMemo>()) {
            for m in existing { modelContext.delete(m) }
            try? modelContext.save()
        }
    }

    @discardableResult
    func upsert(_ dto: DateMemoDTO) -> DateMemoDTO? {
        let recurrenceData = dto.recurrence.flatMap { try? JSONEncoder().encode($0) }
        let id = dto.id
        let predicate = #Predicate<DateMemo> { $0.id == id }
        if let existing = try? modelContext.fetch(FetchDescriptor(predicate: predicate)).first {
            existing.title = dto.title
            existing.body = dto.body
            existing.colorHex = dto.colorHex
            existing.startDate = dto.startDate
            existing.endDate = dto.endDate
            existing.updatedAt = Date()
            existing.isDone = dto.isDone
            existing.recurrenceData = recurrenceData
            try? modelContext.save()
            return existing.toDTO()
        } else {
            let memo = DateMemo(
                id: dto.id,
                title: dto.title,
                body: dto.body,
                colorHex: dto.colorHex,
                startDate: dto.startDate,
                endDate: dto.endDate,
                isDone: dto.isDone,
                recurrenceData: recurrenceData
            )
            modelContext.insert(memo)
            try? modelContext.save()
            return memo.toDTO()
        }
    }

    func delete(id: UUID) {
        let predicate = #Predicate<DateMemo> { $0.id == id }
        if let memo = try? modelContext.fetch(FetchDescriptor(predicate: predicate)).first {
            modelContext.delete(memo)
            try? modelContext.save()
        }
    }
}
