//
//  Coworker.swift
//  DiaCalendar2
//

import Foundation
import SwiftData

/// A colleague whose rotating shift schedule is computed and shown alongside the user's.
/// Mirrors Android `CoworkerEntity`. The schedule itself is never persisted — it is
/// recomputed on demand via `ShiftRotationEngine`.
@Model
final class Coworker {
    @Attribute(.unique) var id: UUID
    var name: String
    var sortOrder: Int
    /// 소속 그룹 id 목록 (UUID CSV, 여러 그룹 중복 가능)
    var groupIdsCsv: String
    /// 근무 순환 패턴 (CSV, 예: "주,야,비,휴")
    var shiftPatternCsv: String
    /// 기준 날짜 (start-of-day, Asia/Seoul)
    var referenceDate: Date
    /// 기준 근무명
    var referenceShift: String
    /// 기준 근무의 패턴 내 인덱스 (중복 근무명 구분용)
    var referenceShiftIndex: Int?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        sortOrder: Int = 0,
        groupIdsCsv: String = "",
        shiftPatternCsv: String = "",
        referenceDate: Date,
        referenceShift: String = "",
        referenceShiftIndex: Int? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
        self.groupIdsCsv = groupIdsCsv
        self.shiftPatternCsv = shiftPatternCsv
        self.referenceDate = referenceDate
        self.referenceShift = referenceShift
        self.referenceShiftIndex = referenceShiftIndex
        self.createdAt = createdAt
    }

    func toDTO() -> CoworkerDTO {
        CoworkerDTO(
            id: id,
            name: name,
            sortOrder: sortOrder,
            groupIds: csvToUUIDList(groupIdsCsv),
            shiftPattern: csvToList(shiftPatternCsv),
            referenceDate: referenceDate,
            referenceShift: referenceShift,
            referenceShiftIndex: referenceShiftIndex,
            createdAt: createdAt
        )
    }
}

/// A named bucket colleagues can belong to (many-to-many). Mirrors Android `CoworkerGroupEntity`.
@Model
final class CoworkerGroup {
    @Attribute(.unique) var id: UUID
    var name: String
    var sortOrder: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        sortOrder: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }

    func toDTO() -> CoworkerGroupDTO {
        CoworkerGroupDTO(id: id, name: name, sortOrder: sortOrder, createdAt: createdAt)
    }
}

// MARK: - UUID CSV helpers

nonisolated func csvToUUIDList(_ csv: String) -> [UUID] {
    csv.split(separator: ",")
        .compactMap { UUID(uuidString: $0.trimmingCharacters(in: .whitespaces)) }
}

nonisolated func uuidListToCsv(_ list: [UUID]) -> String {
    list.map { $0.uuidString }.joined(separator: ",")
}
