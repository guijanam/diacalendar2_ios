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

    /// 오늘 근무를 워치로 전송한다.
    /// - updateApplicationContext: "마지막 상태"를 덮어써 워치가 나중에 켜져도 즉시 최신값을 받는다(가장 신뢰도 높음).
    /// - transferUserInfo: 큐 기반 백업 경로(워치 미실행 중에도 다음 기회에 도착).
    func sendTodayShift(_ payload: WatchShiftPayload) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default

        switch session.activationState {
        case .activated:
            // 페어링된 워치 앱이 설치된 경우에만 전송 시도.
            guard session.isPaired && session.isWatchAppInstalled else { return }
            let info = payload.toUserInfo()
            // 1순위: application context (항상 최신 1건 보장).
            try? session.updateApplicationContext(info)
            // 2순위: 큐 전송(앱 컨텍스트가 지원 안 되는 상황 대비).
            session.transferUserInfo(info)
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
