//
//  AttendanceType.swift
//  DiaCalendar2
//

import Foundation
import SwiftData

/// 사용자가 정의하는 휴가 종류 (연차/병가/경조사/출장 등).
@Model
final class AttendanceType {
    @Attribute(.unique) var id: UUID
    var name: String           // 예: "연차"
    var shortName: String      // 예: "연"
    var createdAt: Date

    // 사용 갯수 / 초기화 주기 (사용자 설정값을 저장하는 용도)
    var limitCount: Int? = nil   // nil 또는 0 = 무제한
    var resetMonth: Int? = 1     // 기본 1월
    var resetDay: Int? = 1       // 기본 1일
    var resetYear: Int? = nil    // nil = 매년, 값 있으면 시작 년도
    var resetCycleYears: Int = 1 // N년마다 초기화 (기본 매년)

    init(
        id: UUID = UUID(),
        name: String,
        shortName: String,
        createdAt: Date = Date(),
        limitCount: Int? = nil,
        resetMonth: Int? = 1,
        resetDay: Int? = 1,
        resetYear: Int? = nil,
        resetCycleYears: Int = 1
    ) {
        self.id = id
        self.name = name
        self.shortName = shortName
        self.createdAt = createdAt
        self.limitCount = limitCount
        self.resetMonth = resetMonth
        self.resetDay = resetDay
        self.resetYear = resetYear
        self.resetCycleYears = resetCycleYears
    }

    func toDTO() -> AttendanceTypeDTO {
        AttendanceTypeDTO(
            id: id,
            name: name,
            shortName: shortName,
            createdAt: createdAt,
            limitCount: limitCount,
            resetMonth: resetMonth,
            resetDay: resetDay,
            resetYear: resetYear,
            resetCycleYears: resetCycleYears
        )
    }
}
