//
//  PaywallGateModifier.swift
//  DiaCalendar2
//

import SwiftUI

// MARK: - Trigger Mode

enum PaywallTriggerMode {
    /// 화면 진입 시 항상 페이월 표시 (구독 안 된 경우)
    case always
    /// 누적 사용 횟수가 한도를 초과하면 페이월 표시
    case usageLimited
    /// DayDetailSheet를 3번째 열 때마다 페이월 표시 (앱 실행과 별도 카운터)
    case dayDetailUsageLimited
    /// 근무표 탭을 3번째 열 때마다 페이월 표시 (앱 실행과 별도 카운터)
    case diaTableUsageLimited
}

// MARK: - ViewModifier

struct PaywallGateModifier: ViewModifier {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(\.dismiss) private var dismiss
    let mode: PaywallTriggerMode
    @State private var showPaywall = false

    func body(content: Content) -> some View {
        content
            .onAppear { evaluate() }
            .onChange(of: appEnvironment.revenueCatService.hasCompletedInitialCheck) { _, completed in
                // 앱 실행 직후 구독 확인이 늦게 끝난 경우, 완료 시점에 한 번 더 평가한다.
                if completed { evaluate() }
            }
            .sheet(isPresented: $showPaywall, onDismiss: handlePaywallDismiss) {
                CustomPaywallView()
            }
    }

    private func evaluate() {
        // 구독 상태 확인이 끝나기 전에는 평가하지 않는다.
        // (확인 완료 시 onChange가 다시 호출한다.) 구독자에게 페이월이 잘못 노출되는 것을 방지.
        guard appEnvironment.revenueCatService.hasCompletedInitialCheck else { return }
        guard !appEnvironment.revenueCatService.isVIP else { return }
        guard !appEnvironment.revenueCatService.isSubscribed else { return }
        // 결제/복원 진행 중에는 다른 화면의 게이트가 페이월을 중복 노출하지 않도록 한다.
        guard !appEnvironment.revenueCatService.isPurchaseInProgress else { return }
        switch mode {
        case .always:
            showPaywall = true
        case .usageLimited:
            if UsageLimitManager.hasExceededLimit {
                showPaywall = true
                UsageLimitManager.reset()
            } else {
                UsageLimitManager.increment()
            }
        case .dayDetailUsageLimited:
            if UsageLimitManager.shouldShowDayDetailPaywall {
                showPaywall = true
                UsageLimitManager.resetDayDetail()
            } else {
                UsageLimitManager.incrementDayDetail()
            }
        case .diaTableUsageLimited:
            if UsageLimitManager.shouldShowDiaTablePaywall {
                showPaywall = true
                UsageLimitManager.resetDiaTable()
            } else {
                UsageLimitManager.incrementDiaTable()
            }
        }
    }

    private func handlePaywallDismiss() {
        guard !appEnvironment.revenueCatService.isVIP else { return }
        guard !appEnvironment.revenueCatService.isSubscribed else { return }
        dismiss()
    }
}

// MARK: - View Extension

extension View {
    /// 구독 게이트를 적용합니다.
    /// - Parameter mode: `.always` — 항상, `.usageLimited` — 횟수 초과 시
    func paywallGate(_ mode: PaywallTriggerMode) -> some View {
        modifier(PaywallGateModifier(mode: mode))
    }
}
