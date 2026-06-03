//
//  CafeteriaAPI.swift
//  DiaCalendar2
//
//  구내식당 메뉴 조회. weekly_menus 컬럼이 동적 JSON 구조라 수동 파싱한다.
//  (참고: 구버전 ApiService.getCafeteriaNames / getCafeteriaMenu)
//

import Foundation
import OSLog

enum CafeteriaAPIError: Error, LocalizedError {
    case invalidURL
    case badStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "잘못된 요청 URL입니다."
        case .badStatus(let code): return "서버 응답 오류 (HTTP \(code))"
        }
    }
}

/// 해당 날짜의 한 식당 식단(조/중/석식).
struct CafeteriaDayMenu {
    let date: String
    let breakfast: [String]
    let lunch: [String]
    let dinner: [String]
}

enum CafeteriaAPI {
    private static let log = Logger(subsystem: "DiaCalendar2", category: "CafeteriaAPI")

    private static func makeRequest(_ path: String) throws -> URLRequest {
        guard let url = URL(string: "\(CafeteriaConfig.restURL)/\(path)") else {
            throw CafeteriaAPIError.invalidURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue(CafeteriaConfig.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(CafeteriaConfig.anonKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return req
    }

    private static func dateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        return formatter.string(from: date)
    }

    /// 해당 날짜에 식단이 등록된 식당 이름 목록.
    static func cafeteriaNames(date: Date) async throws -> [String] {
        let dateStr = dateString(for: date)
        let path = "menu_analyses?select=cafeteria_name&start_date=lte.\(dateStr)&end_date=gte.\(dateStr)&order=cafeteria_name.asc"
        let req = try makeRequest(path)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw CafeteriaAPIError.badStatus(code)
        }

        let items = try JSONDecoder().decode([[String: String]].self, from: data)
        return Array(Set(items.compactMap { $0["cafeteria_name"] })).sorted()
    }

    /// 특정 식당의 해당 날짜 식단. 없으면 nil.
    static func menu(cafeteriaName: String, date: Date) async throws -> CafeteriaDayMenu? {
        let dateStr = dateString(for: date)
        let encodedName = cafeteriaName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cafeteriaName
        let path = "menu_analyses?cafeteria_name=eq.\(encodedName)&start_date=lte.\(dateStr)&end_date=gte.\(dateStr)&select=weekly_menus"
        let req = try makeRequest(path)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw CafeteriaAPIError.badStatus(code)
        }

        // weekly_menus가 동적 구조이므로 JSONSerialization으로 수동 파싱.
        guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let first = jsonArray.first,
              let weeklyMenus = first["weekly_menus"] as? [[String: Any]] else {
            return nil
        }

        for dayMenu in weeklyMenus {
            guard let menuDate = dayMenu["date"] as? String, menuDate == dateStr else { continue }

            // meals 하위에 breakfast/lunch/dinner가 있는 구조와, 평면 구조 둘 다 허용.
            let meals = dayMenu["meals"] as? [String: Any]
            let breakfast = parseMealItems(meals?["breakfast"] ?? dayMenu["breakfast"])
            let lunch = parseMealItems(meals?["lunch"] ?? dayMenu["lunch"])
            let dinner = parseMealItems(meals?["dinner"] ?? dayMenu["dinner"])

            return CafeteriaDayMenu(date: dateStr, breakfast: breakfast, lunch: lunch, dinner: dinner)
        }

        return nil
    }

    private static func parseMealItems(_ value: Any?) -> [String] {
        if let items = value as? [String] {
            return items
        }
        if let item = value as? String {
            return item.isEmpty ? [] : [item]
        }
        return []
    }
}
