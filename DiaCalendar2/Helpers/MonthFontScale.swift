//
//  MonthFontScale.swift
//  DiaCalendar2
//

import SwiftUI
import Yotei

enum MonthFontScale {
    /// 호환용 레거시 키. 4분할 도입 이전에 단일 배율을 저장하던 키.
    /// 새 4분할 키들의 초기값을 결정할 때 마이그레이션 소스로만 사용한다.
    static let storageKey = "monthFontScale"

    static let dateStorageKey = "monthFontScale.date"
    static let shiftStorageKey = "monthFontScale.shift"
    static let eventStorageKey = "monthFontScale.event"
    static let memoStorageKey = "monthFontScale.memo"

    static let minScale: Double = 0.8
    static let maxScale: Double = 1.4
    static let defaultScale: Double = 1.0

    /// 시스템 textStyle Font에 배율을 적용해 새 Font 반환.
    static func font(_ textStyle: Font.TextStyle, scale: Double) -> Font {
        let basePoints: CGFloat
        switch textStyle {
        case .caption2:    basePoints = 11
        case .caption:     basePoints = 12
        case .footnote:    basePoints = 13
        case .subheadline: basePoints = 15
        case .callout:     basePoints = 16
        case .body:        basePoints = 17
        case .headline:    basePoints = 17
        case .title3:      basePoints = 20
        case .title2:      basePoints = 22
        case .title:       basePoints = 28
        case .largeTitle:  basePoints = 34
        default:           basePoints = 17
        }
        return .system(size: basePoints * scale)
    }

    /// `.system(size: X, weight: W)` 형태 고정 크기에 배율 적용.
    static func fixedSize(_ baseSize: CGFloat, weight: Font.Weight = .regular, scale: Double) -> Font {
        .system(size: baseSize * scale, weight: weight)
    }

    /// Yotei 디폴트 뷰들이 사용하는 YoteiFontStyle 환경값을 배율 적용된 버전으로.
    static func yoteiFontStyle(scale: Double) -> YoteiFontStyle {
        YoteiFontStyle(
            caption: font(.caption, scale: scale),
            caption2: font(.caption2, scale: scale),
            body: font(.body, scale: scale),
            headline: font(.headline, scale: scale),
            subheadline: font(.subheadline, scale: scale)
        )
    }
}
