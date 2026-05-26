//
//  RevenueCatService.swift
//  DiaCalendar2
//

import Observation
import RevenueCat
import UIKit

@Observable
@MainActor
final class RevenueCatService {

    // MARK: - Public State

    private(set) var isSubscribed: Bool = false
    private(set) var isVIP: Bool = false
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

    /// Supabase `coworker_list.device_id`에 현재 기기 ID가 등록되어 있는지 확인.
    /// 등록되어 있으면 RevenueCat 구독자와 동일하게 페이월을 우회한다.
    func checkVIP() async {
        guard let deviceId = UIDevice.current.identifierForVendor?.uuidString else { return }
        do {
            isVIP = try await SupabaseAPI.isRegisteredDevice(deviceId)
        } catch {
            // 네트워크 실패 시 기존 상태 유지
        }
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
