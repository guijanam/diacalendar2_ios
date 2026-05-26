//
//  CalendarPickerSheet.swift
//  DiaCalendar2
//

import SwiftUI

struct CalendarPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let load: () async -> [EKCalendarInfo]
    let initialSelection: String?
    let onSelect: (String?) -> Void

    @State private var calendars: [EKCalendarInfo] = []
    @State private var selection: String?
    @State private var isLoading = true

    init(
        load: @escaping () async -> [EKCalendarInfo],
        initialSelection: String?,
        onSelect: @escaping (String?) -> Void
    ) {
        self.load = load
        self.initialSelection = initialSelection
        self.onSelect = onSelect
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
                    List(selection: $selection) {
                        Section {
                            HStack {
                                Text("자동 (기본 캘린더)")
                                Spacer()
                                if selection == nil {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { selection = nil }
                        } footer: {
                            Text("선택하지 않으면 시스템의 기본 캘린더에 추가됩니다.")
                        }

                        ForEach(groupedCalendars, id: \.title) { group in
                            Section(group.title) {
                                ForEach(group.calendars) { calendar in
                                    HStack(spacing: 12) {
                                        Circle()
                                            .fill(Color(hex: calendar.colorHex ?? "") ?? .gray)
                                            .frame(width: 12, height: 12)
                                        Text(calendar.title)
                                        Spacer()
                                        if selection == calendar.identifier {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(.tint)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture { selection = calendar.identifier }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("동기화 캘린더 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        onSelect(selection)
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

    private struct CalendarGroup: Equatable {
        let title: String
        let calendars: [EKCalendarInfo]
    }

    private var groupedCalendars: [CalendarGroup] {
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
}
