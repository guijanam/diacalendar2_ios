//
//  HolidayRepository.swift
//  DiaCalendar2
//

import Foundation
import SwiftData

@ModelActor
actor HolidayRepository {
    func all() -> [HolidayRecordDTO] {
        var d = FetchDescriptor<HolidayRecord>()
        d.sortBy = [SortDescriptor(\.date, order: .forward)]
        return ((try? modelContext.fetch(d)) ?? []).map { $0.toDTO() }
    }

    /// 메모리 lookup용 [Date(KST 자정): name] 맵.
    func map() -> [Date: String] {
        var out: [Date: String] = [:]
        for r in all() { out[r.date] = r.name }
        return out
    }

    func count() -> Int {
        (try? modelContext.fetchCount(FetchDescriptor<HolidayRecord>())) ?? 0
    }

    /// 전체 교체. fetch 결과를 그대로 신뢰하므로 기존 row 모두 삭제 후 새로 insert.
    func replaceAll(with items: [HolidayRecordDTO], locdateRaws: [Date: String]) {
        if let existing = try? modelContext.fetch(FetchDescriptor<HolidayRecord>()) {
            for r in existing { modelContext.delete(r) }
        }
        let now = Date()
        for dto in items {
            modelContext.insert(HolidayRecord(
                date: dto.date,
                name: dto.name,
                locdateRaw: locdateRaws[dto.date] ?? "",
                updatedAt: now
            ))
        }
        try? modelContext.save()
    }
}
