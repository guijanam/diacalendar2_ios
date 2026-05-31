//
//  RevenueCatService.swift
//  DiaCalendar2
//

import Observation
import RevenueCat
import UIKit
import WidgetKit

@Observable
@MainActor
final class RevenueCatService {

    // MARK: - Public State

    private(set) var isSubscribed: Bool = false {
        didSet { syncWidgetState() }
    }
    private(set) var isVIP: Bool = false {
        didSet { syncWidgetState() }
    }
    private(set) var isLoading: Bool = false
    private(set) var restoreError: String? = nil

    /// 앱 실행 후 구독 상태 확인이 최소 1회 완료되었는지 여부.
    /// 확인 전에는 페이월 게이트를 평가하지 않아 구독자에게 잘못 노출되는 것을 막는다.
    private(set) var hasCompletedInitialCheck: Bool = false

    /// 결제/복원이 진행 중인 동안 true. 다른 화면의 페이월 게이트 중복 노출을 막는 데 사용.
    var isPurchaseInProgress: Bool = false

    // MARK: - Configuration

    static let apiKey = "appl_hTihmOBmvtgNDcogCLxhyJidXeY"
    static let entitlementID = "DiaCalendar2 Premium"

    func configure() {
        Purchases.configure(withAPIKey: Self.apiKey)
        Purchases.logLevel = .warn
        // 구독 상태가 기본값(false)에서 변하지 않는 비구독자도 App Group 플래그가
        // 최소 1회 기록되도록 초기 동기화를 강제한다(didSet은 값이 바뀔 때만 발화).
        syncWidgetState()
    }

    // MARK: - Widget State Mirroring

    /// 구독/VIP 상태를 App Group으로 미러링하고 위젯 타임라인을 갱신한다.
    /// `isSubscribed`/`isVIP`의 didSet에서 호출되어 상태 변경 시 자동 반영된다.
    private func syncWidgetState() {
        let unlocked = isSubscribed || isVIP
        guard SharedSubscriptionState.widgetUnlocked != unlocked else { return }
        SharedSubscriptionState.widgetUnlocked = unlocked
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Subscription Check

    func checkSubscription() async {
        isLoading = true
        defer {
            isLoading = false
            hasCompletedInitialCheck = true
        }
        do {
            let info = try await Purchases.shared.customerInfo()
            isSubscribed = info.entitlements[Self.entitlementID]?.isActive == true
        } catch {
            // 네트워크 오류 등: 기존 상태 유지
        }
    }

    /// 결제/복원 결과로 직접 받은 CustomerInfo로 구독 상태를 갱신합니다.
    /// 네트워크 재조회 없이 결제 직후 상태를 즉시 반영하므로 페이월 재노출을 방지합니다.
    func updateSubscription(from info: CustomerInfo) {
        isSubscribed = info.entitlements[Self.entitlementID]?.isActive == true
    }

    // MARK: - VIP (평생 무료) Check

    private static let vipCacheKey = "rc_vip_status"
    private static let vipCacheTimestampKey = "rc_vip_status_timestamp"
    private static let vipCacheTTL: TimeInterval = 7 * 24 * 60 * 60 // 1주일

    /// Supabase `coworker_list.device_id`에 현재 기기 ID가 등록되어 있는지 확인.
    /// 캐시가 유효하면 서버 호출 없이 캐시값을 사용한다. TTL = 1주일.
    func checkVIP() async {
        if let cached = loadVIPCache() {
            isVIP = cached
            return
        }
        await fetchVIPFromServer()
    }

    /// 캐시를 무시하고 서버에서 강제로 VIP 상태를 갱신한다.
    func refreshVIP() async {
        await fetchVIPFromServer()
    }

    private func fetchVIPFromServer() async {
        guard let deviceId = UIDevice.current.identifierForVendor?.uuidString else { return }
        do {
            let result = try await SupabaseAPI.isRegisteredDevice(deviceId)
            isVIP = result
            saveVIPCache(result)
        } catch {
            // 네트워크 실패 시 기존 상태 유지
        }
    }

    private func loadVIPCache() -> Bool? {
        let defaults = UserDefaults.standard
        guard let timestamp = defaults.object(forKey: Self.vipCacheTimestampKey) as? Date else { return nil }
        guard Date().timeIntervalSince(timestamp) < Self.vipCacheTTL else { return nil }
        guard defaults.object(forKey: Self.vipCacheKey) != nil else { return nil }
        return defaults.bool(forKey: Self.vipCacheKey)
    }

    private func saveVIPCache(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: Self.vipCacheKey)
        UserDefaults.standard.set(Date(), forKey: Self.vipCacheTimestampKey)
    }

    // MARK: - Restore Purchases

    func restore() async {
        isLoading = true
        restoreError = nil
        defer { isLoading = false }
        do {
            let info = try await Purchases.shared.restorePurchases()
            updateSubscription(from: info)
        } catch {
            restoreError = "복원에 실패했습니다. 다시 시도해주세요."
        }
    }
}
