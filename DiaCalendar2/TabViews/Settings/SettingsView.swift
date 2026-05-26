//
//  SettingsView.swift
//  DiaCalendar2
//

import SwiftUI

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var appEnvironment

    @State private var ekStatus: EventKitSyncService.AuthorizationStatus = .notDetermined
    @State private var isTimezoneSelectorActive = false
    @State private var isDefaultCalendarPickerActive = false
    @State private var isVisibleCalendarsActive = false
    @State private var timezoneIdentifier: String = TimeZone.current.identifier
    @State private var defaultCalendarIdentifier: String?
    @State private var defaultCalendarTitle: String?
    @State private var visibleCalendarIdentifiers: Set<String> = []
    @State private var visibleCalendarsSummary: String = "전체"
    @State private var currentShiftConfig: UserShiftConfigDTO?
    @State private var isHolidayRefreshing = false
    @State private var holidayLastSyncAt: Date?
    @State private var holidayStatusMessage: String?
    @State private var holidayStatusIsError = false
    @State private var isCalendarRefreshing = false
    @State private var showPaywall = false
    @State private var didCopyDeviceID: Bool = false
    @State private var isVIPRefreshing: Bool = false
    @State private var vipRefreshResult: Bool? = nil

    @AppStorage(AppearanceMode.storageKey) private var appearanceRaw: String = AppearanceMode.system.rawValue
    @AppStorage(MonthFontScale.dateStorageKey) private var dateFontScale: Double = MonthFontScale.defaultScale
    @AppStorage(MonthFontScale.shiftStorageKey) private var shiftFontScale: Double = MonthFontScale.defaultScale
    @AppStorage(MonthFontScale.eventStorageKey) private var eventFontScale: Double = MonthFontScale.defaultScale
    @AppStorage(MonthFontScale.memoStorageKey) private var memoFontScale: Double = MonthFontScale.defaultScale

    var body: some View {
        NavigationStack {
            Form {
                Section("근무 설정") {
                    NavigationLink {
                        ShiftSetupView()
                    } label: {
                        HStack {
                            Label("근무 생성", systemImage: "square.grid.3x3.middleleft.filled")
                            Spacer()
                            Text(shiftConfigSummary)
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                    NavigationLink {
                        CustomShiftListView()
                    } label: {
                        Label("교대근무 편집", systemImage: "arrow.triangle.2.circlepath")
                    }
                    NavigationLink {
                        AttendanceTypeListView()
                    } label: {
                        Label("근태 편집", systemImage: "tag")
                    }
                }

                Section {
                    Button {
                        Task { await refreshHolidays() }
                    } label: {
                        HStack {
                            Label("공휴일 정보 갱신", systemImage: "calendar.badge.exclamationmark")
                            Spacer()
                            if isHolidayRefreshing {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isHolidayRefreshing)

                    if let msg = holidayStatusMessage {
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(holidayStatusIsError ? .red : .secondary)
                    } else if let last = holidayLastSyncAt {
                        Text("마지막 갱신: \(holidaySyncFormatter.string(from: last))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("아직 갱신된 적이 없습니다.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("공휴일")
                } footer: {
                    Text("대한민국 공휴일 목록을 받아 달력에 빨간색으로 표시합니다.")
                }

                Section("동기화") {
                    HStack {
                        Label("시스템 캘린더", systemImage: "calendar")
                        Spacer()
                        Text(ekStatusLabel)
                            .foregroundStyle(.secondary)
                    }

                    if ekStatus == .notDetermined {
                        Button("접근 권한 요청") {
                            Task { await requestEKAccess() }
                        }
                    } else if ekStatus == .denied || ekStatus == .restricted {
                        Text("설정 앱에서 캘린더 접근을 허용해주세요.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if ekStatus == .authorized {
                        Button {
                            isVisibleCalendarsActive = true
                        } label: {
                            HStack {
                                Text("표시할 캘린더")
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text(visibleCalendarsSummary)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Button {
                            isDefaultCalendarPickerActive = true
                        } label: {
                            HStack {
                                Text("새 이벤트 저장 위치")
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text(defaultCalendarTitle ?? "자동")
                                    .foregroundStyle(.secondary)
                            }
                        }
//                        Button("지금 새로 고침") {
//                            NotificationCenter.default.post(name: .ekChangesDidPropagate, object: nil)
//                        }
                        
                        Button {
                                    Task { await refreshCalendarWithIndicator() }
                                } label: {
                                    HStack {
                                        Text("지금 새로 고침")
                                            .foregroundStyle(isCalendarRefreshing ? .secondary : .primary)
                                        Spacer()
                                        if isCalendarRefreshing {
                                            ProgressView()
                                        }
                                    }
                                }
                                .disabled(isCalendarRefreshing) // 로딩 중 클릭 방지
                    }

                
                }

                

                Section("테마") {
                    Picker("외관", selection: $appearanceRaw) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.displayName).tag(mode.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                Section {
                    monthFontScaleSlider(title: "날짜", value: $dateFontScale)
                    monthFontScaleSlider(title: "근무", value: $shiftFontScale)
                    monthFontScaleSlider(title: "이벤트", value: $eventFontScale)
                    monthFontScaleSlider(title: "메모", value: $memoFontScale)
                    Button("기본값") {
                        dateFontScale = MonthFontScale.defaultScale
                        shiftFontScale = MonthFontScale.defaultScale
                        eventFontScale = MonthFontScale.defaultScale
                        memoFontScale = MonthFontScale.defaultScale
                    }
                    .font(.caption)
                } header: {
                    Text("월간달력 글자 크기")
                } footer: {
                    Text("월간달력 셀에 표시되는 날짜·근무·이벤트·메모의 글자 크기를 각각 조절합니다. 다른 화면은 영향 받지 않습니다.")
                }
                
                
                Section("구독") {
                    if appEnvironment.revenueCatService.isSubscribed {
                        Label("프리미엄 이용 중", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button {
                            showPaywall = true
                        } label: {
                            Label("프리미엄 구독하기", systemImage: "crown")
                        }
                    }
                    Button("구매 복원") {
                        Task { await appEnvironment.revenueCatService.restore() }
                    }
                    .disabled(appEnvironment.revenueCatService.isLoading)
                    if let error = appEnvironment.revenueCatService.restoreError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                
                Section("시간대") {
                    Button {
                        isTimezoneSelectorActive = true
                    } label: {
                        HStack {
                            Text("기본 시간대")
                            Spacer()
                            Text(timezoneIdentifier)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                
                Section("정보") {
                    LabeledContent(
                        "버전",
                        value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
                    )

                    Button {
                        UIPasteboard.general.string = deviceID
                        didCopyDeviceID = true
                        Task {
                            try? await Task.sleep(nanoseconds: 2_000_000_000)
                            didCopyDeviceID = false
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("기기 ID")
                                    .foregroundStyle(.primary)
                                Text(deviceID)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer()
                            Label(didCopyDeviceID ? "복사됨" : "복사하기",
                                  systemImage: didCopyDeviceID ? "checkmark" : "doc.on.doc")
                                .font(.caption)
                                .foregroundStyle(didCopyDeviceID ? .green : .accentColor)
                        }
                    }

                    if appEnvironment.revenueCatService.isVIP {
                        Button {
                            guard !isVIPRefreshing else { return }
                            isVIPRefreshing = true
                            vipRefreshResult = nil
                            Task {
                                await appEnvironment.revenueCatService.refreshVIP()
                                vipRefreshResult = appEnvironment.revenueCatService.isVIP
                                isVIPRefreshing = false
                                try? await Task.sleep(nanoseconds: 3_000_000_000)
                                vipRefreshResult = nil
                            }
                        } label: {
                            HStack {
                                Text("VIP 상태 갱신")
                                    .foregroundStyle(.primary)
                                Spacer()
                                if isVIPRefreshing {
                                    ProgressView()
                                } else if let result = vipRefreshResult {
                                    Label(result ? "VIP 확인됨" : "VIP 아님",
                                          systemImage: result ? "checkmark.seal.fill" : "xmark.seal")
                                        .font(.caption)
                                        .foregroundStyle(result ? .green : .red)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                        .foregroundStyle(.accentColor)
                                }
                            }
                        }
                    }

                    NavigationLink("오픈소스 라이선스") {
                        OpenSourceLicensesView()
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $isTimezoneSelectorActive) {
                TimezoneSelectorView(timezone: Binding<String?>(
                    get: { timezoneIdentifier },
                    set: { newValue in
                        if let newValue { timezoneIdentifier = newValue }
                        isTimezoneSelectorActive = false
                    }
                ))
            }
            .sheet(isPresented: $isDefaultCalendarPickerActive) {
                CalendarPickerSheet(
                    load: { await appEnvironment.eventKitSyncService.writableCalendars() },
                    initialSelection: defaultCalendarIdentifier,
                    onSelect: { selected in
                        Task { await saveDefaultCalendar(selected) }
                    }
                )
            }
            .sheet(isPresented: $isVisibleCalendarsActive) {
                VisibleCalendarsSheet(
                    load: { await appEnvironment.eventKitSyncService.readableCalendars() },
                    initialSelection: visibleCalendarIdentifiers,
                    onSave: { selected in
                        Task { await saveVisibleCalendars(selected) }
                    }
                )
            }
            .task {
                migrateLegacyMonthFontScaleIfNeeded()
                await refreshState()
            }
            .sheet(isPresented: $showPaywall) {
                CustomPaywallView()
            }
        }
    }

    @ViewBuilder
    private func monthFontScaleSlider(title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: "%.0f%%", value.wrappedValue * 100))
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .monospacedDigit()
            }
            Slider(
                value: value,
                in: MonthFontScale.minScale ... MonthFontScale.maxScale,
                step: 0.05
            ) {
                Text(title)
            } minimumValueLabel: {
                Text("가").font(.caption)
            } maximumValueLabel: {
                Text("가").font(.title3)
            }
        }
    }

    /// 단일 `monthFontScale` 키만 사용하던 이전 버전에서 4분할 키 체계로 옮길 때
    /// 사용자가 조절했던 배율 감각을 보존하기 위해 한 번만 마이그레이션한다.
    private func migrateLegacyMonthFontScaleIfNeeded() {
        let defaults = UserDefaults.standard
        guard let legacy = defaults.object(forKey: MonthFontScale.storageKey) as? Double else { return }
        let keys = [
            MonthFontScale.dateStorageKey,
            MonthFontScale.shiftStorageKey,
            MonthFontScale.eventStorageKey,
            MonthFontScale.memoStorageKey,
        ]
        for key in keys where defaults.object(forKey: key) == nil {
            defaults.set(legacy, forKey: key)
        }
        defaults.removeObject(forKey: MonthFontScale.storageKey)
    }

    private var deviceID: String {
        UIDevice.current.identifierForVendor?.uuidString ?? "확인 불가"
    }

    private var shiftConfigSummary: String {
        guard let cfg = currentShiftConfig else { return "미설정" }
        if cfg.isCustomShift {
            return cfg.officeName
        }
        return "\(cfg.officeName) · \(cfg.position.displayName)"
    }

    private var ekStatusLabel: String {
        switch ekStatus {
        case .notDetermined: return "허용 필요"
        case .denied: return "거부됨"
        case .restricted: return "제한됨"
        case .authorized: return "허용됨"
        case .writeOnly: return "쓰기 전용"
        }
    }

    private var holidaySyncFormatter: DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy.MM.dd HH:mm"
        return f
    }

    private func refreshState() async {
        ekStatus = await appEnvironment.eventKitSyncService.currentAuthorizationStatus()
        defaultCalendarIdentifier = await appEnvironment.syncStateRepository.defaultEKCalendarIdentifier()
        visibleCalendarIdentifiers = await appEnvironment.syncStateRepository.visibleCalendarIdentifiers()
        currentShiftConfig = await appEnvironment.userShiftConfigRepository.load()
        holidayLastSyncAt = await appEnvironment.syncStateRepository.lastHolidaySyncAt()
        await refreshCalendarLabels()
    }

    private func refreshHolidays() async {
        isHolidayRefreshing = true
        holidayStatusMessage = nil
        holidayStatusIsError = false
        defer { isHolidayRefreshing = false }

        let result = await appEnvironment.holidaySyncService.refresh()
        switch result {
        case .success(let count):
            holidayStatusIsError = false
            holidayStatusMessage = "공휴일 \(count)개를 받아왔습니다."
            holidayLastSyncAt = await appEnvironment.syncStateRepository.lastHolidaySyncAt()
        case .failure(let message):
            holidayStatusIsError = true
            holidayStatusMessage = "갱신 실패: \(message)"
        }
    }

    private func refreshCalendarLabels() async {
        guard ekStatus == .authorized else {
            defaultCalendarTitle = nil
            visibleCalendarsSummary = "전체"
            return
        }
        let readable = await appEnvironment.eventKitSyncService.readableCalendars()
        let writable = await appEnvironment.eventKitSyncService.writableCalendars()

        defaultCalendarTitle = defaultCalendarIdentifier
            .flatMap { id in writable.first(where: { $0.identifier == id })?.title }

        if visibleCalendarIdentifiers.isEmpty {
            visibleCalendarsSummary = "전체"
        } else if visibleCalendarIdentifiers.count == 1,
                  let onlyId = visibleCalendarIdentifiers.first,
                  let title = readable.first(where: { $0.identifier == onlyId })?.title {
            visibleCalendarsSummary = title
        } else {
            visibleCalendarsSummary = "\(visibleCalendarIdentifiers.count)개 선택"
        }
    }

    private func requestEKAccess() async {
        ekStatus = await appEnvironment.eventKitSyncService.requestAccess()
        await refreshCalendarLabels()
        if ekStatus == .authorized {
            NotificationCenter.default.post(name: .ekChangesDidPropagate, object: nil)
        }
    }

    private func saveDefaultCalendar(_ identifier: String?) async {
        await appEnvironment.syncStateRepository.setDefaultEKCalendarIdentifier(identifier)
        defaultCalendarIdentifier = identifier
        await refreshCalendarLabels()
    }

    private func saveVisibleCalendars(_ identifiers: Set<String>) async {
        await appEnvironment.syncStateRepository.setVisibleCalendarIdentifiers(identifiers)
        visibleCalendarIdentifiers = identifiers
        await refreshCalendarLabels()
        NotificationCenter.default.post(name: .ekChangesDidPropagate, object: nil)
    }
    
    // 2. 새로운 비동기 함수 추가 (private func 영역)
    private func refreshCalendarWithIndicator() async {
        isCalendarRefreshing = true // 로딩 시작
        
        // 알림 전송 (연동된 캘린더 데이터 갱신 트리거)
        NotificationCenter.default.post(name: .ekChangesDidPropagate, object: nil)
        
        // 팁: 알림 전송은 즉시 끝나지만, 시각적인 피드백을 위해 0.5~1초 정도 대기 시간을 줄 수 있습니다.
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5초 대기
        
        isCalendarRefreshing = false // 로딩 종료
    }
}
