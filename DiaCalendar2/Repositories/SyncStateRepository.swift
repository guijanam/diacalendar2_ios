//
//  SyncStateRepository.swift
//  DiaCalendar2
//

import Foundation
import SwiftData

@ModelActor
actor SyncStateRepository {
    private func loadOrCreate() -> SyncState {
        let predicate = #Predicate<SyncState> { $0.id == "singleton" }
        if let existing = try? modelContext.fetch(FetchDescriptor(predicate: predicate)).first {
            return existing
        }
        let new = SyncState()
        modelContext.insert(new)
        try? modelContext.save()
        return new
    }

    func defaultEKCalendarIdentifier() -> String? {
        loadOrCreate().defaultEKCalendarIdentifier
    }

    func setDefaultEKCalendarIdentifier(_ identifier: String?) {
        let state = loadOrCreate()
        state.defaultEKCalendarIdentifier = identifier
        try? modelContext.save()
    }

    func lastSupabaseShiftSyncAt() -> Date? {
        loadOrCreate().lastSupabaseShiftSyncAt
    }

    func setLastSupabaseShiftSyncAt(_ date: Date?) {
        let state = loadOrCreate()
        state.lastSupabaseShiftSyncAt = date
        try? modelContext.save()
    }

    func lastHolidaySyncAt() -> Date? {
        loadOrCreate().lastHolidaySyncAt
    }

    func setLastHolidaySyncAt(_ date: Date?) {
        let state = loadOrCreate()
        state.lastHolidaySyncAt = date
        try? modelContext.save()
    }

    func visibleCalendarIdentifiers() -> Set<String> {
        loadOrCreate().visibleCalendarIdentifiers
    }

    func setVisibleCalendarIdentifiers(_ identifiers: Set<String>) {
        let state = loadOrCreate()
        state.visibleCalendarIdentifiers = identifiers
        try? modelContext.save()
    }
}
