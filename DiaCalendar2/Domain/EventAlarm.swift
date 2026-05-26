//
//  EventAlarm.swift
//  DiaCalendar2
//

import Foundation

/// 시작 시각 기준 상대 시간(초 단위, 음수 = 이전).
struct EventAlarm: Codable, Sendable, Equatable, Identifiable {
    var id: UUID
    var offsetSeconds: TimeInterval

    init(id: UUID = UUID(), offsetSeconds: TimeInterval) {
        self.id = id
        self.offsetSeconds = offsetSeconds
    }
}

enum EventAlarmPreset: CaseIterable, Sendable {
    case atStart
    case fiveMinutesBefore
    case tenMinutesBefore
    case fifteenMinutesBefore
    case thirtyMinutesBefore
    case oneHourBefore
    case oneDayBefore

    var title: String {
        switch self {
        case .atStart: return "시작 시"
        case .fiveMinutesBefore: return "5분 전"
        case .tenMinutesBefore: return "10분 전"
        case .fifteenMinutesBefore: return "15분 전"
        case .thirtyMinutesBefore: return "30분 전"
        case .oneHourBefore: return "1시간 전"
        case .oneDayBefore: return "1일 전"
        }
    }

    var offsetSeconds: TimeInterval {
        switch self {
        case .atStart: return 0
        case .fiveMinutesBefore: return -5 * 60
        case .tenMinutesBefore: return -10 * 60
        case .fifteenMinutesBefore: return -15 * 60
        case .thirtyMinutesBefore: return -30 * 60
        case .oneHourBefore: return -60 * 60
        case .oneDayBefore: return -24 * 60 * 60
        }
    }

    static func match(_ offsetSeconds: TimeInterval) -> EventAlarmPreset? {
        EventAlarmPreset.allCases.first { abs($0.offsetSeconds - offsetSeconds) < 0.5 }
    }
}

extension EventAlarm {
    var summary: String {
        if let preset = EventAlarmPreset.match(offsetSeconds) {
            return preset.title
        }
        let absSeconds = Int(abs(offsetSeconds))
        let direction = offsetSeconds <= 0 ? "전" : "후"
        if absSeconds % 86_400 == 0 {
            return "\(absSeconds / 86_400)일 \(direction)"
        }
        if absSeconds % 3_600 == 0 {
            return "\(absSeconds / 3_600)시간 \(direction)"
        }
        if absSeconds % 60 == 0 {
            return "\(absSeconds / 60)분 \(direction)"
        }
        return "\(absSeconds)초 \(direction)"
    }
}
