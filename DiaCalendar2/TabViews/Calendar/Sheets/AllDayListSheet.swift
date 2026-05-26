//
//  AllDayListSheet.swift
//  DiaCalendar2
//

import SwiftUI
import Yotei

struct AllDayListSheet: View {
    @Environment(\.dismiss) private var dismiss

    let date: Date
    let calendar: Calendar
    let events: [YoteiEvent<EventData>]
    let onSelectEvent: (String) -> Void

    var body: some View {
        NavigationStack {
            List {
                if events.isEmpty {
                    Text("종일 이벤트가 없습니다.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(events, id: \.id) { event in
                        Button {
                            if event.data.kind == .event {
                                onSelectEvent(event.data.originId)
                            }
                        } label: {
                            HStack {
                                Text(event.title)
                                Spacer()
                                if event.data.kind == .shift {
                                    Image(systemName: "briefcase.fill")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(event.data.kind != .event)
                    }
                }
            }
            .navigationTitle(formattedDate)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }
}
