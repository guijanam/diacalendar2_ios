//
//  UserShiftConfigDTO.swift
//  DiaCalendar2
//

import Foundation

enum ShiftPosition: String, Sendable, CaseIterable, Hashable {
    case engineer = "기관사"
    case conductor = "차장"
    case fourShift = "4조2교대"
    case custom = "custom"

    var displayName: String {
        switch self {
        case .engineer: return "기관사"
        case .conductor: return "차장"
        case .fourShift: return "4조2교대"
        case .custom: return "교대근무"
        }
    }

    /// Which `OfficeRecordDTO` field this position reads its pattern from.
    func pattern(in office: OfficeRecordDTO) -> [String] {
        switch self {
        case .engineer: return office.diaTurns1
        case .conductor: return office.diaTurns2
        case .fourShift: return office.subTurns
        case .custom: return []
        }
    }
}

struct UserShiftConfigDTO: Sendable, Hashable {
    var officeCode: Int64
    var officeName: String
    var position: ShiftPosition
    var shiftPattern: [String]
    var startDate: Date
    var referenceDate: Date
    var todayShift: String
    var todayShiftIndex: Int?
    var createdAt: Date

    /// `true` when this config refers to a user-defined CustomShift instead of a Supabase office.
    /// We encode customShift id via negative officeCode: `-(10000 + customShiftId)` (matches Android).
    var isCustomShift: Bool { officeCode <= -10000 }
    var customShiftId: Int64? {
        guard isCustomShift else { return nil }
        return -officeCode - 10000
    }
}
