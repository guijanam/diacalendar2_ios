//
//  AppEnvironment.swift
//  DiaCalendar2
//

import Combine
import EventKit
import Foundation
import RevenueCat
import SwiftData

extension Notification.Name {
    /// EK 변경(외부 앱에서 수정 등)이 감지된 후 0.5s 디바운스 뒤에 발송.
    /// 캘린더 화면이 이걸 받아 재로드한다.
    static let ekChangesDidPropagate = Notification.Name("DiaCalendar2.ekChangesDidPropagate")
    /// 교번근무 설정/스케줄/교체/충당 변경이 일어났을 때 발송. CalendarAggregator가 받아 재로드한다.
    static let shiftScheduleDidUpdate = Notification.Name("DiaCalendar2.shiftScheduleDidUpdate")
    /// 공휴일 목록이 sync 되어 변경되었을 때 발송. 캘린더 화면이 받아 재로드한다.
    static let holidaysDidUpdate = Notification.Name("DiaCalendar2.holidaysDidUpdate")
}

@Observable
@MainActor
final class AppEnvironment {
    let workShiftRepository: WorkShiftRepository
    let dateMemoRepository: DateMemoRepository
    let syncStateRepository: SyncStateRepository
    let eventKitSyncService: EventKitSyncService

    // 교번근무 관리 관련
    let officeRecordRepository: OfficeRecordRepository
    let diaRecordRepository: DiaRecordRepository
    let userShiftConfigRepository: UserShiftConfigRepository
    let shiftScheduleRepository: ShiftScheduleRepository
    let shiftSwapRecordRepository: ShiftSwapRecordRepository
    let shiftInputTypeRepository: ShiftInputTypeRepository
    let shiftInputRecordRepository: ShiftInputRecordRepository
    let customShiftRepository: CustomShiftRepository
    let shiftSyncService: ShiftSyncService

    // 공휴일
    let holidayRepository: HolidayRepository
    let holidaySyncService: HolidaySyncService

    // 근태 (휴가)
    let attendanceTypeRepository: AttendanceTypeRepository
    let attendanceRecordRepository: AttendanceRecordRepository

    // 앱 버전 강제 업데이트
    let appUpdateService: AppUpdateService

    // 구독 관리
    let revenueCatService: RevenueCatService

    // 음력 기념일
    let lunarAnniversaryRepository: LunarAnniversaryRepository

    // 동료근무
    let coworkerRepository: CoworkerRepository

    // 로컬 알림
    let localNotificationService: LocalNotificationService

    /// 위젯의 잠금 안내 탭(diacalendar://subscribe) 등으로 구독 페이월을 띄워야 할 때 true.
    /// ContentView가 이 값을 sheet 바인딩으로 사용한다.
    var showSubscriptionPaywall: Bool = false

    @ObservationIgnored private var ekChangeObserver: AnyCancellable?
    @ObservationIgnored private var pendingChangeWorkItem: DispatchWorkItem?
    @ObservationIgnored private var widgetRefreshObservers: [AnyCancellable] = []

    init(modelContainer: ModelContainer) {
        self.workShiftRepository = WorkShiftRepository(modelContainer: modelContainer)
        self.dateMemoRepository = DateMemoRepository(modelContainer: modelContainer)
        self.syncStateRepository = SyncStateRepository(modelContainer: modelContainer)
        self.eventKitSyncService = EventKitSyncService()

        let officeRepo = OfficeRecordRepository(modelContainer: modelContainer)
        let diaRepo = DiaRecordRepository(modelContainer: modelContainer)
        self.officeRecordRepository = officeRepo
        self.diaRecordRepository = diaRepo
        self.userShiftConfigRepository = UserShiftConfigRepository(modelContainer: modelContainer)
        self.shiftScheduleRepository = ShiftScheduleRepository(modelContainer: modelContainer)
        self.shiftSwapRecordRepository = ShiftSwapRecordRepository(modelContainer: modelContainer)
        let inputTypeRepo = ShiftInputTypeRepository(modelContainer: modelContainer)
        self.shiftInputTypeRepository = inputTypeRepo
        self.shiftInputRecordRepository = ShiftInputRecordRepository(modelContainer: modelContainer)
        self.customShiftRepository = CustomShiftRepository(modelContainer: modelContainer)
        self.shiftSyncService = ShiftSyncService(
            officeRepo: officeRepo,
            diaRepo: diaRepo,
            syncStateRepo: SyncStateRepository(modelContainer: modelContainer)
        )

        let holidayRepo = HolidayRepository(modelContainer: modelContainer)
        self.holidayRepository = holidayRepo
        let holidaySync = HolidaySyncService(
            repo: holidayRepo,
            syncStateRepo: SyncStateRepository(modelContainer: modelContainer)
        )
        self.holidaySyncService = holidaySync

        let attendanceTypeRepo = AttendanceTypeRepository(modelContainer: modelContainer)
        self.attendanceTypeRepository = attendanceTypeRepo
        self.attendanceRecordRepository = AttendanceRecordRepository(modelContainer: modelContainer)

        self.appUpdateService = AppUpdateService()

        let rcService = RevenueCatService()
        self.revenueCatService = rcService
        rcService.configure()

        self.lunarAnniversaryRepository = LunarAnniversaryRepository(modelContainer: modelContainer)

        self.coworkerRepository = CoworkerRepository(modelContainer: modelContainer)

        self.localNotificationService = LocalNotificationService()

        // 기본 충당 유형 시드
        Task { await inputTypeRepo.seedDefaultsIfNeeded() }
        // 기본 근태(휴가) 유형 시드: 연차/병가/경조사/출장
        Task { await attendanceTypeRepo.seedDefaultsIfNeeded() }
        // 공휴일은 변경 빈도가 매우 낮아 자동 fetch 하지 않는다.
        // 사용자가 Settings → "공휴일 정보 갱신"을 눌러 직접 갱신한다.
        Task { await rcService.checkSubscription() }
        Task { await rcService.checkVIP() }
        Task { await localNotificationService.requestAuthorization() }

        observeEventKitChanges()
        observeWidgetDataChanges()
        // 앱 시작 시 위젯 데이터 1회 생성.
        regenerateWidgetData()
    }

    func onForeground() {
        NotificationCenter.default.post(name: .ekChangesDidPropagate, object: nil)
        Task { await appUpdateService.checkForUpdate() }
        Task { await revenueCatService.checkSubscription() }
        Task { await revenueCatService.checkVIP() }
        // 포그라운드 복귀 시 위젯 데이터 갱신(날짜 경과·외부 변경 반영).
        regenerateWidgetData()
    }

    /// 위젯 등에서 들어온 딥링크(diacalendar://...)를 처리한다.
    func handleDeepLink(_ url: URL) {
        guard url.scheme == "diacalendar" else { return }
        switch url.host {
        case "subscribe":
            // 이미 구독/VIP면 페이월을 띄울 필요 없음.
            guard !revenueCatService.isSubscribed, !revenueCatService.isVIP else { return }
            showSubscriptionPaywall = true
        default:
            break
        }
    }

    /// 근무/공휴일 변경 알림을 받아 위젯 데이터를 재생성한다.
    private func observeWidgetDataChanges() {
        let names: [Notification.Name] = [.shiftScheduleDidUpdate, .holidaysDidUpdate, .ekChangesDidPropagate]
        widgetRefreshObservers = names.map { name in
            NotificationCenter.default
                .publisher(for: name)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in self?.regenerateWidgetData() }
        }
    }

    private func regenerateWidgetData() {
        Task { await WidgetDataGenerator.generateAndSave(using: self) }
    }

    private func observeEventKitChanges() {
        ekChangeObserver = NotificationCenter.default
            .publisher(for: .EKEventStoreChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.scheduleDebouncedReload()
            }
    }

    private func scheduleDebouncedReload() {
        pendingChangeWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            NotificationCenter.default.post(name: .ekChangesDidPropagate, object: nil)
        }
        pendingChangeWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }
}
