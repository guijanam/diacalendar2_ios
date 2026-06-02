//
//  DateMemo.swift
//  DiaCalendar2
//

import Foundation
import SwiftData

@Model
final class DateMemo {
    @Attribute(.unique) var id: UUID
    var title: String
    var body: String
    var colorHex: String
    var startDate: Date
    var endDate: Date
    /// 데이터베이스에 메모가 처음 생성된 시각. 기존 데이터 마이그레이션을 위해 기본값을 둔다.
    var createdAt: Date = Date()
    var updatedAt: Date
    var isDone: Bool
    var recurrenceData: Data?

    init(
        id: UUID = UUID(),
        title: String,
        body: String,
        colorHex: String,
        startDate: Date,
        endDate: Date,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isDone: Bool = false,
        recurrenceData: Data? = nil
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.colorHex = colorHex
        self.startDate = startDate
        self.endDate = endDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isDone = isDone
        self.recurrenceData = recurrenceData
    }

    func toDTO() -> DateMemoDTO {
        let recurrence = recurrenceData.flatMap { try? JSONDecoder().decode(EventRecurrence.self, from: $0) }
        return DateMemoDTO(
            id: id,
            title: title,
            body: body,
            colorHex: colorHex,
            startDate: startDate,
            endDate: endDate,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isDone: isDone,
            recurrence: recurrence
        )
    }
}
