//
//  HolidayRecord.swift
//  DiaCalendar2
//

import Foundation
import SwiftData

/// 한국 공휴일 한 건. `date` 는 KST 자정 기준으로 저장.
@Model
final class HolidayRecord {
    @Attribute(.unique) var date: Date
    var name: String
    var locdateRaw: String
    var updatedAt: Date

    init(
        date: Date,
        name: String,
        locdateRaw: String,
        updatedAt: Date = Date()
    ) {
        self.date = date
        self.name = name
        self.locdateRaw = locdateRaw
        self.updatedAt = updatedAt
    }

    func toDTO() -> HolidayRecordDTO {
        HolidayRecordDTO(date: date, name: name)
    }
}
