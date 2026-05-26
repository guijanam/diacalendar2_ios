//
//  EventRecurrence.swift
//  DiaCalendar2
//

import Foundation

enum EventRecurrenceFrequency: String, Codable, Sendable, CaseIterable {
    case daily
    case weekly
    case monthly
    case yearly

    var title: String {
        switch self {
        case .daily: return "매일"
        case .weekly: return "매주"
        case .monthly: return "매월"
        case .yearly: return "매년"
        }
    }
}

enum EventRecurrenceEnd: Codable, Sendable, Equatable {
    case never
    case onDate(Date)
    case afterCount(Int)
}

struct EventRecurrence: Codable, Sendable, Equatable {
    var frequency: EventRecurrenceFrequency
    var interval: Int
    var end: EventRecurrenceEnd

    static let dailyForever = EventRecurrence(frequency: .daily, interval: 1, end: .never)
    static let weeklyForever = EventRecurrence(frequency: .weekly, interval: 1, end: .never)
    static let monthlyForever = EventRecurrence(frequency: .monthly, interval: 1, end: .never)
    static let yearlyForever = EventRecurrence(frequency: .yearly, interval: 1, end: .never)
}

extension EventRecurrence {
    var summary: String {
        let base: String
        switch frequency {
        case .daily:
            base = interval == 1 ? "매일" : "\(interval)일마다"
        case .weekly:
            base = interval == 1 ? "매주" : "\(interval)주마다"
        case .monthly:
            base = interval == 1 ? "매월" : "\(interval)개월마다"
        case .yearly:
            base = interval == 1 ? "매년" : "\(interval)년마다"
        }

        switch end {
        case .never:
            return base
        case .afterCount(let count):
            return "\(base), \(count)회"
        case .onDate(let date):
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return "\(base), \(formatter.string(from: date))까지"
        }
    }
}
