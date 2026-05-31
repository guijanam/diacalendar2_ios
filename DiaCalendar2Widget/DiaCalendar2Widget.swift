//
//  DiaCalendar2Widget.swift
//  DiaCalendar2Widget
//
//  근무 위젯. 메인 앱이 App Group에 써둔 widget_data.json 을 읽어 표시한다.
//  구독/VIP(=widgetUnlocked) 사용자만 내용을 보고, 비구독은 잠금 안내를 표시한다.
//  (구버전 DiaCalendar 위젯 UI 포팅)
//

import WidgetKit
import SwiftUI

// MARK: - Provider

struct Provider: TimelineProvider {

    private func readWidgetData() -> WidgetData? {
        guard let url = WidgetSharedStore.fileURL,
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WidgetData.self, from: data)
    }

    func placeholder(in context: Context) -> DayEntry {
        DayEntry.placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (DayEntry) -> ()) {
        // 갤러리 스냅샷은 잠금과 무관하게 미리보기 형태를 보여준다.
        if let data = readWidgetData() {
            completion(DayEntry(date: Date(), fullData: data, isUnlocked: true))
        } else {
            completion(DayEntry.placeholder)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DayEntry>) -> ()) {
        let now = Date()
        let calendar = Calendar.current

        // 비구독(잠금): 데이터 조회 없이 잠금 엔트리만. 구독 시 앱이 reload 트리거.
        guard SharedSubscriptionState.widgetUnlocked else {
            completion(Timeline(entries: [DayEntry.locked], policy: .never))
            return
        }

        let startOfTomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now)!)

        guard let data = readWidgetData() else {
            let nextUpdate = calendar.date(byAdding: .hour, value: 1, to: now)!
            completion(Timeline(entries: [DayEntry.placeholder], policy: .after(nextUpdate)))
            return
        }

        // 오늘 엔트리 + 자정에 갱신될 내일 엔트리.
        let todayEntry = DayEntry(date: now, fullData: data, isUnlocked: true)
        let tomorrowEntry = DayEntry(date: startOfTomorrow, fullData: data, isUnlocked: true)
        completion(Timeline(entries: [todayEntry, tomorrowEntry], policy: .after(startOfTomorrow)))
    }
}

// MARK: - Entry

struct DayEntry: TimelineEntry {
    let date: Date
    let calendarDays: [SimpleCalendarDay]
    let holidayInfo: [Date: String]
    let isUnlocked: Bool

    var selectedDiaInfo: String
    var selectedWorkTime: String
    var tomorrowDia: String
    var tomorrowWorkTime: String

    init(date: Date, fullData: WidgetData, isUnlocked: Bool) {
        self.date = date
        self.calendarDays = fullData.calendarDays
        self.holidayInfo = fullData.holidayInfo
        self.isUnlocked = isUnlocked

        let calendar = Calendar.current

        if let todayData = fullData.calendarDays.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
            self.selectedDiaInfo = todayData.dia.isEmpty ? "근무없음" : todayData.dia
            self.selectedWorkTime = todayData.workTime
        } else {
            self.selectedDiaInfo = "정보없음"
            self.selectedWorkTime = ""
        }

        let tomorrowDate = calendar.date(byAdding: .day, value: 1, to: date)!
        if let tomorrowData = fullData.calendarDays.first(where: { calendar.isDate($0.date, inSameDayAs: tomorrowDate) }) {
            self.tomorrowDia = tomorrowData.dia.isEmpty ? "근무없음" : tomorrowData.dia
            self.tomorrowWorkTime = tomorrowData.workTime
        } else {
            self.tomorrowDia = "정보없음"
            self.tomorrowWorkTime = ""
        }
    }

    private init(date: Date, days: [SimpleCalendarDay], holidays: [Date: String], isUnlocked: Bool, todayD: String, todayT: String, tomD: String, tomT: String) {
        self.date = date; self.calendarDays = days; self.holidayInfo = holidays; self.isUnlocked = isUnlocked
        self.selectedDiaInfo = todayD; self.selectedWorkTime = todayT
        self.tomorrowDia = tomD; self.tomorrowWorkTime = tomT
    }

    static var placeholder: DayEntry {
        DayEntry(date: Date(), days: [], holidays: [:], isUnlocked: true, todayD: "정보없음", todayT: "", tomD: "정보없음", tomT: "")
    }

    static var locked: DayEntry {
        DayEntry(date: Date(), days: [], holidays: [:], isUnlocked: false, todayD: "", todayT: "", tomD: "", tomT: "")
    }
}

// MARK: - Entry View

struct DiaCalendar2WidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: DayEntry

    @ViewBuilder
    var body: some View {
        if !entry.isUnlocked {
            LockedView()
        } else {
            switch family {
            case .systemSmall: DayView(entry: entry)
            case .systemMedium: WeekView(entry: entry)
            case .systemLarge: MonthView(entry: entry)

            case .accessoryCircular:
                ZStack {
                    AccessoryWidgetBackground()
                    VStack { Text(entry.selectedDiaInfo.prefix(1)).font(.headline) }
                }

            case .accessoryRectangular:
                HStack(spacing: 12) {
                    WorkInfoView(title: "오늘", dia: entry.selectedDiaInfo, time: entry.selectedWorkTime, isAccent: true)
                    WorkInfoView(title: "내일", dia: entry.tomorrowDia, time: entry.tomorrowWorkTime, isAccent: false)
                }

            case .accessoryInline:
                Text("오늘: \(entry.selectedDiaInfo) / 내일: \(entry.tomorrowDia)")

            @unknown default: DayView(entry: entry)
            }
        }
    }
}

/// 비구독 사용자 잠금 안내. 탭하면 앱이 열려 구독을 유도한다.
struct LockedView: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "lock.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("프리미엄 구독이 필요합니다")
                .font(.caption)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            Text("탭하여 구독하기")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetURL(URL(string: "diacalendar://subscribe"))
    }
}

struct WorkInfoView: View {
    let title: String
    let dia: String
    let time: String
    let isAccent: Bool

    var body: some View {
        VStack(alignment: .leading) {
            Text(title).font(.subheadline).foregroundColor(.secondary)
            Text(dia).font(.body).if(isAccent) { $0.widgetAccentable() }
            Text(time).font(.callout)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition { transform(self) } else { self }
    }
}

// MARK: - Widget Configuration

struct DiaCalendar2Widget: Widget {
    let kind: String = "DiaCalendar2Widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            DiaCalendar2WidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("내 근무 달력")
        .description("홈 화면과 잠금화면에서 근무를 확인하세요.")
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge,
            .accessoryCircular, .accessoryRectangular, .accessoryInline
        ])
    }
}

// MARK: - Helpers

extension Date {
    var weekday: Int? {
        Calendar.current.dateComponents([.weekday], from: self).weekday
    }
}

// MARK: - Size-specific Views

struct DayView: View {
    var entry: DayEntry

    var body: some View {
        HStack(spacing: 0) {
            SingleDayInfoView(
                title: "오늘",
                date: entry.date,
                dia: entry.selectedDiaInfo,
                workTime: entry.selectedWorkTime,
                holidayInfo: entry.holidayInfo
            )
            Divider()
            SingleDayInfoView(
                title: "내일",
                date: Calendar.current.date(byAdding: .day, value: 1, to: entry.date)!,
                dia: entry.tomorrowDia,
                workTime: entry.tomorrowWorkTime,
                holidayInfo: entry.holidayInfo
            )
        }
        .padding(2)
    }
}

struct SingleDayInfoView: View {
    let title: String
    let date: Date
    let dia: String
    let workTime: String
    let holidayInfo: [Date: String]

    private var holidayName: String? {
        holidayInfo[Calendar.current.startOfDay(for: date)]
    }

    private var isHolidayOrSunday: Bool {
        if holidayName != nil { return true }
        return Calendar.current.component(.weekday, from: date) == 1
    }

    private var dateColor: Color {
        if isHolidayOrSunday { return .red }
        return Calendar.current.component(.weekday, from: date) == 7 ? .blue : .primary
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(title).font(.system(size: 14)).lineLimit(1)
            Text(holidayName ?? " ")
                .font(.system(size: 12)).lineLimit(1)
                .foregroundColor(.red).frame(height: 12)
            Text(date, format: .dateTime.day())
                .font(.system(size: 15)).lineLimit(1).bold()
                .foregroundColor(dateColor)
            Text("(\(date, format: .dateTime.weekday(.short)))")
                .font(.system(size: 14)).lineLimit(1)
                .foregroundColor(dateColor)
            Spacer()
            Text(workTime)
                .font(.system(size: 12)).lineLimit(1)
                .fontWeight(.bold).foregroundColor(.secondary)
            WidgetDiaView2(diaTurn: dia, workTime: workTime)
        }
        .frame(maxWidth: .infinity)
    }
}

struct WeekView: View {
    var entry: DayEntry
    private let weekdays = ["일", "월", "화", "수", "목", "금", "토"]

    var body: some View {
        VStack(alignment: .center, spacing: 1) {
            Text(entry.date, format: .dateTime.month(.wide))
                .font(.system(size: 12)).bold()

            HStack(spacing: 4) {
                ForEach(getSevenDays(from: entry.date), id: \.id) { day in
                    VStack(spacing: 2) {
                        let weekdayIndex = Calendar.current.component(.weekday, from: day.date)
                        let isToday = Calendar.current.isDate(day.date, inSameDayAs: entry.date)
                        let dayDate = Calendar.current.startOfDay(for: day.date)
                        let isHoliday = entry.holidayInfo[dayDate] != nil
                        let dateColor: Color = (isHoliday || weekdayIndex == 1) ? .red : (weekdayIndex == 7) ? .blue : .primary

                        HStack {
                            if let holidayName = entry.holidayInfo[dayDate] {
                                Text(holidayName)
                                    .font(.system(size: 8)).lineLimit(1).foregroundColor(.red)
                            }
                        }.frame(height: 8)

                        Text("\(Calendar.current.component(.day, from: day.date))")
                            .font(.system(size: 10)).lineLimit(1).bold(isToday)
                            .foregroundColor(dateColor)
                            .frame(width: 24, height: 24)
                            .background(isToday ? Color.orange.opacity(0.5) : Color.clear)
                            .clipShape(Rectangle())

                        Text(weekdays[weekdayIndex - 1])
                            .font(.system(size: 10)).lineLimit(1).foregroundColor(dateColor)

                        WidgetShiftInfoView(diaTurn: day.dia, workTime: day.workTime)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(2)
    }

    private func getSevenDays(from date: Date) -> [SimpleCalendarDay] {
        let calendar = Calendar.current
        var sevenDays: [SimpleCalendarDay] = []
        for i in 0..<7 {
            if let targetDate = calendar.date(byAdding: .day, value: i, to: date) {
                if let dayData = entry.calendarDays.first(where: { calendar.isDate($0.date, inSameDayAs: targetDate) }) {
                    sevenDays.append(dayData)
                } else {
                    sevenDays.append(SimpleCalendarDay(date: targetDate, dia: "", workTime: ""))
                }
            }
        }
        return sevenDays
    }
}

struct MonthView: View {
    var entry: DayEntry
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    private let weekdays = ["일", "월", "화", "수", "목", "금", "토"]

    var body: some View {
        VStack(spacing: 1) {
            Spacer()
            HStack(alignment: .center) {
                Text(entry.date, format: .dateTime.month(.wide))
                    .font(.system(size: 10)).lineLimit(1).bold()
            }
            Spacer().frame(height: 2)

            HStack {
                ForEach(weekdays, id: \.self) { day in
                    let weekdayIndex = weekdays.firstIndex(of: day)! + 1
                    Text(day)
                        .font(.system(size: 8)).lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .foregroundColor(weekdayIndex == 1 ? .red : (weekdayIndex == 7 ? .blue : .primary))
                }
            }
            Spacer().frame(height: 2)

            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(entry.calendarDays) { day in
                    if day.date == Date.distantPast {
                        Rectangle().fill(Color.clear)
                    } else {
                        VStack(spacing: 1) {
                            let weekdayIndex = Calendar.current.component(.weekday, from: day.date)
                            let dayDate = Calendar.current.startOfDay(for: day.date)
                            let isHoliday = entry.holidayInfo[dayDate] != nil
                            let dateColor: Color = (isHoliday || weekdayIndex == 1) ? .red : (weekdayIndex == 7) ? .blue : .primary

                            Text("\(Calendar.current.component(.day, from: day.date))")
                                .font(.system(size: 10)).lineLimit(1)
                                .foregroundColor(dateColor)
                                .padding(1).frame(maxWidth: .infinity)
                                .background(Calendar.current.isDate(day.date, inSameDayAs: entry.date) ? Color.orange.opacity(0.5) : Color.clear)
                                .clipShape(Circle())

                            WidgetShiftInfoView(diaTurn: day.dia, workTime: day.workTime)
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(1)
    }
}

// MARK: - Component Views

struct WidgetShiftInfoView: View {
    var diaTurn: String
    var workTime: String
    let holidayKeywords = ["휴", "연차", "촉연", "병가", "가연", "공가", "돌봄", "반차"]

    private var backgroundColor: Color {
        if diaTurn.contains("~") || diaTurn.isEmpty {
            return .clear
        } else if holidayKeywords.contains(where: { diaTurn.contains($0) }) || workTime.contains("운휴") {
            return .red.opacity(0.8)
        } else if diaTurn.contains("대") {
            return .green.opacity(0.8)
        }
        return .gray.opacity(0.6)
    }

    private var textColor: Color {
        if backgroundColor != .clear && backgroundColor != .gray { return .white }
        return .secondary
    }

    var body: some View {
        VStack(spacing: 1) {
            Text(getTurnSting(diaTurn))
                .font(.system(size: 13)).lineLimit(1).fontWeight(.bold)
                .foregroundColor(textColor)
            if !diaTurn.isEmpty && !diaTurn.contains("~") {
                Text(workTime)
                    .font(.system(size: 13)).lineLimit(1)
                    .foregroundColor(textColor.opacity(0.9))
            }
        }
        .frame(width: 39, height: 30)
        .background(backgroundColor)
        .cornerRadius(4)
    }

    private func getTurnSting(_ turn: String) -> String {
        if turn.contains("~") || turn.contains("비") { return "~" }
        return turn
    }
}

struct WidgetDiaView2: View {
    var diaTurn: String
    var workTime: String
    let holidayKeywords = ["휴", "연차", "촉연", "병가", "가연", "공가", "돌봄", "반차"]

    private var backgroundColor: Color {
        if diaTurn.contains("~") || diaTurn.isEmpty {
            return .clear
        } else if holidayKeywords.contains(where: { diaTurn.contains($0) }) || workTime.contains("운휴") {
            return .red.opacity(0.8)
        } else if diaTurn.contains("대") {
            return .green.opacity(0.8)
        }
        return .gray.opacity(0.6)
    }

    private var textColor: Color {
        let bg = backgroundColor
        if bg == .pink.opacity(0.8) || bg == .red.opacity(0.8) || bg == .green.opacity(0.8) {
            return .white
        }
        return .secondary
    }

    var body: some View {
        Text(getTurnSting(diaTurn))
            .font(.system(size: 14, weight: .medium)).lineLimit(1)
            .frame(width: 38, height: 21)
            .background(backgroundColor)
            .foregroundColor(textColor)
            .cornerRadius(4)
    }

    fileprivate func getTurnSting(_ turn: String) -> String {
        if turn.contains("비") { return "~" }
        return turn
    }
}
