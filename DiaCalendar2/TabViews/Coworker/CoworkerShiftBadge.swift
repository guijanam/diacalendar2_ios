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
        let textColor = ContrastPalette.readableForeground(baseColor, scheme: colorScheme)

        Text(shiftName)
            .font(.system(size: fontSize, weight: .bold, design: .rounded))
            .foregroundColor(textColor)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity)
            .frame(height: fontSize + 6)
            .background(baseColor.opacity(isMine ? 0.22 : 0.14))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
