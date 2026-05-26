//
//  UserShiftConfigRepository.swift
//  DiaCalendar2
//

import Foundation
import SwiftData

@ModelActor
actor UserShiftConfigRepository {
    private static let singletonId = "singleton"

    func load() -> UserShiftConfigDTO? {
        let key = Self.singletonId
        let predicate = #Predicate<UserShiftConfig> { $0.id == key }
        return (try? modelContext.fetch(FetchDescriptor(predicate: predicate)).first)?.toDTO()
    }

    func save(_ dto: UserShiftConfigDTO) {
        let key = Self.singletonId
        let predicate = #Predicate<UserShiftConfig> { $0.id == key }
        if let existing = try? modelContext.fetch(FetchDescriptor(predicate: predicate)).first {
            existing.officeCode = dto.officeCode
            existing.officeName = dto.officeName
            existing.position = dto.position.rawValue
            existing.shiftPatternCsv = listToCsv(dto.shiftPattern)
            existing.startDate = ShiftRotationEngine.startOfDay(dto.startDate)
            existing.referenceDate = ShiftRotationEngine.startOfDay(dto.referenceDate)
            existing.todayShift = dto.todayShift
            existing.todayShiftIndex = dto.todayShiftIndex ?? -1
        } else {
            modelContext.insert(UserShiftConfig(
                id: Self.singletonId,
                officeCode: dto.officeCode,
                officeName: dto.officeName,
                position: dto.position.rawValue,
                shiftPatternCsv: listToCsv(dto.shiftPattern),
                startDate: ShiftRotationEngine.startOfDay(dto.startDate),
                referenceDate: ShiftRotationEngine.startOfDay(dto.referenceDate),
                todayShift: dto.todayShift,
                todayShiftIndex: dto.todayShiftIndex ?? -1,
                createdAt: dto.createdAt
            ))
        }
        try? modelContext.save()
    }

    func clear() {
        let key = Self.singletonId
        let predicate = #Predicate<UserShiftConfig> { $0.id == key }
        if let existing = try? modelContext.fetch(FetchDescriptor(predicate: predicate)).first {
            modelContext.delete(existing)
            try? modelContext.save()
        }
    }
}
