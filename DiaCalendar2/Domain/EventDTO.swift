//
//  EventDTO.swift
//  DiaCalendar2
//

import Foundation

struct EventDTO: Sendable, Identifiable, Equatable {
    /// EK 이벤트 식별자.
    let ekEventIdentifier: String
    /// 반복 이벤트의 특정 발생 시작 시각. 셀 렌더링과 occurrence 매칭에 사용.
    let occurrenceStart: Date

    var title: String
    var start: Date
    var end: Date
    var isAllDay: Bool
    var notes: String?
    var ekCalendarIdentifier: String?
    var recurrence: EventRecurrence?
    var alarms: [EventAlarm]

    /// 반복 이벤트의 occurrence를 구분하기 위해 식별자 + 시작 시간을 합성.
    var id: String {
        "\(ekEventIdentifier)@\(occurrenceStart.timeIntervalSince1970)"
    }
}
