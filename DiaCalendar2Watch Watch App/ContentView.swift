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
        VStack(spacing: 3) {
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
                    VStack(spacing: 2) {
                        if !shift.firstTime.isEmpty || !shift.numTr1.isEmpty {
                            halfBlock(train: shift.numTr1, time: shift.firstTime, color: .cyan)
                        }
                        if !shift.secondTime.isEmpty || !shift.numTr2.isEmpty {
                            halfBlock(train: shift.numTr2, time: shift.secondTime, color: .orange)
                        }
                    }
                    .padding(.top, 1)
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
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.horizontal)
        .padding(.vertical, 2)
    }

    /// 전반/후반 중 하나라도 표시할 내용이 있는지.
    private func hasHalfDetail(_ shift: WatchShiftPayload) -> Bool {
        !shift.numTr1.isEmpty || !shift.firstTime.isEmpty
            || !shift.numTr2.isEmpty || !shift.secondTime.isEmpty
    }

    /// 전반/후반 한 묶음: 열번(작게) 위, 시간(크게) 아래로 한 줄씩, 색으로 구분(전반=cyan, 후반=orange).
    @ViewBuilder
    private func halfBlock(train: String, time: String, color: Color) -> some View {
        VStack(spacing: 0) {
            if !train.isEmpty {
                Text(train)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(color)
            }
            if !time.isEmpty {
                Text(time)
                    .font(.headline)
                    .foregroundStyle(color)
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
