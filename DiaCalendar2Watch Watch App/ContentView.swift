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

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(shift.dia)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)

                    if !shift.workTime.isEmpty {
                        Text(shift.workTime)
                            .font(.headline)
                            .foregroundStyle(.tint)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                    }
                }

                if hasHalfDetail(shift) {
                    VStack(spacing: 4) {
                        if !shift.firstTime.isEmpty || !shift.numTr1.isEmpty {
                            halfRow(label: "전반", train: shift.numTr1, time: shift.firstTime)
                        }
                        if !shift.secondTime.isEmpty || !shift.numTr2.isEmpty {
                            halfRow(label: "후반", train: shift.numTr2, time: shift.secondTime)
                        }
                    }
                    .padding(.top, 2)
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

    /// 전반/후반 중 하나라도 표시할 내용이 있는지.
    private func hasHalfDetail(_ shift: WatchShiftPayload) -> Bool {
        !shift.numTr1.isEmpty || !shift.firstTime.isEmpty
            || !shift.numTr2.isEmpty || !shift.secondTime.isEmpty
    }

    /// 전반/후반 한 줄: "전반  2204  06:30" 형태.
    @ViewBuilder
    private func halfRow(label: String, train: String, time: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            if !train.isEmpty {
                Text(train)
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            if !time.isEmpty {
                Text(time)
                    .font(.caption)
                    .foregroundStyle(.tint)
            }
        }
        .minimumScaleFactor(0.6)
        .lineLimit(1)
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
