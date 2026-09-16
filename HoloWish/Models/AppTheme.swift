import Observation
import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case hazakura = "SWG Hazakura Light"
    case ishtar = "GMK Ishtar"
    case lavender = "SWG Lavender"
    case tako = "GMK Tako"
    case shoko = "GMK Shoko"
    case abyssal = "GMK Abyssal"

    var id: String { rawValue }

    func colors(for scheme: ColorScheme) -> ThemeColors {
        let dark = scheme == .dark
        switch self {
        case .hazakura:
            return dark
                ? ThemeColors(background: 0x1C151A, surface: 0x2C2028, primaryText: 0xFFF2F6, secondaryText: 0xD8BCC8, accent: 0xFF8FB5, secondaryAccent: 0x9FC394)
                : ThemeColors(background: 0xFFF8FA, surface: 0xFFF0F4, primaryText: 0x392B35, secondaryText: 0x765C6A, accent: 0xD95F8D, secondaryAccent: 0x789874)
        case .ishtar:
            return dark
                ? ThemeColors(background: 0x130F0C, surface: 0x281D15, primaryText: 0xF9E7BF, secondaryText: 0xCDB78C, accent: 0xE34A45, secondaryAccent: 0xD7A32B)
                : ThemeColors(background: 0xFFF8E8, surface: 0xF4E4C1, primaryText: 0x241813, secondaryText: 0x735845, accent: 0xA8202A, secondaryAccent: 0xB57C10)
        case .lavender:
            return dark
                ? ThemeColors(background: 0x18131F, surface: 0x2A2136, primaryText: 0xF4EBFC, secondaryText: 0xC7B1D8, accent: 0xB995DD, secondaryAccent: 0x7DAFA8)
                : ThemeColors(background: 0xFAF7FD, surface: 0xECE2F8, primaryText: 0x33253F, secondaryText: 0x6E5A7C, accent: 0x805AA8, secondaryAccent: 0x548F87)
        case .tako:
            return dark
                ? ThemeColors(background: 0x150E19, surface: 0x2B1832, primaryText: 0xFBF0FD, secondaryText: 0xCEB5D5, accent: 0xC47AD1, secondaryAccent: 0xFFB565)
                : ThemeColors(background: 0xFBF6FF, surface: 0xE9DDF0, primaryText: 0x38213F, secondaryText: 0x735979, accent: 0x6A347D, secondaryAccent: 0xD97823)
        case .shoko:
            return dark
                ? ThemeColors(background: 0x0D1821, surface: 0x172B3A, primaryText: 0xEAF7FF, secondaryText: 0xA8C5D8, accent: 0x68B5E8, secondaryAccent: 0xA7D5EC)
                : ThemeColors(background: 0xF4FAFF, surface: 0xDCECF7, primaryText: 0x183142, secondaryText: 0x507187, accent: 0x347FB8, secondaryAccent: 0x72AFD2)
        case .abyssal:
            return dark
                ? ThemeColors(background: 0x07151B, surface: 0x0E2A34, primaryText: 0xE2FAFB, secondaryText: 0x94C0C6, accent: 0x3DC3CF, secondaryAccent: 0x8173C8)
                : ThemeColors(background: 0xEEF7F8, surface: 0xD7EAEC, primaryText: 0x102C34, secondaryText: 0x476E76, accent: 0x147C8A, secondaryAccent: 0x6657AA)
        }
    }
}
struct ThemeColors {
    let background: Color
    let surface: Color
    let primaryText: Color
    let secondaryText: Color
    let accent: Color
    let secondaryAccent: Color

    init(background: UInt32, surface: UInt32, primaryText: UInt32, secondaryText: UInt32, accent: UInt32, secondaryAccent: UInt32) {
        self.background = Color(hex: background)
        self.surface = Color(hex: surface)
        self.primaryText = Color(hex: primaryText)
        self.secondaryText = Color(hex: secondaryText)
        self.accent = Color(hex: accent)
        self.secondaryAccent = Color(hex: secondaryAccent)
    }
}

@MainActor
@Observable
final class ThemeStore {
    private static let defaultsKey = "appearance.theme"

    var selected: AppTheme {
        didSet { UserDefaults.standard.set(selected.rawValue, forKey: Self.defaultsKey) }
    }

    init() {
        selected = UserDefaults.standard.string(forKey: Self.defaultsKey)
            .flatMap(AppTheme.init(rawValue:)) ?? .hazakura
    }

    func colors(for scheme: ColorScheme) -> ThemeColors { selected.colors(for: scheme) }
}

private extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
