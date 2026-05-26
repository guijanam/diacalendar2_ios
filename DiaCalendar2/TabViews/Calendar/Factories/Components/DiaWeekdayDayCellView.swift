//
//  DiaWeekdayDayCellView.swift
//  DiaCalendar2
//
//  Yotei `YoteiDayCellDefaultView` 의 로직을 따라가면서
//  공휴일 / 주말 색만 적용 (이름은 미표시).
//

import SwiftUI

struct DiaWeekdayDayCellView: View {
    let date: Date
    let todayDate: Date
    let isHoliday: Bool
    let calendar: Calendar

    var body: some View {
        let isToday = calendar.isDate(date, inSameDayAs: todayDate)
        let foreground = HolidayColors.dayNumberColor(
            date: date,
            isEnabled: true,
            isToday: isToday,
            isFocused: false,
            isHoliday: isHoliday,
            calendar: calendar
        )
        let dayFormatStyle = Date.FormatStyle(calendar: calendar, timeZone: calendar.timeZone).day()

        Text(date.formatted(dayFormatStyle))
            .font(.subheadline)
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(height: 40)
            .background {
                if isToday {
                    Circle().fill(Color.accentColor)
                } else {
                    Circle().fill(Color.clear)
                }
            }
    }
}
