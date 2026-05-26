//
//  EventEditorSheet.swift
//  DiaCalendar2
//

import SwiftUI

struct EventEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let initialDraft: EventDraft
    let loadCalendars: () async -> [EKCalendarInfo]
    let loadDefaultCalendarIdentifier: () async -> String?
    let onSave: (EventDraft, EventEditScope) -> Void
    let onCancel: () -> Void

    @State private var title: String
    @State private var start: Date
    @State private var end: Date
    @State private var isAllDay: Bool
    @State private var notes: String
    @State private var ekCalendarIdentifier: String?
    @State private var availableCalendars: [EKCalendarInfo] = []
    @State private var didApplyDefault = false

    @State private var recurrenceEnabled: Bool
    @State private var recurrenceFrequency: EventRecurrenceFrequency
    @State private var recurrenceInterval: Int
    @State private var recurrenceEndKind: RecurrenceEndKind
    @State private var recurrenceEndDate: Date
    @State private var recurrenceOccurrenceCount: Int

    @State private var alarms: [EventAlarm]
    @State private var showAddAlarmSheet = false
    @State private var showSpanAlert = false
    @State private var pendingDraft: EventDraft?

    private enum RecurrenceEndKind: String, CaseIterable, Identifiable {
        case never
        case onDate
        case afterCount

        var id: String { rawValue }
        var title: String {
            switch self {
            case .never: return "계속"
            case .onDate: return "특정 날짜"
            case .afterCount: return "횟수"
            }
        }
    }

    private let isEditing: Bool

    init(
        draft: EventDraft,
        loadCalendars: @escaping () async -> [EKCalendarInfo],
        loadDefaultCalendarIdentifier: @escaping () async -> String?,
        onSave: @escaping (EventDraft, EventEditScope) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.initialDraft = draft
        self.loadCalendars = loadCalendars
        self.loadDefaultCalendarIdentifier = loadDefaultCalendarIdentifier
        self.onSave = onSave
        self.onCancel = onCancel
        self._title = State(initialValue: draft.title)
        self._start = State(initialValue: draft.start)
        self._end = State(initialValue: draft.end)
        self._isAllDay = State(initialValue: draft.isAllDay)
        self._notes = State(initialValue: draft.notes ?? "")
        self._ekCalendarIdentifier = State(initialValue: draft.ekCalendarIdentifier)
        self.isEditing = draft.ekEventIdentifier != nil

        let recurrence = draft.recurrence
        self._recurrenceEnabled = State(initialValue: recurrence != nil)
        self._recurrenceFrequency = State(initialValue: recurrence?.frequency ?? .weekly)
        self._recurrenceInterval = State(initialValue: recurrence?.interval ?? 1)
        switch recurrence?.end ?? .never {
        case .never:
            self._recurrenceEndKind = State(initialValue: .never)
            self._recurrenceEndDate = State(
                initialValue: Calendar.current.date(byAdding: .month, value: 1, to: draft.start) ?? draft.start
            )
            self._recurrenceOccurrenceCount = State(initialValue: 10)
        case .onDate(let date):
            self._recurrenceEndKind = State(initialValue: .onDate)
            self._recurrenceEndDate = State(initialValue: date)
            self._recurrenceOccurrenceCount = State(initialValue: 10)
        case .afterCount(let count):
            self._recurrenceEndKind = State(initialValue: .afterCount)
            self._recurrenceEndDate = State(
                initialValue: Calendar.current.date(byAdding: .month, value: 1, to: draft.start) ?? draft.start
            )
            self._recurrenceOccurrenceCount = State(initialValue: count)
        }

        self._alarms = State(initialValue: draft.alarms)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("제목") {
                    TextField("이벤트 제목", text: $title)
                }

                Section("시간") {
                    Toggle("종일", isOn: $isAllDay)
                    DatePicker(
                        "시작",
                        selection: $start,
                        displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute]
                    )
                    DatePicker(
                        "종료",
                        selection: $end,
                        displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute]
                    )
                }

                recurrenceSection

                alarmsSection

                if !availableCalendars.isEmpty {
                    Section {
                        Picker("캘린더", selection: $ekCalendarIdentifier) {
                            HStack {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 12, height: 12)
                                Text("자동 (기본 캘린더)")
                            }
                            .tag(String?.none)

                            ForEach(availableCalendars) { calendar in
                                HStack {
                                    Circle()
                                        .fill(Color(hex: calendar.colorHex ?? "") ?? .gray)
                                        .frame(width: 12, height: 12)
                                    Text(calendar.title)
                                }
                                .tag(String?.some(calendar.identifier))
                            }
                        }
                    } header: {
                        Text("동기화 캘린더")
                    } footer: {
                        Text("이벤트는 선택한 캘린더의 색으로 표시됩니다.")
                    }
                }

                Section("메모") {
                    TextField("메모 (선택)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(isEditing ? "이벤트 편집" : "새 이벤트")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        save()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .task {
                availableCalendars = await loadCalendars()
                if !didApplyDefault, !isEditing, ekCalendarIdentifier == nil {
                    ekCalendarIdentifier = await loadDefaultCalendarIdentifier()
                    didApplyDefault = true
                }
            }
            .sheet(isPresented: $showAddAlarmSheet) {
                AlarmPresetPickerSheet { preset in
                    alarms.append(EventAlarm(offsetSeconds: preset.offsetSeconds))
                }
            }
            .alert("반복 이벤트 수정", isPresented: $showSpanAlert) {
                Button("이 이벤트만 수정") {
                    if let pendingDraft {
                        onSave(pendingDraft, .thisEvent)
                    }
                    pendingDraft = nil
                }
                Button("향후 모든 이벤트 수정") {
                    if let pendingDraft {
                        onSave(pendingDraft, .futureEvents)
                    }
                    pendingDraft = nil
                }
                Button("취소", role: .cancel) {
                    pendingDraft = nil
                }
            } message: {
                Text("이 변경사항을 어디에 적용할까요?")
            }
        }
    }

    @ViewBuilder
    private var recurrenceSection: some View {
        Section("반복") {
            Toggle("반복", isOn: $recurrenceEnabled)
            if recurrenceEnabled {
                Picker("주기", selection: $recurrenceFrequency) {
                    ForEach(EventRecurrenceFrequency.allCases, id: \.self) { freq in
                        Text(freq.title).tag(freq)
                    }
                }
                Stepper("간격: \(recurrenceInterval)", value: $recurrenceInterval, in: 1...99)
                Picker("종료", selection: $recurrenceEndKind) {
                    ForEach(RecurrenceEndKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                if recurrenceEndKind == .onDate {
                    DatePicker(
                        "종료일",
                        selection: $recurrenceEndDate,
                        displayedComponents: [.date]
                    )
                } else if recurrenceEndKind == .afterCount {
                    Stepper("\(recurrenceOccurrenceCount)회", value: $recurrenceOccurrenceCount, in: 1...365)
                }
            }
        }
    }

    @ViewBuilder
    private var alarmsSection: some View {
        Section("알림") {
            if alarms.isEmpty {
                Text("알림 없음")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(alarms) { alarm in
                    Text(alarm.summary)
                }
                .onDelete { indexSet in
                    alarms.remove(atOffsets: indexSet)
                }
            }
            Button {
                showAddAlarmSheet = true
            } label: {
                Label("알림 추가", systemImage: "bell.badge.plus")
            }
        }
    }

    private func save() {
        var draft = initialDraft
        draft.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.start = start
        draft.end = max(end, start)
        draft.isAllDay = isAllDay
        draft.notes = notes.isEmpty ? nil : notes
        draft.ekCalendarIdentifier = ekCalendarIdentifier
        draft.recurrence = recurrenceEnabled ? buildRecurrence() : nil
        draft.alarms = alarms

        // 편집 모드 + 기존 또는 변경 후가 반복 이벤트라면 사용자에게 적용 범위 확인.
        let wasRecurring = initialDraft.recurrence != nil
        let willBeRecurring = draft.recurrence != nil
        if isEditing && (wasRecurring || willBeRecurring) {
            pendingDraft = draft
            showSpanAlert = true
        } else {
            onSave(draft, .thisEvent)
        }
    }

    private func buildRecurrence() -> EventRecurrence {
        let end: EventRecurrenceEnd
        switch recurrenceEndKind {
        case .never: end = .never
        case .onDate: end = .onDate(recurrenceEndDate)
        case .afterCount: end = .afterCount(recurrenceOccurrenceCount)
        }
        return EventRecurrence(
            frequency: recurrenceFrequency,
            interval: recurrenceInterval,
            end: end
        )
    }
}

private struct AlarmPresetPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (EventAlarmPreset) -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(EventAlarmPreset.allCases, id: \.self) { preset in
                    Button {
                        onSelect(preset)
                        dismiss()
                    } label: {
                        Text(preset.title)
                            .foregroundStyle(.primary)
                    }
                }
            }
            .navigationTitle("알림 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
            }
        }
    }
}
