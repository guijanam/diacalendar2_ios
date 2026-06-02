//
//  DateMemoDTO.swift
//  DiaCalendar2
//

import Foundation

struct DateMemoDTO: Sendable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var body: String
    var colorHex: String
    var startDate: Date
    var endDate: Date
    /// 데이터베이스에 메모가 처음 생성된 시각.
    var createdAt: Date = Date()
    var updatedAt: Date
    var isDone: Bool
    var recurrence: EventRecurrence?
}

extension DateMemoDTO {
    /// 사용자가 선택할 수 있는 미리 정의된 배경 색상 팔레트.
//    static let palette: [String] = [
//        "#FFD1DC", // pastel pink
//        "#FFE5B4", // pastel peach
//        "#FFF5BA", // pastel yellow
//        "#C8E6C9", // pastel green
//        "#B5EAD7", // pastel mint
//        "#C4E1F5", // pastel blue
//        "#D5C6F0", // pastel purple
//        "#E0E0E0"  // light gray
//    ]
    static let palette: [String] = [
        "#E0E0E0",  // light gray
        "#8E8E93",  // System Gray: 비활성화된 버튼, 부가 설명(Caption) 텍스트

        "#FFD1DC", // pastel pink
        "#FF3B30", // System Red: 경고, 삭제, 오류 등 주의를 끌어야 할 때
        
        "#FFE5B4", // pastel peach
        "#FF9500", // System Orange: 알림, 중요한 포인트 강조
        "#FFF5BA", // pastel yellow
        "#FFCC00", // System Yellow: 주의, 별점, 즐겨찾기
        "#C8E6C9", // pastel green
        "#34C759", // System Green: 성공, 완료, 진행 상태, 긍정적인 행동
        "#B5EAD7", // pastel mint
        "#C4E1F5", // pastel blue
        "#007AFF", // System Blue: 가장 대중적인 기본 버튼, 링크, 강조 색상
        "#5AC8FA", // System Light Blue: 보조 파란색, 정보성 텍스트나 배경
        "#D5C6F0", // pastel purple
        "#5856D6", // System Purple: 특별한 카테고리나 프리미엄 기능 표기
   
        
    ]

    static var defaultColorHex: String { palette[0] }
}
