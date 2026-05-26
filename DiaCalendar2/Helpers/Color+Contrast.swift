//
//  Color+Contrast.swift
//  DiaCalendar2
//
//  이벤트/메모 카드처럼 임의의 사용자 색 위에 텍스트를 올릴 때
//  라이트/다크 모드 모두에서 가독성이 유지되도록 글자색·배경 알파를 결정한다.
//

import SwiftUI
import UIKit

enum ContrastPalette {
    /// 라이트/다크 모드에서 카드 배경에 적용할 알파.
    /// 라이트에서는 거의 불투명에 가깝게(시스템 흰 배경과 섞여 글자색이 흐려지는 것을 방지),
    /// 다크에서는 약간 투명하게(원색이 과하게 밝아지지 않도록).
    static func cardBackgroundAlpha(for scheme: ColorScheme) -> Double {
        scheme == .dark ? 0.55 : 0.95
    }

    /// 시스템 그룹 배경 근사값. textColor 계산시 합성 결과를 평가하는 데 쓰인다.
    static func surfaceRGB(for scheme: ColorScheme) -> (r: Double, g: Double, b: Double) {
        scheme == .dark ? (0.11, 0.11, 0.12) : (0.95, 0.95, 0.97)
    }

    /// `background.opacity(alpha)`를 시스템 surface 위에 합성한 가상의 색에 대해
    /// WCAG sRGB 상대 휘도를 계산한 뒤, 가장 가독성이 높은 글자색(.white/.black)을 반환.
    static func textColor(on background: Color, scheme: ColorScheme) -> Color {
        let rgb = sRGBComponents(of: UIColor(background))
        let alpha = cardBackgroundAlpha(for: scheme)
        let surface = surfaceRGB(for: scheme)
        let r = rgb.r * alpha + surface.r * (1 - alpha)
        let g = rgb.g * alpha + surface.g * (1 - alpha)
        let b = rgb.b * alpha + surface.b * (1 - alpha)
        return relativeLuminance(r: r, g: g, b: b) > 0.5 ? .black : .white
    }

    /// 알파 합성 없이 원색 위 글자색을 결정. (Yotei 기본 이벤트처럼 불투명 배경에 글자 올릴 때)
    static func textColor(onSolid background: Color) -> Color {
        let rgb = sRGBComponents(of: UIColor(background))
        return relativeLuminance(r: rgb.r, g: rgb.g, b: rgb.b) > 0.5 ? .black : .white
    }

    /// 색 글자(컬러 텍스트)를 옅은/시스템 배경 위에 올릴 때 가독성을 보정한다.
    /// 라이트 모드에서 너무 밝은 색(예: 하늘색)은 흰 배경과 대비가 부족하므로 어둡게 낮추고,
    /// 다크 모드에서는 원색을 그대로 사용한다.
    static func readableForeground(_ color: Color, scheme: ColorScheme) -> Color {
        guard scheme == .light else { return color }
        let rgb = sRGBComponents(of: UIColor(color))
        let lum = relativeLuminance(r: rgb.r, g: rgb.g, b: rgb.b)
        // 휘도가 충분히 낮으면(=이미 진한 색) 그대로 둔다.
        guard lum > 0.4 else { return color }
        // 밝은 색일수록 더 많이 어둡게: 목표 휘도 ~0.25 수준이 되도록 배율 적용.
        let factor = max(0.35, 0.25 / lum)
        return Color(
            red: rgb.r * factor,
            green: rgb.g * factor,
            blue: rgb.b * factor
        )
    }

    private static func sRGBComponents(of color: UIColor) -> (r: Double, g: Double, b: Double) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if color.getRed(&r, green: &g, blue: &b, alpha: &a) {
            return (Double(r), Double(g), Double(b))
        }
        var white: CGFloat = 0
        if color.getWhite(&white, alpha: &a) {
            return (Double(white), Double(white), Double(white))
        }
        return (0.5, 0.5, 0.5)
    }

    private static func relativeLuminance(r: Double, g: Double, b: Double) -> Double {
        func channel(_ c: Double) -> Double {
            c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
    }
}
