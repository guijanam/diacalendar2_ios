//
//  AttendanceRecord.swift
//  DiaCalendar2
//

import Foundation
import SwiftData

/// 특정 일자에 등록된 휴가 한 건. 가장 우선순위가 높은 오버레이.
@Model
final class AttendanceRecord {
    @Attribute(.unique) var date: Date       // KST 자정
    var attendanceTypeId: UUID
    var name: String                          // type.name 스냅샷
    var shortName: String                     // type.shortName 스냅샷
    var originalShiftName: String             // 베이스 ShiftSchedule.shiftName
    var groupId: UUID
    var createdAt: Date
    /// 근태 분류. AttendanceCategory.rawValue ("normal"/"jigeun"/"jihyu").
    /// 기존 데이터 마이그레이션 대비 기본값 "normal".
    var categoryRaw: String = AttendanceCategory.normal.rawValue

    /// 타입 안전한 분류 접근자.
    var category: AttendanceCategory {
        get { AttendanceCategory(rawValue: categoryRaw) ?? .normal }
        set { categoryRaw = newValue.rawValue }
    }

    init(
        date: Date,
        attendanceTypeId: UUID,
        name: String,
        shortName: String,
        originalShiftName: String,
        groupId: UUID = UUID(),
        createdAt: Date = Date(),
        category: AttendanceCategory = .normal
    ) {
        self.date = date
        self.attendanceTypeId = attendanceTypeId
        self.name = name
        self.shortName = shortName
        self.originalShiftName = originalShiftName
        self.groupId = groupId
        self.createdAt = createdAt
        self.categoryRaw = category.rawValue
    }

    func toDTO() -> AttendanceRecordDTO {
        AttendanceRecordDTO(
            date: date,
            attendanceTypeId: attendanceTypeId,
            name: name,
            shortName: shortName,
            originalShiftName: originalShiftName,
            groupId: groupId,
            createdAt: createdAt,
            category: category
        )
    }
}
