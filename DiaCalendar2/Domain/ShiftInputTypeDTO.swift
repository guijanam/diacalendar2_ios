//
//  ShiftInputTypeDTO.swift
//  DiaCalendar2
//

import Foundation

struct ShiftInputTypeDTO: Sendable, Hashable, Identifiable {
    var id: UUID
    var name: String
    var shortName: String
    var colorHex: String
    var requiresLateWork: Bool
}

/// Defaults seeded on first launch (mirrors Android `ShiftInputTypeRepositoryImpl`).
nonisolated enum ShiftInputDefaults {
    nonisolated static let entries: [(name: String, shortName: String, colorHex: String, requiresLateWork: Bool)] = [
        ("대기충당", "대", "#4CAF50", true),
        ("휴무충당", "휴", "#9C27B0", true),
        ("지근충당", "지근", "05F4FA", true)
    ]
}
