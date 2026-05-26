//
//  EventDetailSheet.swift
//  DiaCalendar2
//

import SwiftUI

struct EventDetailSheet: View {
    @Environment(\.dismiss) private var dismiss

    let eventIdentifier: String
    let calendar: Calendar
    let load: (String) async -> EventDTO?
    let onEdit: (String) -> Void
    let onDelete: (String, EventEditScope) -> Void

    @State private var dto: EventDTO?
    @State private var isLoading = true
    @State private var showSpanAlert = false

    var body: some View {
        NavigationStack {
            Group {
                if let dto {
                    Form {
                        Section {
                            LabeledContent("제목", value: dto.title)
                            LabeledContent("시작", value: format(dto.start, allDay: dto.isAllDay))
                            LabeledContent("종료", value: format(dto.end, allDay: dto.isAllDay))
                            if dto.isAllDay {
                                LabeledContent("종일", value: "예")
                            }
                        }

                        if let recurrence = dto.recurrence {
                            Section("반복") {
                                Text(recurrence.summary)
                            }
                        }

                        if !dto.alarms.isEmpty {
                            Section("알림") {
                                ForEach(dto.alarms) { alarm in
                                    Text(alarm.summary)
                                }
                            }
                        }

                        if let notes = dto.notes, !notes.isEmpty {
                            Section("메모") {
                                Text(notes)
                            }
                        }

                        Section {
                            Button(role: .destructive) {
                                if dto.recurrence != nil {
                                    showSpanAlert = true
                                } else {
                                    onDelete(dto.ekEventIdentifier, .thisEvent)
                                    dismiss()
                                }
                            } label: {
                                Label("삭제", systemImage: "trash")
                            }
                        }
                    }
                } else if isLoading {
                    ProgressView()
                } else {
                    ContentUnavailableView(
                        "이벤트를 찾을 수 없습니다",
                        systemImage: "questionmark.circle"
                    )
                }
            }
            .navigationTitle("이벤트 상세")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("편집") {
                        if let dto {
                            onEdit(dto.ekEventIdentifier)
                            dismiss()
                        }
                    }
                    .disabled(dto == nil)
                }
            }
            .task {
                dto = await load(eventIdentifier)
                isLoading = false
            }
            .alert("반복 이벤트 삭제", isPresented: $showSpanAlert) {
                Button("이 이벤트만 삭제", role: .destructive) {
                    if let dto {
                        onDelete(dto.ekEventIdentifier, .thisEvent)
                    }
                    dismiss()
                }
                Button("향후 모든 이벤트 삭제", role: .destructive) {
                    if let dto {
                        onDelete(dto.ekEventIdentifier, .futureEvents)
                    }
                    dismiss()
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("이 변경사항을 어디에 적용할까요?")
            }
        }
    }

    private func format(_ date: Date, allDay: Bool) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = allDay ? .none : .short
        return formatter.string(from: date)
    }
}
