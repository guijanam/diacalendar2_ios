//
//  AttendanceTypeDTO.swift
//  DiaCalendar2
//

import Foundation

struct AttendanceTypeDTO: Sendable, Hashable, Identifiable {
    var id: UUID
    var name: String
    var shortName: String
    var createdAt: Date
    var limitCount: Int? = nil   // nil 또는 0 = 무제한
    var resetMonth: Int? = 1     // 기본 1월
    var resetDay: Int? = 1       // 기본 1일
}

/// 첫 부팅 시 시드. 사용자가 자유롭게 편집/삭제 가능.
nonisolated enum AttendanceDefaults {
    nonisolated static let entries: [(name: String, shortName: String)] = [
        ("연차", "연차"),
        ("촉진연차", "촉연"),
        ("대체휴가", "대휴"),
        ("학습휴가", "학휴"),
        ("자녀돌봄휴가", "돌휴"),
        ("청원휴가", "청휴"),
        ("보건휴가", "보휴"),
        ("만근휴가", "만휴"),
        ("출산휴가", "출휴"),
        ("장기재직휴가", "장휴"),
        ("임금피크휴가", "임휴"),
        ("임신검진동행휴가", "동휴"),
        ("난임치료동행휴가", "난휴"),
        ("공가", "공가"),
        ("회행", "회행"),
        ("출장", "출장"),
        ("반차", "반차"),
        ("가연차", "가연"),
        ("반반차", "반반"),
        ("출장", "출장")
    ]
}
