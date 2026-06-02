//
//  WatchShiftPayload.swift
//  DiaCalendar2Watch Watch App
//
//  폰 → 워치로 WCSession.transferUserInfo 를 통해 전달받는 "오늘 근무" 페이로드.
//
//  ⚠️ 이 파일은 메인 앱 타깃의 "DiaCalendar2/Watch/WatchShiftPayload.swift" 와
//     내용이 동일하게 유지되어야 한다. (두 타깃이 각자 사본을 컴파일)
//

import Foundation

/// 워치에 표시할 당일 근무 요약. transferUserInfo dictionary 로 직렬화된다.
struct WatchShiftPayload: Codable, Equatable {
    /// 이 페이로드가 가리키는 날짜(KST 자정).
    let date: Date
    /// 근무명(교번). 근무 없으면 "근무없음".
    let dia: String
    /// 근무 시간 문자열. 없으면 빈 문자열.
    let workTime: String

    /// transferUserInfo 가 받는 [String: Any] 로 변환.
    func toUserInfo() -> [String: Any] {
        [
            WatchPayloadKeys.kind: WatchPayloadKeys.todayShiftKind,
            WatchPayloadKeys.date: date.timeIntervalSince1970,
            WatchPayloadKeys.dia: dia,
            WatchPayloadKeys.workTime: workTime
        ]
    }

    /// 수신한 [String: Any] 에서 복원. 형식이 맞지 않으면 nil.
    init?(userInfo: [String: Any]) {
        guard userInfo[WatchPayloadKeys.kind] as? String == WatchPayloadKeys.todayShiftKind,
              let ts = userInfo[WatchPayloadKeys.date] as? TimeInterval,
              let dia = userInfo[WatchPayloadKeys.dia] as? String,
              let workTime = userInfo[WatchPayloadKeys.workTime] as? String else {
            return nil
        }
        self.date = Date(timeIntervalSince1970: ts)
        self.dia = dia
        self.workTime = workTime
    }

    init(date: Date, dia: String, workTime: String) {
        self.date = date
        self.dia = dia
        self.workTime = workTime
    }
}

enum WatchPayloadKeys {
    static let kind = "kind"
    static let todayShiftKind = "todayShift"
    static let date = "date"
    static let dia = "dia"
    static let workTime = "workTime"

    /// 워치가 마지막 수신 페이로드를 캐시해 두는 UserDefaults 키(워치 측 자체 저장소).
    static let cachedPayloadDefaultsKey = "watch.cachedTodayShift"
}
