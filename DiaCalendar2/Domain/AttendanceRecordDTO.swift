//
//  AttendanceRecordDTO.swift
//  DiaCalendar2
//

import Foundation

struct AttendanceRecordDTO: Sendable, Hashable, Identifiable {
    var date: Date
    var attendanceTypeId: UUID
    var name: String
    var shortName: String
    var originalShiftName: String
    var groupId: UUID
    var createdAt: Date
    /// 근태 분류 (일반/지근/지휴). 월간 휴 갯수 계산에 사용.
    var category: AttendanceCategory = .normal

    var id: Date { date }
}
