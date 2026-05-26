//
//  UserShiftConfig.swift
//  DiaCalendar2
//

import Foundation
import SwiftData

/// Singleton (id == "singleton") describing the user's current shift setup.
/// Matches Android `UserShiftConfigEntity` (id=1 there).
@Model
final class UserShiftConfig {
    @Attribute(.unique) var id: String
    var officeCode: Int64
    var officeName: String
    var position: String          // "기관사" / "차장" / "4조2교대" / "custom"
    var shiftPatternCsv: String   // "1,2,비,주휴"
    var startDate: Date           // 캘린더에 보여줄 시작일
    var referenceDate: Date       // 기준 날짜
    var todayShift: String        // 기준 날짜의 근무번호
    var todayShiftIndex: Int      // 패턴에서의 위치 (중복 이름 처리용); -1이면 자동 탐색
    var createdAt: Date

    init(
        id: String = "singleton",
        officeCode: Int64,
        officeName: String,
        position: String,
        shiftPatternCsv: String,
        startDate: Date,
        referenceDate: Date,
        todayShift: String,
        todayShiftIndex: Int = -1,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.officeCode = officeCode
        self.officeName = officeName
        self.position = position
        self.shiftPatternCsv = shiftPatternCsv
        self.startDate = startDate
        self.referenceDate = referenceDate
        self.todayShift = todayShift
        self.todayShiftIndex = todayShiftIndex
        self.createdAt = createdAt
    }

    func toDTO() -> UserShiftConfigDTO {
        UserShiftConfigDTO(
            officeCode: officeCode,
            officeName: officeName,
            position: ShiftPosition(rawValue: position) ?? .engineer,
            shiftPattern: csvToList(shiftPatternCsv),
            startDate: startDate,
            referenceDate: referenceDate,
            todayShift: todayShift,
            todayShiftIndex: todayShiftIndex >= 0 ? todayShiftIndex : nil,
            createdAt: createdAt
        )
    }
}
