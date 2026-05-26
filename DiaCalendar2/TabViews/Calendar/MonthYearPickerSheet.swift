//
//  MonthYearPickerSheet.swift
//  DiaCalendar2
//

import SwiftUI

struct MonthYearPickerSheet: View {
    let calendar: Calendar
    let onSelect: (Date) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selectedYear: Int
    @State private var selectedMonth: Int

    private let currentYear: Int
    private let yearRange: [Int]

    init(calendar: Calendar, selected: Date, onSelect: @escaping (Date) -> Void) {
        self.calendar = calendar
        self.onSelect = onSelect
        let comps = calendar.dateComponents([.year, .month], from: selected)
        let year = comps.year ?? calendar.component(.year, from: Date())
        let month = comps.month ?? 1
        _selectedYear = State(initialValue: year)
        _selectedMonth = State(initialValue: month)
        currentYear = calendar.component(.year, from: Date())
        yearRange = Array((currentYear - 10)...(currentYear + 10))
    }

    private let monthNames: [String] = {
        var cal = Calendar.current
        return (1...12).map { month in
            cal.monthSymbols[month - 1]
        }
    }()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("취소") { dismiss() }
                Spacer()
                Text("년/월 선택")
                    .font(.headline)
                Spacer()
                Button("이동") {
                    if let date = calendar.date(from: DateComponents(year: selectedYear, month: selectedMonth, day: 1)) {
                        onSelect(date)
                    }
                    dismiss()
                }
                .fontWeight(.semibold)
            }
            .padding()

            Divider()

            HStack(spacing: 0) {
                Picker("년", selection: $selectedYear) {
                    ForEach(yearRange, id: \.self) { year in
                        Text(String(format: "%d년", year)).tag(year)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)

                Picker("월", selection: $selectedMonth) {
                    ForEach(1...12, id: \.self) { month in
                        Text(monthNames[month - 1]).tag(month)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal)
        }
    }
}
