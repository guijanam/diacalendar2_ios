//
//  LunarSolarConverter.swift
//  DiaCalendar2
//
//  lunar-swift를 직접 import 하는 유일한 파일.
//  윤달: lunarMonth를 음수(-month)로 전달하면 윤달을 의미함 (lunar-swift 규칙).
//

import Foundation
import LunarSwift

enum LunarSolarConverter {

    /// 음력 날짜 → 해당 연도의 양력 Date.
    /// - Parameters:
    ///   - lunarYear: 변환할 음력 연도
    ///   - lunarMonth: 음력 월 (1–12)
    ///   - lunarDay: 음력 일 (1–30)
    ///   - isLeapMonth: 윤달 여부
    ///   - calendar: 결과 Date를 생성할 Calendar
    /// - Returns: 해당 양력 Date, 변환 불가(잘못된 날짜 등)면 nil
    static func solarDate(
        lunarYear: Int,
        lunarMonth: Int,
        lunarDay: Int,
        isLeapMonth: Bool,
        calendar: Calendar
    ) -> Date? {
        // 윤달 요청 시 해당 연도에 실제로 그 달의 윤달이 있는지 확인
        // lunar-swift에서 윤달은 음수 month(-6 = 윤6월)로 표현
        let effectiveMonth: Int
        if isLeapMonth {
            let leapMonthOfYear = LunarYear.fromYear(lunarYear: lunarYear).leapMonth
            if leapMonthOfYear == lunarMonth {
                effectiveMonth = -lunarMonth  // 윤달 존재 → 음수로 전달
            } else {
                effectiveMonth = lunarMonth   // 윤달 없는 해 → 일반달로 폴백
            }
        } else {
            effectiveMonth = lunarMonth
        }

        // lunarDay가 해당 월의 일수를 초과하면 마지막 날로 clamp
        let clampedDay: Int
        if let lunarMonthObj = LunarYear.fromYear(lunarYear: lunarYear).getMonth(lunarMonth: effectiveMonth) {
            clampedDay = min(lunarDay, lunarMonthObj.dayCount)
        } else {
            return nil
        }

        let lunar = Lunar(lunarYear: lunarYear, lunarMonth: effectiveMonth, lunarDay: clampedDay)
        let solar = lunar.solar

        var comps = DateComponents()
        comps.year = solar.year
        comps.month = solar.month
        comps.day = solar.day
        return calendar.date(from: comps)
    }

    /// 주어진 DateInterval 내에서 특정 음력 기념일의 모든 양력 발생 날짜를 반환한다.
    static func solarDates(
        for dto: LunarAnniversaryDTO,
        in interval: DateInterval,
        calendar: Calendar
    ) -> [Date] {
        let startYear = calendar.component(.year, from: interval.start)
        let endYear   = calendar.component(.year, from: interval.end)

        var results: [Date] = []
        for year in startYear...endYear {
            guard let date = solarDate(
                lunarYear: year,
                lunarMonth: dto.lunarMonth,
                lunarDay: dto.lunarDay,
                isLeapMonth: dto.isLeapMonth,
                calendar: calendar
            ) else { continue }
            if date >= interval.start && date < interval.end {
                results.append(date)
            }
        }
        return results
    }

    /// 양력 날짜 → 음력 월/일 반환 (DayDetailSheet에서 pre-fill용)
    static func lunarMonthDay(from date: Date, calendar: Calendar) -> (month: Int, day: Int) {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        guard let y = comps.year, let m = comps.month, let d = comps.day else {
            return (1, 1)
        }
        let solar = Solar(year: y, month: m, day: d)
        let lunar = Lunar.fromSolar(solar: solar)
        return (abs(lunar.month), lunar.day)
    }
}
