//
//  SupabaseAPI.swift
//  DiaCalendar2
//

import Foundation
import OSLog

enum SupabaseAPIError: Error, LocalizedError {
    case invalidURL
    case badStatus(Int, body: String?)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "잘못된 요청 URL입니다."
        case .badStatus(let code, let body):
            if let body, !body.isEmpty {
                return "서버 응답 오류 (HTTP \(code)): \(body)"
            }
            return "서버 응답 오류 (HTTP \(code))"
        case .decoding(let err): return "응답 해석 실패: \(err.localizedDescription)"
        }
    }
}

/// Thin URLSession + Codable wrapper for Supabase REST endpoints we use.
/// Pattern mirrors `/Users/heebum/Documents/AppStore Project/DiaCalendar/DiaCalendar/ApiService.swift`.
enum SupabaseAPI {
    private static func makeRequest(_ path: String) throws -> URLRequest {
        guard let url = URL(string: "\(SupabaseConfig.restURL)/\(path)") else {
            throw SupabaseAPIError.invalidURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return req
    }

    private static let log = Logger(subsystem: "DiaCalendar2", category: "SupabaseAPI")

    private static func send<T: Decodable>(_ req: URLRequest, as: T.Type) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw SupabaseAPIError.badStatus(-1, body: nil)
        }
        guard http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8)
            let urlString = req.url?.absoluteString ?? "?"
            log.error("[Supabase] HTTP \(http.statusCode, privacy: .public) for \(urlString, privacy: .public) — body: \(body ?? "(empty)", privacy: .public)")
            throw SupabaseAPIError.badStatus(http.statusCode, body: body)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            let preview = String(data: data, encoding: .utf8)?.prefix(500).description
            log.error("[Supabase] decoding failed: \(error.localizedDescription, privacy: .public) — body preview: \(preview ?? "(empty)", privacy: .public)")
            throw SupabaseAPIError.decoding(error)
        }
    }

    /// All offices (light-weight: name + code only).
    static func listOffices() async throws -> [OfficeDTO] {
        let req = try makeRequest("office?select=*&order=office_name.asc")
        return try await send(req, as: [OfficeDTO].self)
    }

    /// Single office detail by name.
    static func office(named name: String) async throws -> OfficeDTO? {
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        let req = try makeRequest("office?office_name=eq.\(encoded)&select=*")
        let rows: [OfficeDTO] = try await send(req, as: [OfficeDTO].self)
        return rows.first
    }

    /// All dia rows for a given office.
    static func dias(officeName: String) async throws -> [DiaDTO] {
        let encoded = officeName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? officeName
        let req = try makeRequest("dia?office_name=eq.\(encoded)&select=*")
        return try await send(req, as: [DiaDTO].self)
    }

    /// 대한민국 공휴일 전체. row 수가 적어 한 번에 fetch.
    /// `select=*`로 모든 컬럼을 받고 HolidayDTO가 가능한 키 이름을 모두 시도해 디코딩.
    /// 첫 1KB 본문도 로그에 남겨 컬럼명 / 형식 확인을 돕는다.
    static func listHolidays() async throws -> [HolidayDTO] {
        let req = try makeRequest("holidays?select=*&order=id.asc.nullslast")
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw SupabaseAPIError.badStatus(-1, body: nil)
        }
        let preview = String(data: data.prefix(1024), encoding: .utf8) ?? "(non-utf8)"
        log.info("[Supabase] holidays HTTP \(http.statusCode, privacy: .public) — body preview: \(preview, privacy: .public)")

        if http.statusCode != 200 {
            // order 컬럼이 없을 수도 있으니 order 없이 한 번 더 시도
            let retryReq = try makeRequest("holidays?select=*")
            let (data2, response2) = try await URLSession.shared.data(for: retryReq)
            guard let http2 = response2 as? HTTPURLResponse else {
                throw SupabaseAPIError.badStatus(-1, body: nil)
            }
            let preview2 = String(data: data2.prefix(1024), encoding: .utf8) ?? "(non-utf8)"
            log.info("[Supabase] holidays retry HTTP \(http2.statusCode, privacy: .public) — body preview: \(preview2, privacy: .public)")
            guard http2.statusCode == 200 else {
                throw SupabaseAPIError.badStatus(http2.statusCode, body: String(data: data2, encoding: .utf8))
            }
            return try decodeHolidays(from: data2)
        }
        return try decodeHolidays(from: data)
    }

    private static func decodeHolidays(from data: Data) throws -> [HolidayDTO] {
        do {
            return try JSONDecoder().decode([HolidayDTO].self, from: data)
        } catch {
            let preview = String(data: data.prefix(500), encoding: .utf8) ?? "(empty)"
            log.error("[Supabase] holiday decoding failed: \(error.localizedDescription, privacy: .public) — body preview: \(preview, privacy: .public)")
            throw SupabaseAPIError.decoding(error)
        }
    }

    /// 강제 업데이트 판단에 사용하는 단일 `app_version` 행을 가져온다.
    static func fetchAppVersion() async throws -> AppVersionDTO {
        let req = try makeRequest("app_version?id=eq.1&select=min_version,latest_version,store_url")
        let rows: [AppVersionDTO] = try await send(req, as: [AppVersionDTO].self)
        guard let dto = rows.first else {
            throw SupabaseAPIError.badStatus(404, body: "app_version row not found")
        }
        return dto
    }

    /// coworker_list 테이블에 device_id가 등록되어 있으면 true. (평생 무료 VIP 판단)
    static func isRegisteredDevice(_ deviceId: String) async throws -> Bool {
        let encoded = deviceId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? deviceId
        let req = try makeRequest("coworker_list?device_id=eq.\(encoded)&select=device_id&limit=1")
        let rows: [CoworkerDeviceDTO] = try await send(req, as: [CoworkerDeviceDTO].self)
        return !rows.isEmpty
    }
}

private struct CoworkerDeviceDTO: Decodable {
    let deviceId: String
    enum CodingKeys: String, CodingKey { case deviceId = "device_id" }
}
