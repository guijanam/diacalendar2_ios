//
//  VisibleCalendarsSheet.swift
//  DiaCalendar2
//

import SwiftUI

struct VisibleCalendarsSheet: View {
    @Environment(\.dismiss) private var dismiss

    let load: () async -> [EKCalendarInfo]
    let initialSelection: Set<String>
    let onSave: (Set<String>) -> Void

    @State private var calendars: [EKCalendarInfo] = []
    @State private var selection: Set<String>
    @State private var isLoading = true

    init(
        load: @escaping () async -> [EKCalendarInfo],
        initialSelection: Set<String>,
        onSave: @escaping (Set<String>) -> Void
    ) {
        self.load = load
        self.initialSelection = initialSelection
        self.onSave = onSave
        self._selection = State(initialValue: initialSelection)
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if calendars.isEmpty {
                    ContentUnavailableView(
                        "쓸 수 있는 캘린더가 없습니다",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("시스템 캘린더 접근 권한이 허용되어 있는지 확인해주세요.")
                    )
                } else {
                    List {
                        ForEach(groupedCalendars, id: \.title) { group in
                            Section {
                                ForEach(group.calendars) { calendar in
                                    Button {
                                        toggle(calendar.identifier)
                                    } label: {
                                        row(for: calendar)
                                    }
                                    .buttonStyle(.plain)
                                }
                            } header: {
                                HStack {
                                    Text(group.title)
                                    Spacer()
                                    Button(allInGroupSelected(group) ? "모두 해제" : "모두 선택") {
                                        toggleAll(in: group)
                                    }
                                    .font(.caption)
                                    .textCase(nil)
                                }
                            }
                        }

                        Section {
                            EmptyView()
                        } footer: {
                            Text("선택한 캘린더의 이벤트만 화면에 표시됩니다. 아무것도 선택하지 않으면 시스템 캘린더 이벤트는 표시되지 않습니다.")
                        }
                    }
                }
            }
            .navigationTitle("표시할 캘린더")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        onSave(selection)
                        dismiss()
                    }
                    .disabled(isLoading)
                }
            }
            .task {
                calendars = await load()
                isLoading = false
            }
        }
    }

    @ViewBuilder
    private func row(for calendar: EKCalendarInfo) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: calendar.colorHex ?? "") ?? .gray)
                .frame(width: 12, height: 12)
            Text(calendar.title)
                .foregroundStyle(.primary)
            Spacer()
            if selection.contains(calendar.identifier) {
                Image(systemName: "checkmark")
                    .foregroundStyle(.tint)
            }
        }
    }

    private struct CalendarGroup: Equatable {
        let title: String
        let calendars: [EKCalendarInfo]
    }

    private var groupedCalendars: [CalendarGroup] {
        // 같은 sourceTitle끼리 묶고, sourceKind의 sortOrder를 따라 정렬.
        let grouped = Dictionary(grouping: calendars, by: { $0.sourceTitle })
        return grouped
            .map { title, items in
                CalendarGroup(
                    title: title,
                    calendars: items.sorted { $0.title < $1.title }
                )
            }
            .sorted { lhs, rhs in
                let lhsOrder = lhs.calendars.first?.sourceKind.sortOrder ?? Int.max
                let rhsOrder = rhs.calendars.first?.sourceKind.sortOrder ?? Int.max
                if lhsOrder != rhsOrder { return lhsOrder < rhsOrder }
                return lhs.title < rhs.title
            }
    }

    private func toggle(_ identifier: String) {
        if selection.contains(identifier) {
            selection.remove(identifier)
        } else {
            selection.insert(identifier)
        }
    }

    private func allInGroupSelected(_ group: CalendarGroup) -> Bool {
        group.calendars.allSatisfy { selection.contains($0.identifier) }
    }

    private func toggleAll(in group: CalendarGroup) {
        if allInGroupSelected(group) {
            for calendar in group.calendars {
                selection.remove(calendar.identifier)
            }
        } else {
            for calendar in group.calendars {
                selection.insert(calendar.identifier)
            }
        }
    }
}
