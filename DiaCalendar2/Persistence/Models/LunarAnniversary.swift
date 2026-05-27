//
//  LunarAnniversary.swift
//  DiaCalendar2
//

import Foundation
import SwiftData

@Model
final class LunarAnniversary {
    @Attribute(.unique) var id: UUID
    var title: String
    var lunarMonth: Int   // 1–12
    var lunarDay: Int     // 1–30
    var isLeapMonth: Bool // 윤달 여부
    var colorHex: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        lunarMonth: Int,
        lunarDay: Int,
        isLeapMonth: Bool = false,
        colorHex: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.lunarMonth = lunarMonth
        self.lunarDay = lunarDay
        self.isLeapMonth = isLeapMonth
        self.colorHex = colorHex
        self.createdAt = createdAt
    }

    func toDTO() -> LunarAnniversaryDTO {
        LunarAnniversaryDTO(
            id: id,
            title: title,
            lunarMonth: lunarMonth,
            lunarDay: lunarDay,
            isLeapMonth: isLeapMonth,
            colorHex: colorHex,
            createdAt: createdAt
        )
    }
}
