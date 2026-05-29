//
//  SeoulSubwayAPI.swift
//  DiaCalendar2
//
//  서울 열린데이터 광장 지하철 실시간 위치 API.
//  패턴은 SupabaseAPI.swift를 따른다. HTTP 엔드포인트라 ATS(NSAllowsArbitraryLoads) 허용 필요 —
//  앱 Info.plist에 이미 설정되어 있다.
//

import Foundation
import OSLog

// MARK: - DTO

/// 실시간 위치 API의 단일 열차 항목.
struct SubwayPositionDTO: Decodable, Identifiable, Hashable {
    let subwayId: String      // "1002" = 2호선
    let subwayNm: String?     // "2호선"
    let statnId: String       // "1002000203" — 끝 자리가 역 순번
    let statnNm: String       // 현재 역
    let trainNo: String       // 열번 "2300"
    let updnLine: String      // "0"=상행/내선, "1"=하행/외선
    let statnTnm: String?     // 종착역
    let trainSttus: String    // "0"진입 "1"도착 "2"출발 "3"전역출발
    let directAt: String?     // "1"=급행
    let lstcarAt: String?     // "1"=막차

    var id: String { trainNo + "-" + statnId }

    /// statnId 끝 4자리를 역 순번으로 사용(루프 노선 정렬 근사).
    var stationSequence: Int {
        Int(statnId.suffix(4)) ?? Int(statnId) ?? 0
    }
}

private struct SubwayPositionResponse: Decodable {
    struct ErrorMessage: Decodable {
        let status: Int
        let code: String
        let message: String
        let total: Int
    }
    let errorMessage: ErrorMessage?
    let realtimePositionList: [SubwayPositionDTO]?
}

// MARK: - Error

enum SeoulSubwayAPIError: Error, LocalizedError {
    case invalidURL
    case badStatus(Int, body: String?)
    case apiError(code: String, message: String)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "잘못된 요청 URL입니다."
        case .badStatus(let code, _): return "서버 응답 오류 (HTTP \(code))"
        case .apiError(_, let message): return message
        case .decoding(let err): return "응답 해석 실패: \(err.localizedDescription)"
        }
    }
}

// MARK: - API

enum SeoulSubwayAPI {
    private static let apiKey = "595a517963646576333041576d556d"
    private static let baseURL = "http://swopenAPI.seoul.go.kr/api/subway"
    private static let defaultCount = 100
    private static let log = Logger(subsystem: "DiaCalendar2", category: "SeoulSubwayAPI")

    /// 지정 호선의 모든 실시간 열차 위치를 가져온다.
    static func realtimePositions(line: Int) async throws -> [SubwayPositionDTO] {
        let path = "\(apiKey)/json/realtimePosition/0/\(defaultCount)/\(line)호선"
        guard let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "\(baseURL)/\(encoded)") else {
            throw SeoulSubwayAPIError.invalidURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.cachePolicy = .reloadIgnoringLocalCacheData   // 실시간이므로 캐시 무시

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw SeoulSubwayAPIError.badStatus(-1, body: nil)
        }
        guard http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8)
            log.error("[Subway] HTTP \(http.statusCode, privacy: .public) — \(body ?? "(empty)", privacy: .public)")
            throw SeoulSubwayAPIError.badStatus(http.statusCode, body: body)
        }
        do {
            let decoded = try JSONDecoder().decode(SubwayPositionResponse.self, from: data)
            // API는 정상 HTTP에도 errorMessage.code로 논리 오류를 표현(데이터 없음 등).
            if let err = decoded.errorMessage, err.code != "INFO-000" {
                log.error("[Subway] API code \(err.code, privacy: .public) — \(err.message, privacy: .public)")
                throw SeoulSubwayAPIError.apiError(code: err.code, message: err.message)
            }
            return decoded.realtimePositionList ?? []
        } catch let e as SeoulSubwayAPIError {
            throw e
        } catch {
            let preview = String(data: data.prefix(500), encoding: .utf8)
            log.error("[Subway] decode failed: \(error.localizedDescription, privacy: .public) — \(preview ?? "", privacy: .public)")
            throw SeoulSubwayAPIError.decoding(error)
        }
    }
}
