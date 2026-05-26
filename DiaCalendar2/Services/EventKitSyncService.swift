//
//  EventKitSyncService.swift
//  DiaCalendar2
//
//  EK를 single source of truth로 다루는 서비스.
//  앱은 EK에서 직접 이벤트를 fetch/create/update/delete하며 로컬 캐시를 두지 않는다.
//

import EventKit
import Foundation

actor EventKitSyncService {
    enum AuthorizationStatus: Sendable {
        case notDetermined
        case denied
        case restricted
        case authorized
        case writeOnly

        init(_ raw: EKAuthorizationStatus) {
            switch raw {
            case .notDetermined: self = .notDetermined
            case .denied: self = .denied
            case .restricted: self = .restricted
            case .fullAccess, .authorized: self = .authorized
            case .writeOnly: self = .writeOnly
            @unknown default: self = .denied
            }
        }

        var isAuthorized: Bool { self == .authorized }
    }

    private let store = EKEventStore()

    func currentAuthorizationStatus() -> AuthorizationStatus {
        AuthorizationStatus(EKEventStore.authorizationStatus(for: .event))
    }

    func requestAccess() async -> AuthorizationStatus {
        do {
            _ = try await store.requestFullAccessToEvents()
        } catch {
            return AuthorizationStatus(EKEventStore.authorizationStatus(for: .event))
        }
        return AuthorizationStatus(EKEventStore.authorizationStatus(for: .event))
    }

    // MARK: - Fetch

    /// 주어진 interval과 visible identifiers에 해당하는 EK 이벤트들을 DTO로 반환.
    /// visibleIdentifiers가 비어 있으면 빈 배열 반환.
    func fetchEvents(in interval: DateInterval, visibleIdentifiers: Set<String>) -> [EventDTO] {
        guard currentAuthorizationStatus().isAuthorized else { return [] }
        guard !visibleIdentifiers.isEmpty else { return [] }

        let calendarsToQuery: [EKCalendar] = visibleIdentifiers
            .compactMap { store.calendar(withIdentifier: $0) }
        guard !calendarsToQuery.isEmpty else { return [] }

        let predicate = store.predicateForEvents(
            withStart: interval.start,
            end: interval.end,
            calendars: calendarsToQuery
        )
        return store.events(matching: predicate).compactMap(Self.dto(from:))
    }

    func event(with identifier: String) -> EventDTO? {
        guard currentAuthorizationStatus().isAuthorized else { return nil }
        guard let ekEvent = store.event(withIdentifier: identifier) else { return nil }
        return Self.dto(from: ekEvent)
    }

    // MARK: - Mutations

    /// 새 이벤트를 EK에 저장. 성공 시 식별자 반환.
    func create(
        _ draft: EventDraft,
        defaultCalendarIdentifier: String?
    ) -> String? {
        guard currentAuthorizationStatus().isAuthorized else { return nil }

        let ekEvent = EKEvent(eventStore: store)
        applyDraft(draft, to: ekEvent)

        let preferred = draft.ekCalendarIdentifier ?? defaultCalendarIdentifier
        ekEvent.calendar = resolveCalendar(preferring: preferred)
        guard ekEvent.calendar != nil else { return nil }

        let span: EKSpan = draft.recurrence != nil ? .futureEvents : .thisEvent
        do {
            try store.save(ekEvent, span: span, commit: true)
            return ekEvent.eventIdentifier
        } catch {
            return nil
        }
    }

    /// 기존 EK 이벤트를 수정.
    @discardableResult
    func update(
        ekEventIdentifier: String,
        with draft: EventDraft,
        scope: EventEditScope
    ) -> Bool {
        guard currentAuthorizationStatus().isAuthorized else { return false }
        guard let ekEvent = store.event(withIdentifier: ekEventIdentifier) else { return false }

        applyDraft(draft, to: ekEvent)

        if
            let preferred = draft.ekCalendarIdentifier,
            ekEvent.calendar?.calendarIdentifier != preferred,
            let target = resolveCalendar(preferring: preferred)
        {
            ekEvent.calendar = target
        }

        let effectiveSpan: EKSpan
        if draft.recurrence != nil {
            effectiveSpan = scope == .thisEvent ? .thisEvent : .futureEvents
        } else {
            effectiveSpan = .thisEvent
        }

        do {
            try store.save(ekEvent, span: effectiveSpan, commit: true)
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    func delete(ekEventIdentifier: String, scope: EventEditScope) -> Bool {
        guard currentAuthorizationStatus().isAuthorized else { return false }
        guard let ekEvent = store.event(withIdentifier: ekEventIdentifier) else { return false }
        do {
            try store.remove(ekEvent, span: scope.ekSpan, commit: true)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Calendars

    /// 표시 용도: 모든 이벤트 캘린더(구독, 생일 등 read-only 포함).
    func readableCalendars() -> [EKCalendarInfo] {
        guard currentAuthorizationStatus().isAuthorized else { return [] }
        return store.calendars(for: .event)
            .map(Self.makeInfo(from:))
            .sorted(by: Self.calendarOrder)
    }

    /// 쓰기 용도: 새 이벤트를 저장할 수 있는 캘린더만.
    func writableCalendars() -> [EKCalendarInfo] {
        guard currentAuthorizationStatus().isAuthorized else { return [] }
        return store.calendars(for: .event)
            .filter { $0.allowsContentModifications }
            .map(Self.makeInfo(from:))
            .sorted(by: Self.calendarOrder)
    }

    func calendarInfo(for identifier: String) -> EKCalendarInfo? {
        guard currentAuthorizationStatus().isAuthorized else { return nil }
        guard let calendar = store.calendar(withIdentifier: identifier) else { return nil }
        return Self.makeInfo(from: calendar)
    }

    nonisolated func changeNotificationName() -> Notification.Name {
        .EKEventStoreChanged
    }

    // MARK: - Private helpers

    private func applyDraft(_ draft: EventDraft, to ekEvent: EKEvent) {
        ekEvent.title = draft.title
        ekEvent.startDate = draft.start
        ekEvent.endDate = max(draft.end, draft.start)
        ekEvent.isAllDay = draft.isAllDay
        ekEvent.notes = draft.notes
        applyRecurrence(draft.recurrence, to: ekEvent)
        applyAlarms(draft.alarms, to: ekEvent)
    }

    private func resolveCalendar(preferring identifier: String?) -> EKCalendar? {
        if
            let identifier,
            let calendar = store.calendar(withIdentifier: identifier),
            calendar.allowsContentModifications
        {
            return calendar
        }
        if
            let defaultCalendar = store.defaultCalendarForNewEvents,
            defaultCalendar.allowsContentModifications
        {
            return defaultCalendar
        }
        return store.calendars(for: .event).first { $0.allowsContentModifications }
    }

    @MainActor private static func calendarOrder(_ lhs: EKCalendarInfo, _ rhs: EKCalendarInfo) -> Bool {
        if lhs.sourceKind.sortOrder != rhs.sourceKind.sortOrder {
            return lhs.sourceKind.sortOrder < rhs.sourceKind.sortOrder
        }
        if lhs.sourceTitle != rhs.sourceTitle {
            return lhs.sourceTitle < rhs.sourceTitle
        }
        return lhs.title < rhs.title
    }

    private static func makeInfo(from calendar: EKCalendar) -> EKCalendarInfo {
        let kind: EKCalendarSourceKind
        switch calendar.source.sourceType {
        case .local: kind = .local
        case .exchange: kind = .exchange
        case .calDAV: kind = .calDAV
        case .mobileMe: kind = .mobileMe
        case .subscribed: kind = .subscribed
        case .birthdays: kind = .birthdays
        @unknown default: kind = .other
        }
        return EKCalendarInfo(
            id: calendar.calendarIdentifier,
            title: calendar.title,
            colorHex: hexString(from: calendar.cgColor),
            sourceTitle: calendar.source.title,
            sourceKind: kind
        )
    }

    private static func hexString(from cgColor: CGColor?) -> String? {
        guard let cgColor, let components = cgColor.components, components.count >= 3 else {
            return nil
        }
        let r = max(0, min(1, components[0]))
        let g = max(0, min(1, components[1]))
        let b = max(0, min(1, components[2]))
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }

    // MARK: - DTO mapping

    private static func dto(from ekEvent: EKEvent) -> EventDTO? {
        guard let identifier = ekEvent.eventIdentifier, !identifier.isEmpty else { return nil }
        return EventDTO(
            ekEventIdentifier: identifier,
            occurrenceStart: ekEvent.startDate,
            title: ekEvent.title ?? "(제목 없음)",
            start: ekEvent.startDate,
            end: ekEvent.endDate,
            isAllDay: ekEvent.isAllDay,
            notes: ekEvent.notes,
            ekCalendarIdentifier: ekEvent.calendar?.calendarIdentifier,
            recurrence: mapRecurrence(from: ekEvent),
            alarms: mapAlarms(from: ekEvent)
        )
    }

    private static func mapRecurrence(from ekEvent: EKEvent) -> EventRecurrence? {
        guard let rule = ekEvent.recurrenceRules?.first else { return nil }
        let frequency: EventRecurrenceFrequency
        switch rule.frequency {
        case .daily: frequency = .daily
        case .weekly: frequency = .weekly
        case .monthly: frequency = .monthly
        case .yearly: frequency = .yearly
        @unknown default: return nil
        }
        let end: EventRecurrenceEnd
        if let recurrenceEnd = rule.recurrenceEnd {
            if let date = recurrenceEnd.endDate {
                end = .onDate(date)
            } else if recurrenceEnd.occurrenceCount > 0 {
                end = .afterCount(recurrenceEnd.occurrenceCount)
            } else {
                end = .never
            }
        } else {
            end = .never
        }
        return EventRecurrence(
            frequency: frequency,
            interval: max(1, rule.interval),
            end: end
        )
    }

    private func applyRecurrence(_ recurrence: EventRecurrence?, to ekEvent: EKEvent) {
        if let existing = ekEvent.recurrenceRules {
            for rule in existing {
                ekEvent.removeRecurrenceRule(rule)
            }
        }
        guard let recurrence else { return }
        let frequency: EKRecurrenceFrequency
        switch recurrence.frequency {
        case .daily: frequency = .daily
        case .weekly: frequency = .weekly
        case .monthly: frequency = .monthly
        case .yearly: frequency = .yearly
        }
        let recurrenceEnd: EKRecurrenceEnd?
        switch recurrence.end {
        case .never: recurrenceEnd = nil
        case .onDate(let date): recurrenceEnd = EKRecurrenceEnd(end: date)
        case .afterCount(let count): recurrenceEnd = EKRecurrenceEnd(occurrenceCount: count)
        }
        let rule = EKRecurrenceRule(
            recurrenceWith: frequency,
            interval: max(1, recurrence.interval),
            end: recurrenceEnd
        )
        ekEvent.addRecurrenceRule(rule)
    }

    private static func mapAlarms(from ekEvent: EKEvent) -> [EventAlarm] {
        (ekEvent.alarms ?? []).map { ekAlarm in
            EventAlarm(offsetSeconds: ekAlarm.relativeOffset)
        }
    }

    private func applyAlarms(_ alarms: [EventAlarm], to ekEvent: EKEvent) {
        if let existing = ekEvent.alarms {
            for alarm in existing {
                ekEvent.removeAlarm(alarm)
            }
        }
        for alarm in alarms {
            ekEvent.addAlarm(EKAlarm(relativeOffset: alarm.offsetSeconds))
        }
    }
}
