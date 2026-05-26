//
//  OfficeDTO.swift
//  DiaCalendar2
//

import Foundation

/// Raw row from Supabase `office` table.
/// PostgreSQL array columns (`dia_turns1`, `sub_turns`, etc.) come back as strings like
/// `"{a,b,c}"` or JSON arrays like `"[\"a\",\"b\"]"`. We decode them into `[String]` via
/// `ShiftPatternParser.parse(_:)` in the custom initializer.
struct OfficeDTO: Decodable, Sendable, Hashable {
    let officeCode: Int64
    let officeName: String
    let diaTurns1: [String]
    let diaTurns2: [String]
    let diaTurns3: [String]
    let subTurns: [String]
    let diaSelects: [String]

    private enum CodingKeys: String, CodingKey {
        case officeName = "office_name"
        case officeCode = "office_code"
        case diaTurns1 = "dia_turns1"
        case diaTurns2 = "dia_turns2"
        case diaTurns3 = "dia_turns3"
        case subTurns = "sub_turns"
        case diaSelects = "dia_selects"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        officeName = (try? c.decode(String.self, forKey: .officeName)) ?? ""

        if let n = try? c.decode(Int64.self, forKey: .officeCode) {
            officeCode = n
        } else if let s = try? c.decode(String.self, forKey: .officeCode), let n = Int64(s) {
            officeCode = n
        } else {
            officeCode = 0
        }

        diaTurns1 = ShiftPatternParser.parse(try? c.decode(String.self, forKey: .diaTurns1))
        diaTurns2 = ShiftPatternParser.parse(try? c.decode(String.self, forKey: .diaTurns2))
        diaTurns3 = ShiftPatternParser.parse(try? c.decode(String.self, forKey: .diaTurns3))
        subTurns  = ShiftPatternParser.parse(try? c.decode(String.self, forKey: .subTurns))
        diaSelects = ShiftPatternParser.parse(try? c.decode(String.self, forKey: .diaSelects))
    }
}
