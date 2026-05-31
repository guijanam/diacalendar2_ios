//
//  CalendarView.swift
//  DiaCalendar2
//
//  Created by Bum Son on 5/9/26.
//

import SwiftUI
import Yotei

struct FullCalendarView: View {
    private enum Constants {
        static var weekTitlesViewInsets: EdgeInsets {
            EdgeInsets(top: 0, leading: 50, bottom: 0, trailing: 0)
        }
    }

    private let hapticFeedbackGenerator = UISelectionFeedbackGenerator()

    private let dayEventsFactory = DiaDayEventsViewFactory()
    private let allDayFactory = DiaAllDayEventsTopViewFactory()
    private let scheduleFactory = DiaScheduleViewFactory()

    private var monthFactory: DiaMonthViewFactory {
        DiaMonthViewFactory(
            holidayLookup: { [weak viewModel] in viewModel?.holidayName(on: $0) },
            shiftKey: { [weak viewModel] in viewModel?.shiftKey(for: $0) },
            calendar: viewModel.calendar
        )
    }

    private var weekdayFactory: DiaWeekdayViewFactory {
        DiaWeekdayViewFactory(
            holidayLookup: { [weak viewModel] in viewModel?.holidayName(on: $0) != nil },
            calendar: viewModel.calendar
        )
    }

    @StateObject private var viewModel: FullCalendarViewModelModel

    init(
        eventKitService: EventKitSyncService,
        localNotificationService: LocalNotificationService? = nil,
        workShiftRepository: WorkShiftRepository? = nil,
        shiftScheduleRepository: ShiftScheduleRepository? = nil,
        shiftSwapRecordRepository: ShiftSwapRecordRepository? = nil,
        shiftInputRecordRepository: ShiftInputRecordRepository? = nil,
        shiftInputTypeRepository: ShiftInputTypeRepository? = nil,
        attendanceRecordRepository: AttendanceRecordRepository? = nil,
        attendanceTypeRepository: AttendanceTypeRepository? = nil,
        userShiftConfigRepository: UserShiftConfigRepository? = nil,
        officeRecordRepository: OfficeRecordRepository? = nil,
        diaRecordRepository: DiaRecordRepository? = nil,
        holidayRepository: HolidayRepository? = nil,
        dateMemoRepository: DateMemoRepository? = nil,
        syncStateRepository: SyncStateRepository? = nil,
        lunarAnniversaryRepository: LunarAnniversaryRepository? = nil
    ) {
        _viewModel = StateObject(
            wrappedValue: FullCalendarViewModelModel(
                eventKitService: eventKitService,
                localNotificationService: localNotificationService,
                workShiftRepository: workShiftRepository,
                shiftScheduleRepository: shiftScheduleRepository,
                shiftSwapRecordRepository: shiftSwapRecordRepository,
                shiftInputRecordRepository: shiftInputRecordRepository,
                shiftInputTypeRepository: shiftInputTypeRepository,
                attendanceRecordRepository: attendanceRecordRepository,
                attendanceTypeRepository: attendanceTypeRepository,
                userShiftConfigRepository: userShiftConfigRepository,
                officeRecordRepository: officeRecordRepository,
                diaRecordRepository: diaRecordRepository,
                holidayRepository: holidayRepository,
                dateMemoRepository: dateMemoRepository,
                syncStateRepository: syncStateRepository,
                lunarAnniversaryRepository: lunarAnniversaryRepository
            )
        )
    }

    @State private var contentOffset: CGPoint?
    @State private var pendingSheet: CalendarSheet?
    @State private var isMonthPickerPresented: Bool = false
    @State private var showCoworker: Bool = false

    var body: some View {
        VStack {
            switch viewModel.viewType {
            case .schedule:
                scheduleView()
            case .day:
                dayView()
            case .week:
                weekView()
            case .month:
                monthView()
            }
        }
        .navigationDestination(isPresented: $showCoworker) {
            CoworkerView()
        }
        .fontDesign(.serif)
        .yoteiDelegate(viewModel)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                monthTitle
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCoworker = true
                } label: {
                    Image(systemName: "person.2.fill")
                }
                .accessibilityLabel("동료 근무")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.viewDidSelectToday()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .accessibilityLabel("오늘")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    presentNewEventEditor()
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("새 이벤트")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    // 뷰 타입 (서브메뉴)
                    Menu {
                        ForEach(CalendarViewType.allCases, id: \.self) { value in
                            Button(action: {
                                viewModel.viewType = value
                            }) {
                                Label {
                                    Text(value.title)
                                } icon: {
                                    value.icon
                                }
                            }
                        }
                    } label: {
                        Label("보기 방식", systemImage: "calendar")
                    }
                    // 타임존
                    Button(action: {
                        viewModel.viewDidSelectTimezoneSelector()
                    }) {
                        Label("사이트", systemImage: "globe")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .environment(\.calendar, viewModel.calendar)
        .onChange(of: viewModel.focusedDate) {
            hapticFeedbackGenerator.selectionChanged()
            viewModel.viewDidChangeFocusedDate()
        }
//        .onChange(of: viewModel.focusedDate) { _ in
//            hapticFeedbackGenerator.selectionChanged()
//            viewModel.viewDidChangeFocusedDate()
//        }
        .onAppear {
            viewModel.viewDidChangeFocusedDate()
        }
        .sheet(item: $viewModel.activeWebURL) { url in
            NavigationStack {
                WebView(url: url)
                    .ignoresSafeArea(edges: .bottom)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("닫기") {
                                viewModel.activeWebURL = nil
                            }
                        }
                    }
            }
        }
        .sheet(item: $viewModel.pendingPasswordOfficeName) { officeName in
            WebPasswordSheet(officeName: officeName) {
                viewModel.viewDidAuthenticateWebPassword(for: officeName)
            }
        }
        .sheet(item: $viewModel.presentedSheet, onDismiss: {
            if let next = pendingSheet {
                pendingSheet = nil
                DispatchQueue.main.async {
                    viewModel.presentedSheet = next
                }
            }
        }) { sheet in
            sheetContent(for: sheet)
        }
        .id(viewModel.viewID)
        // reacting on system updates
        .onReceive(NotificationCenter.default.publisher(for: NSLocale.currentLocaleDidChangeNotification)) { _ in
            viewModel.viewDidUpdateUserSettings()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemClockDidChange)) { _ in
            // TimelineView does not immediately fire updates if user sets system clock back.
            // See comments in YoteiDayEventsView
            viewModel.viewDidUpdateUserSettings()
        }
        .onReceive(NotificationCenter.default.publisher(for: .ekChangesDidPropagate)) { _ in
            viewModel.reloadEvents()
        }
        .onReceive(NotificationCenter.default.publisher(for: .shiftScheduleDidUpdate)) { _ in
            viewModel.reloadEvents()
        }
        .onReceive(NotificationCenter.default.publisher(for: .holidaysDidUpdate)) { _ in
            Task { await viewModel.loadHolidays() }
            viewModel.reloadEvents()
        }
    }

    @ViewBuilder
    private func scheduleView() -> some View {
        VStack(spacing: 0) {
            YoteiWeekdayTitlesView()
            YoteiStripContainerView(focusedDate: $viewModel.focusedDate)
            YoteiScheduleView(
                focusedDate: $viewModel.focusedDate,
                data: $viewModel.data,
                viewFactory: scheduleFactory
            )
        }
    }

    @ViewBuilder
    private func dayView() -> some View {
        VStack(spacing: 0) {
            YoteiWeekdayTitlesView()
            YoteiStripContainerView(focusedDate: $viewModel.focusedDate)
            YoteiDragEventView(
                data: $viewModel.data,
                contentOffset: $contentOffset,
                focusedDate: $viewModel.focusedDate
            ) {
                YoteiPagesDayView(
                    focusedDate: $viewModel.focusedDate
                ) { date in
                    VStack(spacing: 0) {
                        YoteiAllDayEventsTopView(
                            startDate: date,
                            numberOfDays: 1,
                            data: $viewModel.data,
                            viewFactory: allDayFactory
                        )
                        .padding(EdgeInsets(top: 0, leading: 50, bottom: 0, trailing: 6))
                        .background {
                            Text("All day")
                                .font(.system(.caption))
                                .padding(.horizontal, 4)
                                .frame(width: 50)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .clipped()
                        YoteiDayEventsView(
                            startDate: date,
                            numberOfDays: 1,
                            data: $viewModel.data,
                            contentOffset: $contentOffset,
                            viewFactory: dayEventsFactory
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func weekView() -> some View {
        VStack(spacing: 0) {
            YoteiWeekdayTitlesView()
                .padding(Constants.weekTitlesViewInsets)

            YoteiDragEventView(
                data: $viewModel.data,
                contentOffset: $contentOffset,
                focusedDate: $viewModel.focusedDate
            ) {
                YoteiPagesWeekView(
                    focusedDate: $viewModel.focusedDate
                ) { date in
                    VStack(spacing: 0) {
                        YoteiWeekdaysView(weekStartDate: date, viewFactory: weekdayFactory)
                            .padding(Constants.weekTitlesViewInsets)
                            .padding(.bottom, 4)
                        YoteiAllDayEventsTopView(
                            startDate: date,
                            numberOfDays: 7,
                            data: $viewModel.data,
                            viewFactory: allDayFactory
                        )
                        .padding(Constants.weekTitlesViewInsets)
                        YoteiDayEventsView(
                            startDate: date,
                            numberOfDays: 7,
                            data: $viewModel.data,
                            contentOffset: $contentOffset,
                            viewFactory: dayEventsFactory
                        )
                    }
                }
            }
        }
    }

    /// 상단 월 표시 + 오른쪽에 그 달의 총 휴무 갯수 배지. 탭하면 년/월 선택 시트.
    @ViewBuilder
    private var monthTitle: some View {
        let monthText = viewModel.calendar.isDate(
            viewModel.focusedDate,
            equalTo: Date(),
            toGranularity: .year
        )
            ? viewModel.focusedDate.formatted(Date.FormatStyle(
                calendar: viewModel.calendar,
                timeZone: viewModel.calendar.timeZone
            ).month(.wide))
            : viewModel.focusedDate.formatted(Date.FormatStyle(
                calendar: viewModel.calendar,
                timeZone: viewModel.calendar.timeZone
            ).month().year(.defaultDigits))

        let restColor = Color(hex: ShiftDayInfo.attendanceColorHex) ?? .red
        let hyumuColor = Color(hex: "#9C27B0") ?? .purple

        Button {
            isMonthPickerPresented = true
        } label: {
            HStack(spacing: 6) {
                HStack(spacing: 2) {
                    Text(monthText)
                        .font(.headline)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.primary)
                countBadge(text: "휴 \(viewModel.monthRestCount)", color: restColor)
                if viewModel.monthHyumuChungdangCount > 0 {
                    countBadge(text: "\(viewModel.monthHyumuChungdangCount)", color: hyumuColor)
                }
            }
            // principal 슬롯이 콘텐츠를 좁혀 "..." 로 잘리는 것을 방지: 자연 크기 유지.
            .fixedSize(horizontal: true, vertical: false)
        }
        .sheet(isPresented: $isMonthPickerPresented) {
            MonthYearPickerSheet(
                calendar: viewModel.calendar,
                selected: viewModel.focusedDate
            ) { date in
                viewModel.focusedDate = date
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    /// 월 표시 옆 갯수 배지 (휴 / 휴무충당 공통).
    @ViewBuilder
    private func countBadge(text: String, color: Color) -> some View {
        Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .lineLimit(1)
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    @ViewBuilder
    private func monthView() -> some View {
        VStack(spacing: 0) {
            YoteiWeekdayTitlesView()
            YoteiPagesMonthView(
                focusedDate: $viewModel.focusedDate
            ) { date in
                YoteiPagesMonthPageView(
                    selectedDate: $viewModel.focusedDate,
                    dateInMonth: date,
                    data: $viewModel.monthData,
                    viewFactory: monthFactory
                )
            }
        }
        .environment(\.shiftsByDate, viewModel.shiftsByDate)
    }

    private func presentNewEventEditor() {
        let calendar = viewModel.calendar
        let now = Date()
        let start: Date
        if calendar.isDateInToday(viewModel.focusedDate) {
            start = calendar.date(
                bySettingHour: calendar.component(.hour, from: now) + 1,
                minute: 0,
                second: 0,
                of: viewModel.focusedDate
            ) ?? viewModel.focusedDate
        } else {
            start = calendar.date(
                bySettingHour: 9, minute: 0, second: 0, of: viewModel.focusedDate
            ) ?? viewModel.focusedDate
        }
        let end = calendar.date(byAdding: .hour, value: 1, to: start) ?? start
        viewModel.presentedSheet = .eventEditor(.new(start: start, end: end))
    }

    @ViewBuilder
    private func sheetContent(for sheet: CalendarSheet) -> some View {
        switch sheet {
        case .eventEditor(let draft):
            EventEditorSheet(
                draft: draft,
                loadCalendars: { await viewModel.loadWritableCalendars() },
                loadDefaultCalendarIdentifier: { await viewModel.defaultCalendarIdentifierProvider() },
                onSave: { draft, scope in viewModel.saveEvent(draft, scope: scope) },
                onCancel: { viewModel.cancelDraft() }
            )
        case .eventDetail(let id):
            EventDetailSheet(
                eventIdentifier: id,
                calendar: viewModel.calendar,
                load: { await viewModel.event(with: $0) },
                onEdit: { viewModel.presentEditor(forEditing: $0) },
                onDelete: { id, scope in viewModel.deleteEvent(ekEventIdentifier: id, scope: scope) }
            )
        case .dayDetail(let date):
            DayDetailSheet(
                date: date,
                calendar: viewModel.calendar,
                events: viewModel.eventsOnDay(date),
                loadCalendars: { await viewModel.loadAvailableCalendars() },
                loadMemos: { await viewModel.memos(on: $0) },
                loadShiftInfo: { await viewModel.shiftDayInfo(on: $0) },
                holidayName: { viewModel.holidayName(on: $0) },
                onSelectEvent: { id in
                    pendingSheet = .eventDetail(id)
                    viewModel.presentedSheet = nil
                },
                onCreate: {
                    let calendar = viewModel.calendar
                    let start = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: date) ?? date
                    let end = calendar.date(byAdding: .hour, value: 1, to: start) ?? start
                    pendingSheet = .eventEditor(.new(start: start, end: end))
                    viewModel.presentedSheet = nil
                },
                onDeleteOverlay: {
                    await viewModel.deleteOverlay(on: date)
                },
                onToggleMemo: { dto in
                    Task { await viewModel.saveMemoKeepingSheet(dto) }
                },
                onDeleteMemo: { memo in
                    Task { await viewModel.deleteMemoKeepingSheet(id: memo.id) }
                },
                saveMemo: { dto in await viewModel.saveMemoKeepingSheet(dto) },
                deleteMemo: { id in await viewModel.deleteMemoKeepingSheet(id: id) },
                loadShiftOptions: { await viewModel.referenceShiftOptions() },
                loadShiftInputTypes: { await viewModel.availableShiftInputTypes() },
                isJiGeunDay: { await viewModel.isJiGeunDay($0) },
                loadAttendanceTypes: { await viewModel.availableAttendanceTypes() },
                createSwap: { targetName, days in
                    await viewModel.createSwap(on: date, swappedTo: targetName, days: days)
                },
                createShiftInput: { type, days, target in
                    await viewModel.createShiftInput(
                        on: date, type: type, days: days, targetShiftName: target
                    )
                },
                createAttendance: { type, days in
                    await viewModel.createAttendance(on: date, type: type, days: days)
                },
                createJiGeunHyu: { category, days in
                    await viewModel.createJiGeunHyu(on: date, category: category, days: days)
                },
                loadLunarAnniversaries: { await viewModel.allLunarAnniversaries() },
                loadConfiguredOfficeName: { await viewModel.configuredOfficeName() },
                loadPreviousTrainNo: { await viewModel.previousTrainNo(forMyTrainNo: $0) },
                saveLunarAnniversary: { dto in await viewModel.saveLunarAnniversary(dto) },
                deleteLunarAnniversary: { id in await viewModel.deleteLunarAnniversary(id: id) }
            )
            .paywallGate(.dayDetailUsageLimited)
        case .allDay(let date):
            AllDayListSheet(
                date: date,
                calendar: viewModel.calendar,
                events: viewModel.allDayEventsOnDay(date),
                onSelectEvent: { id in
                    viewModel.presentedSheet = .eventDetail(id)
                }
            )
        case .memoEditor(let mode):
            MemoEditorSheet(
                mode: mode,
                calendar: viewModel.calendar,
                onSave: { dto in viewModel.saveMemo(dto) },
                onDelete: { id in viewModel.deleteMemo(id: id) }
            )
        case .shiftSwap(let date):
            ShiftSwapSheet(
                date: date,
                loadOptions: { await viewModel.referenceShiftOptions() },
                onConfirm: { targetName, days in
                    Task { await viewModel.createSwap(on: date, swappedTo: targetName, days: days) }
                    viewModel.presentedSheet = nil
                }
            )
        case .shiftInput(let date):
            ShiftInputSheet(
                date: date,
                loadTypes: { await viewModel.availableShiftInputTypes() },
                loadOptions: { await viewModel.referenceShiftOptions() },
                isJiGeunDay: { await viewModel.isJiGeunDay($0) },
                onConfirm: { type, days, target in
                    Task {
                        await viewModel.createShiftInput(
                            on: date, type: type, days: days, targetShiftName: target
                        )
                    }
                    viewModel.presentedSheet = nil
                }
            )
        case .attendance(let date):
            AttendanceSheet(
                date: date,
                loadTypes: { await viewModel.availableAttendanceTypes() },
                onConfirm: { type, days in
                    Task { await viewModel.createAttendance(on: date, type: type, days: days) }
                    viewModel.presentedSheet = nil
                }
            )
        }
    }
}
