//
//  AttendanceCategory.swift
//  DiaCalendar2
//

import Foundation

/// 근태(휴가) 레코드의 분류.
/// 월간 "휴무" 갯수 계산 시 지휴는 더하고 지근은 빼는 데 사용한다.
enum AttendanceCategory: String, Sendable, CaseIterable {
    /// 일반 근태(휴가). 연차/대휴 등 AttendanceType 으로 등록된 건.
    case normal
    /// 지정 근무: 원래 "휴" 가 근무로 바뀌는 케이스. 월간 휴 갯수에서 차감(-1).
    case jigeun
    /// 지정 휴무: 원래 근무가 "휴" 로 바뀌는 케이스. 월간 휴 갯수에 가산(+1).
    case jihyu

    /// 배지에 표시될 고정 이름. normal 은 별도 이름이 없으므로 빈 문자열.
    var displayName: String {
        switch self {
        case .normal: return ""
        case .jigeun: return "지근"
        case .jihyu: return "지휴"
        }
    }

    /// 지근 전용 하늘색. 달력 배경·지근 버튼에 공통 사용.
    static let jigeunColorHex = "#5AC8FA"

    /// 분류별 표시 색상. 지근은 하늘색, 그 외(일반 근태·지휴)는 휴가 빨강.
    var colorHex: String {
        switch self {
        case .jigeun: return AttendanceCategory.jigeunColorHex
        case .normal, .jihyu: return ShiftDayInfo.attendanceColorHex
        }
    }
}
