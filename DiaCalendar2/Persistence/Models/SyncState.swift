//
//  SyncState.swift
//  DiaCalendar2
//

import Foundation
import SwiftData

@Model
final class SyncState {
    @Attribute(.unique) var id: String
    var lastSupabaseShiftSyncAt: Date?
    /// 마지막으로 Supabase `holidays` 테이블을 fetch 한 시각.
    var lastHolidaySyncAt: Date?
    /// 새 이벤트를 push할 때 기본으로 사용할 EK 캘린더.
    var defaultEKCalendarIdentifier: String?
    /// 캘린더 화면에 표시할 EK 캘린더 식별자 집합 (JSON 인코딩). 비어 있으면 모든 쓰기 가능 캘린더 표시.
    var visibleCalendarIdentifiersData: Data?

    init(
        id: String = "singleton",
        lastSupabaseShiftSyncAt: Date? = nil,
        lastHolidaySyncAt: Date? = nil,
        defaultEKCalendarIdentifier: String? = nil,
        visibleCalendarIdentifiersData: Data? = nil
    ) {
        self.id = id
        self.lastSupabaseShiftSyncAt = lastSupabaseShiftSyncAt
        self.lastHolidaySyncAt = lastHolidaySyncAt
        self.defaultEKCalendarIdentifier = defaultEKCalendarIdentifier
        self.visibleCalendarIdentifiersData = visibleCalendarIdentifiersData
    }

    var visibleCalendarIdentifiers: Set<String> {
        get {
            guard let data = visibleCalendarIdentifiersData else { return [] }
            return (try? JSONDecoder().decode(Set<String>.self, from: data)) ?? []
        }
        set {
            visibleCalendarIdentifiersData = try? JSONEncoder().encode(newValue)
        }
    }
}
