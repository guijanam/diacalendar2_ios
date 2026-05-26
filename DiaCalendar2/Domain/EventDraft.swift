//
//  EventDraft.swift
//  DiaCalendar2
//

import Foundation

struct EventDraft: Sendable, Equatable {
    /// 편집 모드일 때 EK 식별자. nil이면 새 이벤트.
    var ekEventIdentifier: String?
    var title: String
    var start: Date
    var end: Date
    var isAllDay: Bool
    var notes: String?
    var ekCalendarIdentifier: String?
    var recurrence: EventRecurrence?
    var alarms: [EventAlarm]

    static func new(start: Date, end: Date, isAllDay: Bool = false) -> EventDraft {
        EventDraft(
            ekEventIdentifier: nil,
            title: "",
            start: start,
            end: end,
            isAllDay: isAllDay,
            notes: nil,
            ekCalendarIdentifier: nil,
            recurrence: nil,
            alarms: []
        )
    }

    static func edit(from dto: EventDTO) -> EventDraft {
        EventDraft(
            ekEventIdentifier: dto.ekEventIdentifier,
            title: dto.title,
            start: dto.start,
            end: dto.end,
            isAllDay: dto.isAllDay,
            notes: dto.notes,
            ekCalendarIdentifier: dto.ekCalendarIdentifier,
            recurrence: dto.recurrence,
            alarms: dto.alarms
        )
    }
}
