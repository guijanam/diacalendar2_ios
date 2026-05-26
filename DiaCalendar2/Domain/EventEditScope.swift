//
//  EventEditScope.swift
//  DiaCalendar2
//

import EventKit
import Foundation

/// 반복 이벤트 수정/삭제 적용 범위.
/// EKSpan과 1:1 매핑되며, Sendable이 아닌 EKSpan을 actor 경계 너머로 보내지 않기 위해 도입.
enum EventEditScope: Sendable, Equatable {
    case thisEvent
    case futureEvents

    var ekSpan: EKSpan {
        switch self {
        case .thisEvent: return .thisEvent
        case .futureEvents: return .futureEvents
        }
    }
}
