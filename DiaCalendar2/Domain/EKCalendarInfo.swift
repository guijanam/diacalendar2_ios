//
//  EKCalendarInfo.swift
//  DiaCalendar2
//

import Foundation

enum EKCalendarSourceKind: String, Sendable {
    case local
    case exchange
    case calDAV
    case mobileMe
    case subscribed
    case birthdays
    case other

    var displayTitle: String {
        switch self {
        case .local: return "이 기기"
        case .exchange: return "Exchange"
        case .calDAV: return "CalDAV"
        case .mobileMe: return "iCloud"
        case .subscribed: return "구독"
        case .birthdays: return "생일"
        case .other: return "기타"
        }
    }

    /// 정렬 우선순위 — 사용자가 가장 자주 쓰는 iCloud / 로컬을 위로.
    var sortOrder: Int {
        switch self {
        case .mobileMe: return 0
        case .local: return 1
        case .calDAV: return 2
        case .exchange: return 3
        case .subscribed: return 4
        case .birthdays: return 5
        case .other: return 6
        }
    }
}

struct EKCalendarInfo: Sendable, Identifiable, Equatable {
    let id: String
    let title: String
    let colorHex: String?
    let sourceTitle: String
    let sourceKind: EKCalendarSourceKind

    var identifier: String { id }
}
