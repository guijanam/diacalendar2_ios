//
//  WatchConnectivityManager.swift
//  DiaCalendar2Watch Watch App
//
//  워치(watchOS) 측 WatchConnectivity 수신 관리자.
//  폰이 transferUserInfo 로 보낸 오늘 근무를 받아 @Published 로 UI에 반영하고,
//  마지막 값을 UserDefaults 에 캐시해 앱 재시작 시에도 즉시 표시한다.
//

import Combine
import Foundation
import WatchConnectivity

/// 폰에서 받은 당일 근무를 보관하는 관찰 가능 객체.
final class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()

    /// 현재 표시할 오늘 근무. nil 이면 아직 수신 전.
    @Published private(set) var todayShift: WatchShiftPayload?

    private override init() {
        super.init()
        todayShift = Self.loadCached()
    }

    /// 앱 시작 시 호출해 세션을 활성화한다.
    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    // MARK: - Cache

    private static func loadCached() -> WatchShiftPayload? {
        guard let data = UserDefaults.standard.data(forKey: WatchPayloadKeys.cachedPayloadDefaultsKey) else {
            return nil
        }
        return try? JSONDecoder().decode(WatchShiftPayload.self, from: data)
    }

    private func cache(_ payload: WatchShiftPayload) {
        if let data = try? JSONEncoder().encode(payload) {
            UserDefaults.standard.set(data, forKey: WatchPayloadKeys.cachedPayloadDefaultsKey)
        }
    }

    private func apply(_ payload: WatchShiftPayload) {
        DispatchQueue.main.async {
            self.todayShift = payload
            self.cache(payload)
        }
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {}

    /// transferUserInfo 로 도착한 오늘 근무 수신.
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        if let payload = WatchShiftPayload(userInfo: userInfo) {
            apply(payload)
        }
    }
}
