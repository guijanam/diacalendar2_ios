//
//  ShiftInputType.swift
//  DiaCalendar2
//

import Foundation
import SwiftData

/// Catalog row describing a kind of "충당" (대기충당 / 휴무충당 / 지근충당).
@Model
final class ShiftInputType {
    @Attribute(.unique) var id: UUID
    var name: String
    var shortName: String
    var colorHex: String
    var requiresLateWork: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        shortName: String,
        colorHex: String,
        requiresLateWork: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.shortName = shortName
        self.colorHex = colorHex
        self.requiresLateWork = requiresLateWork
        self.createdAt = createdAt
    }

    func toDTO() -> ShiftInputTypeDTO {
        ShiftInputTypeDTO(
            id: id,
            name: name,
            shortName: shortName,
            colorHex: colorHex,
            requiresLateWork: requiresLateWork
        )
    }
}
