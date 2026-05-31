//
//  ContentView.swift
//  DiaCalendar2
//
//  Created by Bum Son on 5/8/26.
//

import SwiftData
import SwiftUI

/// Tab Items
enum AppTab: AnimatedTabSelectionProtocol {
    case home
    case diatable
    case myinfomation
    case settings

    var symbolImage: String {
        switch self {
        case .home: return "calendar"
        case .diatable: return "lightrail.fill"
        case .myinfomation: return "tray"
        case .settings: return "gearshape.fill"
        }
    }
    var title: String {
        switch self {
        case .home: return "달력"
        case .diatable: return "근무표"
        case .myinfomation: return "내정보"
        case .settings: return "설정"
        }
    }
}

struct ContentView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    
    
    @State private var activeTab: AppTab = .home

    var body: some View {
        ZStack {
            AnimatedTabView(selection: $activeTab) {
                Tab.init(AppTab.home.title, systemImage: AppTab.home.symbolImage, value: .home) {
                    NavigationStack {
                        FullCalendarView(
                            eventKitService: appEnvironment.eventKitSyncService,
                            localNotificationService: appEnvironment.localNotificationService,
                            workShiftRepository: appEnvironment.workShiftRepository,
                            shiftScheduleRepository: appEnvironment.shiftScheduleRepository,
                            shiftSwapRecordRepository: appEnvironment.shiftSwapRecordRepository,
                            shiftInputRecordRepository: appEnvironment.shiftInputRecordRepository,
                            shiftInputTypeRepository: appEnvironment.shiftInputTypeRepository,
                            attendanceRecordRepository: appEnvironment.attendanceRecordRepository,
                            attendanceTypeRepository: appEnvironment.attendanceTypeRepository,
                            userShiftConfigRepository: appEnvironment.userShiftConfigRepository,
                            officeRecordRepository: appEnvironment.officeRecordRepository,
                            diaRecordRepository: appEnvironment.diaRecordRepository,
                            holidayRepository: appEnvironment.holidayRepository,
                            dateMemoRepository: appEnvironment.dateMemoRepository,
                            syncStateRepository: appEnvironment.syncStateRepository,
                            lunarAnniversaryRepository: appEnvironment.lunarAnniversaryRepository
                        )
                    }
                }
                
                Tab.init(AppTab.diatable.title, systemImage: AppTab.diatable.symbolImage, value: .diatable) {
                    DiaTableView()
                }

                Tab.init(AppTab.myinfomation.title, systemImage: AppTab.myinfomation.symbolImage, value: .myinfomation) {
                    MyInfomationView()
                }

                Tab.init(AppTab.settings.title, systemImage: AppTab.settings.symbolImage, value: .settings) {
                    SettingsView()
                }
            } effects: { tab in
                switch tab {
                case .home: [.bounce.up]
                case .diatable: [.breathe]
                case .myinfomation: [.wiggle]
                case .settings: [.rotate]
                }
            }

            if appEnvironment.appUpdateService.isUpdateRequired {
                ForceUpdateView(storeURL: appEnvironment.appUpdateService.storeURL)
                    .zIndex(999)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: appEnvironment.appUpdateService.isUpdateRequired)
        .paywallGate(.usageLimited)
        .sheet(isPresented: subscriptionPaywallBinding) {
            CustomPaywallView()
        }
    }

    /// 위젯 잠금 탭(diacalendar://subscribe)으로 띄우는 구독 페이월 바인딩.
    private var subscriptionPaywallBinding: Binding<Bool> {
        Binding(
            get: { appEnvironment.showSubscriptionPaywall },
            set: { appEnvironment.showSubscriptionPaywall = $0 }
        )
    }
}

#Preview {
    let schema = Schema([
        WorkShift.self, DateMemo.self, SyncState.self,
        OfficeRecord.self, DiaRecord.self,
        UserShiftConfig.self, ShiftSchedule.self,
        ShiftSwapRecord.self, ShiftInputType.self, ShiftInputRecord.self,
        CustomShift.self,
        HolidayRecord.self,
        AttendanceType.self,
        AttendanceRecord.self,
        Coworker.self,
        CoworkerGroup.self,
    ])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [configuration])
    return ContentView()
        .environment(AppEnvironment(modelContainer: container))
        .modelContainer(container)
}
