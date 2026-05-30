//
//  CoworkerMatrixCalendar.swift
//  DiaCalendar2
//

import SwiftUI

/// 행렬형 달력: 왼쪽 이름열(나 + 동료) × 날짜 셀. 안드로이드 CoworkerCalendarGrid 이식.
struct CoworkerMatrixCalendar: View {
    let year: Int
    let month: Int
    let myScheduleMap: [Date: String]
    let coworkers: [CoworkerDTO]
    let coworkerSchedules: [UUID: [Date: String]]
    let holidayDates: Set<Date>

    @State private var selectedDate: Date?

    private let cal = ShiftRotationEngine.calendar
    private let weekdays = ["일", "월", "화", "수", "목", "금", "토"]
    private let nameColWidth: CGFloat = 52
    private let weekdayHeaderHeight: CGFloat = 30
    private let dateHeaderHeight: CGFloat = 19
    private let rowItemHeight: CGFloat = 24

    private var firstOfMonth: Date {
        cal.startOfDay(for: cal.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date())
    }
    private var daysInMonth: Int {
        cal.range(of: .day, in: .month, for: firstOfMonth)?.count ?? 30
    }
    /// 일요일=0 기준 시작 오프셋
    private var startOffset: Int {
        (cal.component(.weekday, from: firstOfMonth) - 1 + 7) % 7
    }
    private var rows: Int {
        (startOffset + daysInMonth + 6) / 7
    }
    private var rowHeight: CGFloat {
        dateHeaderHeight + rowItemHeight * CGFloat(coworkers.count + 1) + 6
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(0..<rows, id: \.self) { row in
                        weekRow(row)
                    }
                }
            }
        }
        .sheet(item: Binding(
            get: { selectedDate.map { IdentifiableDate(date: $0) } },
            set: { selectedDate = $0?.date }
        )) { wrapper in
            CoworkerDayDetailSheet(
                date: wrapper.date,
                myShift: myScheduleMap[cal.startOfDay(for: wrapper.date)],
                coworkers: coworkers,
                coworkerSchedules: coworkerSchedules
            )
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Header (이름열 + 요일)

    private var header: some View {
        HStack(spacing: 0) {
            Color(.secondarySystemBackground)
                .frame(width: nameColWidth, height: weekdayHeaderHeight)
            ForEach(0..<7, id: \.self) { i in
                Text(weekdays[i])
                    .font(.caption.weight(.bold))
                    .foregroundStyle(weekdayColor(i))
                    .frame(maxWidth: .infinity)
                    .frame(height: weekdayHeaderHeight)
                    .background(Color(.secondarySystemBackground))
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - 한 주

    @ViewBuilder
    private func weekRow(_ row: Int) -> some View {
        HStack(spacing: 0) {
            // 왼쪽 이름 열
            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: dateHeaderHeight)
                nameCell("나", color: .accentColor, bold: true)
                ForEach(coworkers) { coworker in
                    nameCell(coworker.name, color: .secondary, bold: false)
                }
            }
            .frame(width: nameColWidth, height: rowHeight, alignment: .topLeading)
            .padding(.horizontal, 3)
            .background(Color(.secondarySystemBackground))
            .overlay(Rectangle().stroke(Color(.separator).opacity(0.3), lineWidth: 0.5))

            // 날짜 셀 7개
            ForEach(0..<7, id: \.self) { col in
                let dayNumber = row * 7 + col - startOffset + 1
                dayCell(dayNumber: dayNumber, col: col)
            }
        }
    }

    private func nameCell(_ text: String, color: Color, bold: Bool) -> some View {
        Text(text)
            .font(.system(size: 11, weight: bold ? .bold : .regular))
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(height: rowItemHeight, alignment: .leading)
    }

    @ViewBuilder
    private func dayCell(dayNumber: Int, col: Int) -> some View {
        if dayNumber >= 1 && dayNumber <= daysInMonth {
            let date = cal.date(byAdding: .day, value: dayNumber - 1, to: firstOfMonth) ?? firstOfMonth
            let day = cal.startOfDay(for: date)
            let isToday = cal.isDateInToday(date)
            let isHoliday = holidayDates.contains(day)

            VStack(spacing: 1) {
                Text("\(dayNumber)일")
                    .font(.system(size: 12, weight: isToday ? .heavy : .regular))
                    .foregroundStyle(dayNumberColor(col: col, isToday: isToday, isHoliday: isHoliday))
                    .frame(height: dateHeaderHeight)

                // 내 근무
                badgeCell(myScheduleMap[day], isMine: true)
                // 동료 근무
                ForEach(coworkers) { coworker in
                    badgeCell(coworkerSchedules[coworker.id]?[day], isMine: false)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: rowHeight)
            .padding(.horizontal, 2)
            .background(isHoliday ? Color.red.opacity(0.08) : Color.clear)
            .contentShape(Rectangle())
            .overlay(
                Rectangle().stroke(
                    isToday ? Color.accentColor : Color(.separator).opacity(0.3),
                    lineWidth: isToday ? 1.5 : 0.5
                )
            )
            .onTapGesture { selectedDate = date }
        } else {
            Rectangle()
                .fill(Color.clear)
                .frame(maxWidth: .infinity)
                .frame(height: rowHeight)
                .overlay(Rectangle().stroke(Color(.separator).opacity(0.3), lineWidth: 0.5))
        }
    }

    @ViewBuilder
    private func badgeCell(_ shift: String?, isMine: Bool) -> some View {
        Group {
            if let shift {
                CoworkerShiftBadge(shiftName: shift, fontSize: isMine ? 12 : 11, isMine: isMine)
            } else {
                Color.clear
            }
        }
        .frame(height: rowItemHeight)
    }

    // MARK: - Colors

    private func weekdayColor(_ i: Int) -> Color {
        if i == 0 { return .red }
        if i == 6 { return .blue }
        return .primary
    }

    private func dayNumberColor(col: Int, isToday: Bool, isHoliday: Bool) -> Color {
        if isToday { return .accentColor }
        if col == 0 || isHoliday { return .red }
        if col == 6 { return .blue }
        return .primary
    }
}

private struct IdentifiableDate: Identifiable {
    let date: Date
    var id: TimeInterval { date.timeIntervalSince1970 }
}

// MARK: - 날짜 상세 시트

struct CoworkerDayDetailSheet: View {
    let date: Date
    let myShift: String?
    let coworkers: [CoworkerDTO]
    let coworkerSchedules: [UUID: [Date: String]]

    @Environment(\.dismiss) private var dismiss
    private let cal = ShiftRotationEngine.calendar

    private var titleString: String {
        let f = DateFormatter()
        f.calendar = cal
        f.timeZone = cal.timeZone
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy년 M월 d일 (E)"
        return f.string(from: date)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    personRow(name: "나", initial: "나", shift: myShift, isMine: true)
                }
                if !coworkers.isEmpty {
                    Section("동료") {
                        ForEach(coworkers) { coworker in
                            personRow(
                                name: coworker.name,
                                initial: String(coworker.name.prefix(1)),
                                shift: coworkerSchedules[coworker.id]?[cal.startOfDay(for: date)],
                                isMine: false
                            )
                        }
                    }
                }
            }
            .navigationTitle(titleString)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }

    private func personRow(name: String, initial: String, shift: String?, isMine: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill((isMine ? Color.accentColor : Color.secondary).opacity(0.18))
                    .frame(width: 32, height: 32)
                Text(initial)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(isMine ? Color.accentColor : Color.secondary)
            }
            Text(name)
                .font(.body)
                .fontWeight(isMine ? .bold : .regular)
            Spacer()
            if let shift {
                CoworkerShiftBadge(shiftName: shift, fontSize: 14, isMine: isMine)
                    .fixedSize()
            } else {
                Text("-").foregroundStyle(.secondary)
            }
        }
    }
}
