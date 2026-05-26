//
//  DiaDTO.swift
//  DiaCalendar2
//

import Foundation

/// Raw row from Supabase `dia` table — work details for a specific shift code at an office.
struct DiaDTO: Decodable, Sendable, Hashable {
    let diaId: String
    let officeName: String
    let typeName: String?
    let firstTime: String?
    let numTr1: String?
    let numTr2: String?
    let secondTime: String?
    let thirdTime: String?
    let totalTime: String?
    let workTime: String?

    private enum CodingKeys: String, CodingKey {
        case diaId = "dia_id"
        case officeName = "office_name"
        case typeName = "type_name"
        case firstTime = "first_time"
        case numTr1 = "num_tr1"
        case numTr2 = "num_tr2"
        case secondTime = "second_time"
        case thirdTime = "third_time"
        case totalTime = "total_time"
        case workTime = "work_time"
    }
}
