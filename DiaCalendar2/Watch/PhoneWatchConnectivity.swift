//
//  PhoneWatchConnectivity.swift
//  DiaCalendar2
//
//  폰(iOS) 측 WatchConnectivity 관리자.
//  WidgetDataGenerator 가 오늘 근무를 산출한 뒤 워치로 transferUserInfo 한다.
//

import Foundation
import WatchConnectivity

/// iOS 앱에서 워치로 당일 근무를 전송하는 싱글턴.
final class PhoneWatchConnectivity: NSObject {
    static let shared = PhoneWatchConnectivity()

    /// 세션이 아직 활성화되기 전에 들어온 마지막 페이로드(활성화 직후 재전송용).
    private var pendingPayload: WatchShiftPayload?

    private override init() {
        super.init()
    }

    /// 앱 시작 시 한 번 호출해 세션을 활성화한다.
    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// 오늘 근무를 워치로 전송한다. (transferUserInfo: 큐 기반 → 워치 미실행 중에도 다음 기회에 도착)
    func sendTodayShift(_ payload: WatchShiftPayload) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default

        switch session.activationState {
        case .activated:
            // 폰과 페어링된 워치 앱이 설치된 경우에만 전송 시도.
            if session.isPaired && session.isWatchAppInstalled {
                session.transferUserInfo(payload.toUserInfo())
            }
        default:
            // 아직 비활성: 활성화 후 보내도록 보관하고 activate 트리거.
            pendingPayload = payload
            session.delegate = self
            session.activate()
        }
    }
}

extension PhoneWatchConnectivity: WCSessionDelegate {
    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        if activationState == .activated, let payload = pendingPayload {
            pendingPayload = nil
            sendTodayShift(payload)
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        // 워치 전환 등으로 비활성화되면 재활성화.
        session.activate()
    }
}
