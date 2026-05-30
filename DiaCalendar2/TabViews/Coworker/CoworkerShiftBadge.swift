//
//  CoworkerShiftBadge.swift
//  DiaCalendar2
//

import SwiftUI

/// Small pill used in the coworker matrix calendar to show a single shift name.
/// Color mirrors `ShiftColor` / `DayDetailSheet` styling.
struct CoworkerShiftBadge: View {
    @Environment(\.colorScheme) private var colorScheme
    let shiftName: String
    var fontSize: CGFloat = 11
    var isMine: Bool = false

    var body: some View {
        let colorHex = ShiftColor.colorHex(for: shiftName, isSwap: false)
        let baseColor = colorHex.flatMap { Color(hex: $0) } ?? .accentColor
        // 내 근무: 배경색 채움 + 대비 보정 글자색.
        // 동료 근무: 배경 없이 근무 색상 글자만 (내 근무와 구분).
        let textColor = isMine ? ContrastPalette.readableForeground(baseColor, scheme: colorScheme) : baseColor

        Text(shiftName)
            .font(.system(size: fontSize, weight: .bold, design: .rounded))
            .foregroundColor(textColor)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity)
            .frame(height: fontSize + 6)
            .background(isMine ? baseColor.opacity(0.22) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
