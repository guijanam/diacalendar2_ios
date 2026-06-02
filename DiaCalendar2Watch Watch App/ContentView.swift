//
//  ContentView.swift
//  DiaCalendar2Watch Watch App
//
//  당일 근무(교번)와 근무시간을 표시한다. 데이터는 폰에서 WCSession 으로 받는다.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject private var connectivity = WatchConnectivityManager.shared

    private var isToday: Bool {
        guard let shift = connectivity.todayShift else { return false }
        return Calendar.current.isDateInToday(shift.date)
    }

    var body: some View {
        VStack(spacing: 8) {
            if let shift = connectivity.todayShift {
                Text(dateTitle(shift.date))
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(shift.dia)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                if !shift.workTime.isEmpty {
                    Text(shift.workTime)
                        .font(.headline)
                        .foregroundStyle(.tint)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }

                if !isToday {
                    Text("동기화 대기 중")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Image(systemName: "applewatch.radiowaves.left.and.right")
                    .imageScale(.large)
                    .foregroundStyle(.secondary)
                Text("아이폰에서 동기화 중…")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }

    private func dateTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 (E)"
        return formatter.string(from: date)
    }
}

#Preview {
    ContentView()
}
