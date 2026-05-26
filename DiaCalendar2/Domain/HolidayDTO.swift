//
//  HolidayDTO.swift
//  DiaCalendar2
//

import Foundation

/// Raw row from Supabase `holidays` table.
/// Supabase 테이블 컬럼명을 모르므로 가능한 후보들을 모두 시도해 디코딩한다.
/// 날짜: `locdate` / `date` / `holiday_date` / `loc_date`
/// 이름: `datename` / `dateName` / `date_name` / `name` / `holiday_name` / `title`
struct HolidayDTO: Decodable, Sendable, Hashable {
    let locdate: String
    let datename: String

    private struct AnyKey: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { return nil }
        init(_ s: String) { self.stringValue = s }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)

        let dateKeys = ["locdate", "loc_date", "date", "holiday_date", "dt"]
        let nameKeys = ["datename", "dateName", "date_name", "name", "holiday_name", "title"]

        var dateValue: String?
        for k in dateKeys {
            if let v = try? c.decodeIfPresent(String.self, forKey: AnyKey(k)), !v.isEmpty {
                dateValue = v
                break
            }
            // 숫자형 locdate (예: 20260101)도 지원
            if let v = try? c.decodeIfPresent(Int.self, forKey: AnyKey(k)) {
                dateValue = String(v)
                break
            }
        }

        var nameValue: String?
        for k in nameKeys {
            if let v = try? c.decodeIfPresent(String.self, forKey: AnyKey(k)), !v.isEmpty {
                nameValue = v
                break
            }
        }

        guard let d = dateValue, let n = nameValue else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath,
                      debugDescription: "필수 컬럼(날짜/이름)을 찾지 못했습니다. tried date=\(dateKeys), name=\(nameKeys)")
            )
        }
        self.locdate = d
        self.datename = n
    }
}
