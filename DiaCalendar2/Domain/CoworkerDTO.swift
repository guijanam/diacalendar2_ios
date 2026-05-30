//
//  CoworkerDTO.swift
//  DiaCalendar2
//

import Foundation

struct CoworkerDTO: Sendable, Hashable, Identifiable {
    var id: UUID
    var name: String
    var sortOrder: Int
    /// 소속 그룹 id 목록 (여러 그룹 중복 가능)
    var groupIds: [UUID]
    /// 근무 순환 패턴
    var shiftPattern: [String]
    /// 기준 날짜
    var referenceDate: Date
    /// 기준 근무명
    var referenceShift: String
    /// 기준 근무의 패턴 내 인덱스 (중복 근무명 구분용)
    var referenceShiftIndex: Int?
    var createdAt: Date
}

struct CoworkerGroupDTO: Sendable, Hashable, Identifiable {
    var id: UUID
    var name: String
    var sortOrder: Int
    var createdAt: Date
}
