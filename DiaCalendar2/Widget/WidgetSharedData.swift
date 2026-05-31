//
//  WidgetSharedData.swift
//  DiaCalendar2
//
//  앱↔위젯이 공유하는 위젯 표시 데이터 모델 + App Group 컨테이너 JSON 경로.
//  메인 앱이 widget_data.json 을 write 하고, 위젯이 read 한다.
//
//  ⚠️ 이 파일은 위젯 타깃의 DiaCalendar2Widget/WidgetSharedData.swift 와
//     내용이 동일하게 유지되어야 한다. (두 타깃이 각자 사본을 컴파일)
//

import Foundation

/// 위젯에 표시될 최종 데이터. App Group 컨테이너의 widget_data.json 에 저장된다.
struct WidgetData: Codable {
    /// 데이터 생성 시점
    let date: Date
    /// 이번 달 전체(앞 빈칸 포함) + 다음 달 첫 7일 치 근무 데이터
    let calendarDays: [SimpleCalendarDay]
    let holidayInfo: [Date: String]

    let todayDia: String
    let todayWorkTime: String
    let tomorrowDia: String
    let tomorrowWorkTime: String
}

/// Realm/SwiftData 객체가 아닌, 위젯 표시에 필요한 최소 데이터만 담는 가벼운 구조체.
struct SimpleCalendarDay: Codable, Identifiable {
    let id = UUID()
    /// KST 자정. MonthView 앞 빈칸은 Date.distantPast 로 표현.
    let date: Date
    /// effective 근무명(교번). 빈 문자열이면 근무 없음.
    let dia: String
    /// 근무 시간 문자열(DiaRecord.workTime). 없으면 빈 문자열.
    let workTime: String

    private enum CodingKeys: String, CodingKey {
        case date, dia, workTime
    }
}

enum WidgetSharedStore {
    static let appGroupID = "group.com.developergui7.DiaCalendar2"
    static let fileName = "widget_data.json"

    static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(fileName)
    }
}
