import SwiftUI
import UIKit

// Transit-inspired colors; stop letters and names also identify every stop.
enum TransitTheme {
    enum Appearance: String, CaseIterable, Identifiable {
        case light = "Light"
        case dark = "Dark"

        var id: String { rawValue }
        var colorScheme: ColorScheme { self == .dark ? .dark : .light }
    }

    enum Route {
        case shift, rest, meal

        var color: Color {
            switch self {
            case .shift: return adaptive(light: 0x1458A5, dark: 0x78B5FF)
            case .rest: return adaptive(light: 0x00764B, dark: 0x68D6A4)
            case .meal: return adaptive(light: 0xAC4C00, dark: 0xFFB566)
            }
        }
    }

    static let background = adaptive(light: 0xF2F0E9, dark: 0x111820)
    static let surface = adaptive(light: 0xFFFFFF, dark: 0x202B36)
    static let text = adaptive(light: 0x16212C, dark: 0xF3F6F9)
    static let secondaryText = adaptive(light: 0x52606D, dark: 0xB9C7D3)
    static let badgeText = adaptive(light: 0xFFFFFF, dark: 0x111820)
    static let badgeBorder = adaptive(light: 0x16212C, dark: 0xF3F6F9)
    static let error = adaptive(light: 0xB22232, dark: 0xFF929C)
    static var accent: Color { Route.shift.color }

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}

struct TransitStopBadge: View {
    let letter: String
    let route: TransitTheme.Route

    var body: some View {
        Text(letter)
            .font(.headline.bold())
            .foregroundStyle(TransitTheme.badgeText)
            .frame(width: 40, height: 40)
            .background(route.color, in: Circle())
            .overlay(Circle().strokeBorder(TransitTheme.badgeBorder, lineWidth: 2))
            .accessibilityLabel("Stop \(letter)")
    }
}

extension View {
    func transitScreenStyle() -> some View {
        self
            .foregroundStyle(TransitTheme.text)
            .tint(TransitTheme.accent)
            .scrollContentBackground(.hidden)
            .background(TransitTheme.background)
            .toolbarBackground(TransitTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}
