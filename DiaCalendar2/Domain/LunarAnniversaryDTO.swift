//
//  LunarAnniversaryDTO.swift
//  DiaCalendar2
//

import Foundation

struct LunarAnniversaryDTO: Sendable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var lunarMonth: Int
    var lunarDay: Int
    var isLeapMonth: Bool
    var colorHex: String
    var createdAt: Date
}

enum LunarAnniversaryEditorMode: Equatable {
    case new(lunarMonth: Int, lunarDay: Int)
    case edit(LunarAnniversaryDTO)
}
