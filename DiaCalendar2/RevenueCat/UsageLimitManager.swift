//
//  UsageLimitManager.swift
//  DiaCalendar2
//

import Foundation

enum UsageLimitManager {
    static let freeLimit = 1
    private static let storageKey = "rc_usage_count"

    static var usageCount: Int {
        get { UserDefaults.standard.integer(forKey: storageKey) }
        set { UserDefaults.standard.set(newValue, forKey: storageKey) }
    }

    static var hasExceededLimit: Bool {
        usageCount >= freeLimit
    }

    static func increment() {
        usageCount += 1
    }

    static func reset() {
        usageCount = 0
    }

    // MARK: - DayDetailSheet 전용 카운터

    /// DayDetailSheet를 3번째 열 때 페이월 표시
    static let dayDetailFreeLimit = 2
    private static let dayDetailStorageKey = "rc_day_detail_usage_count"

    static var dayDetailUsageCount: Int {
        get { UserDefaults.standard.integer(forKey: dayDetailStorageKey) }
        set { UserDefaults.standard.set(newValue, forKey: dayDetailStorageKey) }
    }

    /// 이번 진입에서 페이월을 띄워야 하는지 (3번째 진입이면 true)
    static var shouldShowDayDetailPaywall: Bool {
        dayDetailUsageCount + 1 >= dayDetailFreeLimit
    }

    static func incrementDayDetail() {
        dayDetailUsageCount += 1
    }

    static func resetDayDetail() {
        dayDetailUsageCount = 0
    }

    // MARK: - 근무표 탭 전용 카운터

    /// 근무표 탭을 3번째 열 때 페이월 표시
    static let diaTableFreeLimit = 2
    private static let diaTableStorageKey = "rc_dia_table_usage_count"

    static var diaTableUsageCount: Int {
        get { UserDefaults.standard.integer(forKey: diaTableStorageKey) }
        set { UserDefaults.standard.set(newValue, forKey: diaTableStorageKey) }
    }

    /// 이번 진입에서 페이월을 띄워야 하는지 (3번째 진입이면 true)
    static var shouldShowDiaTablePaywall: Bool {
        diaTableUsageCount + 1 >= diaTableFreeLimit
    }

    static func incrementDiaTable() {
        diaTableUsageCount += 1
    }

    static func resetDiaTable() {
        diaTableUsageCount = 0
    }
}
