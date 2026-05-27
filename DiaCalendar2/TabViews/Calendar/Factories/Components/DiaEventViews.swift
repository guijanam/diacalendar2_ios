//
//  DiaEventViews.swift
//  DiaCalendar2
//
//  Yotei default 이벤트 뷰들은 글자색을 `.background`(라이트=흰색, 다크=검정)로
//  하드코딩하기 때문에 사용자 이벤트 색이 라이트모드의 밝은 색일 때 가독성이 떨어진다.
//  여기서는 tint 색의 인지 휘도를 계산해 흰/검정 중 가독성 높은 글자색을 고른다.
//

import SwiftUI
import Yotei

private func tintColor(for event: YoteiEvent<EventData>) -> Color {
    if let hex = event.data.colorHex, let color = Color(hex: hex) {
        return color
    }
    return .primary
}

// MARK: - Day events grid (timed event blocks)

struct DiaDayEventsEventView: View {
    @Environment(\.yoteiFontStyle) private var fontStyle: YoteiFontStyle

    let event: YoteiEvent<EventData>

    var body: some View {
        let color = tintColor(for: event)
        let fg = ContrastPalette.textColor(onSolid: color)
        VStack(alignment: .leading) {
            Text(event.title)
                .foregroundStyle(fg)
                .font(fontStyle.caption)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(height: 16)
                .padding(.horizontal, 4)
        }
        .frame(
            minWidth: 0,
            maxWidth: .infinity,
            minHeight: 0,
            maxHeight: .infinity,
            alignment: .topLeading
        )
        .background(color)
        .clipShape(.rect(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .inset(by: 0.5)
                .stroke(fg.opacity(0.25), lineWidth: 1)
        )
    }
}

// MARK: - All-day strip

struct DiaAllDayEventView: View {
    @Environment(\.yoteiFontStyle) private var fontStyle: YoteiFontStyle

    let event: YoteiEvent<EventData>

    var body: some View {
        let color = tintColor(for: event)
        let fg = ContrastPalette.textColor(onSolid: color)
        Text(event.title)
            .lineLimit(1)
            .truncationMode(.tail)
            .foregroundStyle(fg)
            .font(fontStyle.caption)
            .padding(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
            .frame(maxWidth: .infinity, minHeight: 18, alignment: .leading)
            .background(color)
            .clipShape(.rect(cornerRadius: 6))
            .padding(EdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 2))
    }
}

// MARK: - Schedule (list) timed cell

struct DiaScheduleEventCellView: View {
    @Environment(\.yoteiFontStyle) private var fontStyle: YoteiFontStyle
    @Environment(\.calendar) private var calendar
    @Environment(\.colorScheme) private var colorScheme

    let cellDate: Date
    let event: YoteiEvent<EventData>

    private var dateRange: Range<Date> {
        event.dateInterval.start ..< event.dateInterval.end
    }

    var body: some View {
        let nowDate = Date.now
        let isPast = event.end < nowDate || (cellDate < calendar.startOfDay(for: nowDate))
        let dateInterval = event.dateInterval
        let baseColor = tintColor(for: event)
        // 과거 이벤트는 0.5 알파로 깔리므로 그 합성색을 기준으로 글자색 결정.
        let effectiveAlpha = isPast ? 0.5 : 1.0
        let surface = ContrastPalette.surfaceRGB(for: colorScheme)
        let composed = composedColor(base: baseColor, alpha: effectiveAlpha, surface: surface)
        let fg = ContrastPalette.textColor(onSolid: composed)

        VStack(alignment: .leading, spacing: 4) {
            let sameDay = calendar.isDate(dateInterval.start, inSameDayAs: dateInterval.end)
            let dateStyle = sameDay
                ? Date.IntervalFormatStyle(calendar: calendar, timeZone: calendar.timeZone)
                    .hour(.twoDigits(amPM: .omitted))
                    .minute()
                : Date.IntervalFormatStyle(calendar: calendar, timeZone: calendar.timeZone)
                    .day()
                    .month(.abbreviated)
                    .hour(.twoDigits(amPM: .omitted))
                    .minute()

            Text(dateRange.formatted(dateStyle))
                .font(fontStyle.caption2)
            Text(event.title)
                .lineLimit(1)
                .truncationMode(.tail)
                .font(fontStyle.subheadline)
        }
        .foregroundStyle(fg)
        .padding(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerSize: CGSize(width: 8, height: 8))
                .fill(baseColor)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(effectiveAlpha)
        }
    }
}

// MARK: - Schedule (list) all-day cell

struct DiaScheduleAllDayEventCellView: View {
    @Environment(\.yoteiFontStyle) private var fontStyle: YoteiFontStyle
    @Environment(\.calendar) private var calendar
    @Environment(\.colorScheme) private var colorScheme

    let cellDate: Date
    let event: YoteiEvent<EventData>

    var body: some View {
        let nowDate = Date.now
        let isPast = event.end < nowDate || (cellDate < calendar.startOfDay(for: nowDate))
        let baseColor = tintColor(for: event)
        let effectiveAlpha = isPast ? 0.5 : 1.0
        let surface = ContrastPalette.surfaceRGB(for: colorScheme)
        let composed = composedColor(base: baseColor, alpha: effectiveAlpha, surface: surface)
        let fg = ContrastPalette.textColor(onSolid: composed)

        Text(event.title)
            .lineLimit(1)
            .truncationMode(.tail)
            .foregroundStyle(fg)
            .font(fontStyle.caption)
            .padding(EdgeInsets(top: 3, leading: 4, bottom: 3, trailing: 4))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerSize: CGSize(width: 6, height: 6))
                    .fill(baseColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(effectiveAlpha)
            }
    }
}

// MARK: - Month grid event chip

struct DiaMonthEventView: View {
    @AppStorage(MonthFontScale.eventStorageKey) private var eventScale: Double = MonthFontScale.defaultScale
    @AppStorage(MonthFontScale.memoStorageKey) private var memoScale: Double = MonthFontScale.defaultScale

    let event: YoteiEvent<EventData>

    var body: some View {
        let color = tintColor(for: event)
        let fg = ContrastPalette.textColor(onSolid: color)
        let done = event.data.isDone == true
        let scale = event.data.kind == .memo ? memoScale : eventScale
        let prefix = event.data.kind == .lunarAnniversary ? "음) " : ""
        Text(prefix + event.title)
            .strikethrough(done, color: fg)
            .lineLimit(1)
            .truncationMode(.tail)
            .foregroundStyle(fg)
            .font(MonthFontScale.font(.caption2, scale: scale))
            .padding(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
            .frame(height: 14 * scale)
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()
            .background(color)
            .clipShape(.rect(cornerRadius: 6))
            .padding(EdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 2))
    }
}

// MARK: - Helpers

private func composedColor(
    base: Color,
    alpha: Double,
    surface: (r: Double, g: Double, b: Double)
) -> Color {
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    let ui = UIColor(base)
    if !ui.getRed(&r, green: &g, blue: &b, alpha: &a) {
        var white: CGFloat = 0
        if ui.getWhite(&white, alpha: &a) {
            r = white; g = white; b = white
        } else {
            return base
        }
    }
    let cr = Double(r) * alpha + surface.r * (1 - alpha)
    let cg = Double(g) * alpha + surface.g * (1 - alpha)
    let cb = Double(b) * alpha + surface.b * (1 - alpha)
    return Color(red: cr, green: cg, blue: cb)
}
