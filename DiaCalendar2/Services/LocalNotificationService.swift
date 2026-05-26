//
//  LocalNotificationService.swift
//  DiaCalendar2
//

import Foundation
import UserNotifications

actor LocalNotificationService {

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let current = await center.notificationSettings()
        if current.authorizationStatus == .authorized || current.authorizationStatus == .provisional {
            return true
        }
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    // MARK: - Schedule

    /// 이벤트의 알림을 스케줄링한다. 과거 시각 알림은 무시한다.
    func scheduleAlarms(for draft: EventDraft, ekEventIdentifier: String) async {
        guard !draft.alarms.isEmpty else { return }
        let status = await authorizationStatus()
        guard status == .authorized || status == .provisional else { return }

        let center = UNUserNotificationCenter.current()
        for alarm in draft.alarms {
            let fireDate = draft.start.addingTimeInterval(alarm.offsetSeconds)
            guard fireDate > Date() else { continue }

            let content = UNMutableNotificationContent()
            content.title = draft.title.isEmpty ? "이벤트" : draft.title
            content.body = alarmBody(eventStart: draft.start, offsetSeconds: alarm.offsetSeconds)
            content.sound = .default

            var components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: fireDate
            )
            components.second = components.second ?? 0

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let requestId = notificationId(ekEventIdentifier: ekEventIdentifier, alarmId: alarm.id)
            let request = UNNotificationRequest(identifier: requestId, content: content, trigger: trigger)

            try? await center.add(request)
        }
    }

    /// 이벤트에 연결된 모든 로컬 알림을 제거한다.
    func cancelAlarms(for ekEventIdentifier: String) {
        let center = UNUserNotificationCenter.current()
        // pending 알림 중 해당 이벤트 prefix를 가진 것을 모두 제거
        Task {
            let pending = await center.pendingNotificationRequests()
            let prefix = notificationPrefix(ekEventIdentifier: ekEventIdentifier)
            let ids = pending
                .map(\.identifier)
                .filter { $0.hasPrefix(prefix) }
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    // MARK: - Private

    private func notificationPrefix(ekEventIdentifier: String) -> String {
        "dia.\(ekEventIdentifier)."
    }

    private func notificationId(ekEventIdentifier: String, alarmId: UUID) -> String {
        "\(notificationPrefix(ekEventIdentifier: ekEventIdentifier))\(alarmId.uuidString)"
    }

    private func alarmBody(eventStart: Date, offsetSeconds: TimeInterval) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        let timeStr = formatter.string(from: eventStart)

        if offsetSeconds == 0 {
            return "지금 시작합니다 (\(timeStr))"
        }
        let absSeconds = Int(abs(offsetSeconds))
        if absSeconds % 86_400 == 0 {
            return "\(absSeconds / 86_400)일 후 시작 (\(timeStr))"
        }
        if absSeconds % 3_600 == 0 {
            return "\(absSeconds / 3_600)시간 후 시작 (\(timeStr))"
        }
        if absSeconds % 60 == 0 {
            return "\(absSeconds / 60)분 후 시작 (\(timeStr))"
        }
        return "\(timeStr)에 시작"
    }
}
