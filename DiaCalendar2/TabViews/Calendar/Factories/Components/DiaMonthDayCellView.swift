//
//  DiaMonthDayCellView.swift
//  DiaCalendar2
//
//  Yotei `YoteiPagesMonthDayCellDefaultView` 의 로직을 따라가면서
//  공휴일 / 일요일 / 토요일에 색을 적용하고, 공휴일이면 날짜 아래에 이름을 작게 표시.
//

import SwiftUI

struct DiaMonthDayCellView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.shiftsByDate) private var shiftsByDate
    @AppStorage(MonthFontScale.dateStorageKey) private var dateScale: Double = MonthFontScale.defaultScale
    @AppStorage(MonthFontScale.shiftStorageKey) private var shiftScale: Double = MonthFontScale.defaultScale

    let date: Date
    let todayDate: Date
    let focusedDate: Date?
    let isEnabled: Bool
    let holidayName: String?
    /// Environment의 shiftsByDate dict에서 조회할 키(UTC 자정 Date). nil이면 미조회.
    let shiftKey: Date?
    let calendar: Calendar

    private var shift: ShiftCellData? {
        guard let shiftKey else { return nil }
        return shiftsByDate[shiftKey]
    }

    var body: some View {
        let isToday = calendar.isDate(date, inSameDayAs: todayDate)
        let isFocused: Bool = {
            guard let focusedDate else { return false }
            return calendar.isDate(date, inSameDayAs: focusedDate)
        }()
        let isHoliday = holidayName != nil
        let foreground = HolidayColors.dayNumberColor(
            date: date,
            isEnabled: isEnabled,
            isToday: isToday,
            isFocused: isFocused,
            isHoliday: isHoliday,
            calendar: calendar
        )
        let dayFormatStyle = Date.FormatStyle(calendar: calendar, timeZone: calendar.timeZone).day()

        VStack(spacing: 0) {
            Text(date.formatted(dayFormatStyle))
                .font(MonthFontScale.font(.caption2, scale: dateScale))
                .foregroundStyle(foreground)
                .padding(4)
                .background {
                    if isToday {
                        Circle().fill(Color.accentColor)
                    } else if isFocused {
                        Circle().fill(Color.accentColor.opacity(0.2))
                    } else {
                        Circle().fill(Color.clear)
                    }
                }
                .padding(.top, 2)

            if isEnabled, let shift {
                shiftPill(shift)
                    .padding(.horizontal, 2)
                    .padding(.top, 1)
            }

            if isEnabled {
                Text(holidayName ?? " ")
                    .font(MonthFontScale.fixedSize(8, scale: dateScale))
                    .foregroundStyle(HolidayPalette.red)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 1)
                    .padding(.bottom, 1)
                    .opacity(holidayName != nil ? 1 : 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.bottom, shift == nil ? 3 : 0)
    }

    @ViewBuilder
    private func shiftPill(_ shift: ShiftCellData) -> some View {
        let defaultBg: Color = shift.colorHex.flatMap { Color(hex: $0) } ?? .clear
        let containsTilde = shift.label.contains("~")
        let displayText = containsTilde ? "~" : shift.label
        let finalBg = containsTilde ? Color.gray : defaultBg
        let isDark = colorScheme == .dark
        let bgOpacity: Double = isDark ? 0.55 : 0.2
        let textColor: Color = isDark ? .white : .black

        Text(displayText)
            .font(MonthFontScale.fixedSize(15, weight: .semibold, scale: shiftScale))
            .lineLimit(1)
            .truncationMode(.tail)
            .foregroundStyle(textColor)
            .frame(height: 17 * shiftScale)
            .padding(.horizontal, 4)
            .background(Rectangle().fill(finalBg).opacity(bgOpacity))
    }
}
