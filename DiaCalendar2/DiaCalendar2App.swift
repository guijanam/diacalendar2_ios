//
//  DiaCalendar2App.swift
//  DiaCalendar2
//
//  Created by Bum Son on 5/8/26.
//

import SwiftData
import SwiftUI
import UserNotifications

@main
struct DiaCalendar2App: App {

    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppearanceMode.storageKey) private var appearanceRaw: String = AppearanceMode.system.rawValue

    private let modelContainer: ModelContainer
    @State private var environment: AppEnvironment
    private let notificationDelegate = AppNotificationDelegate()

    init() {
        UNUserNotificationCenter.current().delegate = notificationDelegate
        
        
        
        let schema = Schema([
            WorkShift.self,
            DateMemo.self,
            SyncState.self,
            OfficeRecord.self,
            DiaRecord.self,
            UserShiftConfig.self,
            ShiftSchedule.self,
            ShiftSwapRecord.self,
            ShiftInputType.self,
            ShiftInputRecord.self,
            CustomShift.self,
            HolidayRecord.self,
            AttendanceType.self,
            AttendanceRecord.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            self.modelContainer = container
            self._environment = State(wrappedValue: AppEnvironment(modelContainer: container))
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(environment)
                .preferredColorScheme(AppearanceMode(rawValue: appearanceRaw)?.colorScheme)
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                environment.onForeground()
            }
        }
    }
}

// 앱 포그라운드 상태에서도 알림 배너가 표시되도록 한다.
final class AppNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
