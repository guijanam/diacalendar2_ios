//
//  EventData.swift
//  DiaCalendar2
//
//  Created by Bum Son on 5/9/26.
//

import Foundation

nonisolated struct EventData: Equatable, Sendable {
    enum Kind: String, Sendable {
        case event
        case shift
        case memo
        case lunarAnniversary
    }

    var kind: Kind
    /// EK 이벤트 식별자(.event), WorkShift.id의 UUID 문자열(.shift), 또는 DateMemo.id의 UUID 문자열(.memo).
    var originId: String
    var colorHex: String?
    var notesPreview: String?
    var shiftCode: String?
    var ekCalendarIdentifier: String?
    var isDone: Bool?

    init(
        kind: Kind,
        originId: String,
        colorHex: String? = nil,
        notesPreview: String? = nil,
        shiftCode: String? = nil,
        ekCalendarIdentifier: String? = nil,
        isDone: Bool? = nil
    ) {
        self.kind = kind
        self.originId = originId
        self.colorHex = colorHex
        self.notesPreview = notesPreview
        self.shiftCode = shiftCode
        self.ekCalendarIdentifier = ekCalendarIdentifier
        self.isDone = isDone
    }
}
