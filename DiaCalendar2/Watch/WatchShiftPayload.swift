//
//  WatchShiftPayload.swift
//  DiaCalendar2
//
//  폰 → 워치로 WCSession.transferUserInfo 를 통해 전달하는 "오늘 근무" 페이로드.
//
//  ⚠️ 이 파일은 워치 타깃의 "DiaCalendar2Watch Watch App/WatchShiftPayload.swift" 와
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
    /// 전반 열번. 없으면 빈 문자열.
    let numTr1: String
    /// 전반 시간. 없으면 빈 문자열.
    let firstTime: String
    /// 후반 열번. 없으면 빈 문자열.
    let numTr2: String
    /// 후반 시간. 없으면 빈 문자열.
    let secondTime: String

    /// transferUserInfo 가 받는 [String: Any] 로 변환.
    func toUserInfo() -> [String: Any] {
        [
            WatchPayloadKeys.kind: WatchPayloadKeys.todayShiftKind,
            WatchPayloadKeys.date: date.timeIntervalSince1970,
            WatchPayloadKeys.dia: dia,
            WatchPayloadKeys.workTime: workTime,
            WatchPayloadKeys.numTr1: numTr1,
            WatchPayloadKeys.firstTime: firstTime,
            WatchPayloadKeys.numTr2: numTr2,
            WatchPayloadKeys.secondTime: secondTime
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
        // 신규 필드는 구버전 페이로드 호환을 위해 누락 시 빈 문자열.
        self.numTr1 = userInfo[WatchPayloadKeys.numTr1] as? String ?? ""
        self.firstTime = userInfo[WatchPayloadKeys.firstTime] as? String ?? ""
        self.numTr2 = userInfo[WatchPayloadKeys.numTr2] as? String ?? ""
        self.secondTime = userInfo[WatchPayloadKeys.secondTime] as? String ?? ""
    }

    init(date: Date,
         dia: String,
         workTime: String,
         numTr1: String = "",
         firstTime: String = "",
         numTr2: String = "",
         secondTime: String = "") {
        self.date = date
        self.dia = dia
        self.workTime = workTime
        self.numTr1 = numTr1
        self.firstTime = firstTime
        self.numTr2 = numTr2
        self.secondTime = secondTime
    }
}

enum WatchPayloadKeys {
    static let kind = "kind"
    static let todayShiftKind = "todayShift"
    static let date = "date"
    static let dia = "dia"
    static let workTime = "workTime"
    static let numTr1 = "numTr1"
    static let firstTime = "firstTime"
    static let numTr2 = "numTr2"
    static let secondTime = "secondTime"

    /// 워치가 마지막 수신 페이로드를 캐시해 두는 UserDefaults 키(워치 측 자체 저장소).
    static let cachedPayloadDefaultsKey = "watch.cachedTodayShift"
}
