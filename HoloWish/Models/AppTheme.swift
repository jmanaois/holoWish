import Observation
import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case bijou = "Koseki Bijou"
    case ayame = "Nakiri Ayame"
    case kronii = "Ouro Kronii"
    case gigi = "Gigi Murin"
    case shiori = "Shiori Novella"
    case zeta = "Vestia Zeta"
    case iroha = "Kazama Iroha"
    case kobo = "Kobo Kanaeru"
    case riona = "Isaki Riona"
    case mumei = "Nanashi Mumei"
    case kanade = "Otonose Kanade"
    case fubuki = "Shirakami Fubuki"

    var id: String { rawValue }

    var paletteDescription: String {
        switch self {
        case .bijou: "Amethyst, crystal pink & silver"
        case .ayame: "Crimson, gold & charcoal"
        case .kronii: "Royal blue, clockwork gold & navy"
        case .gigi: "Orange, sunshine gold & charcoal"
        case .shiori: "Ink, silver & amber"
        case .zeta: "Archive teal, spy silver & crimson"
        case .iroha: "Leaf green, warm gold & cream"
        case .kobo: "Rain blue, cloud white & sunshine"
        case .riona: "Crimson, graphite & cool silver"
        case .mumei: "Owl brown, parchment & teal"
        case .kanade: "Piano gold, coral & charcoal"
        case .fubuki: "Fox white, arctic blue & navy"
        }
    }

    // Inspired by the original model artwork on each member's official profile.
    // Accent shades are deeper in light mode and brighter in dark mode so they
    // remain readable as small labels as well as control tints.
    func colors(for scheme: ColorScheme) -> ThemeColors {
        let dark = scheme == .dark
        switch self {
        case .bijou:
            return dark
                ? ThemeColors(background: 0x171321, surface: 0x292238, primaryText: 0xF5F0FF, secondaryText: 0xC9BCD9, accent: 0xBEA0FF, secondaryAccent: 0xEDA5CE)
                : ThemeColors(background: 0xFAF8FF, surface: 0xEEE8F7, primaryText: 0x2C233C, secondaryText: 0x655573, accent: 0x6940A5, secondaryAccent: 0x993968)
        case .ayame:
            return dark
                ? ThemeColors(background: 0x1B1418, surface: 0x302228, primaryText: 0xFFF2F1, secondaryText: 0xD6BDBF, accent: 0xFF8A9B, secondaryAccent: 0xE9C36D)
                : ThemeColors(background: 0xFFF8F6, surface: 0xF4E7E5, primaryText: 0x30232B, secondaryText: 0x75575E, accent: 0xB32343, secondaryAccent: 0x806013)
        case .kronii:
            return dark
                ? ThemeColors(background: 0x101525, surface: 0x1D2940, primaryText: 0xEFF5FF, secondaryText: 0xB5C5DF, accent: 0x90B5FF, secondaryAccent: 0xE3C775)
                : ThemeColors(background: 0xF6F8FF, surface: 0xE6ECF7, primaryText: 0x1E2A43, secondaryText: 0x51627E, accent: 0x304FB0, secondaryAccent: 0x7C611B)
        case .gigi:
            return dark
                ? ThemeColors(background: 0x1C1815, surface: 0x302820, primaryText: 0xFFF4E6, secondaryText: 0xDDC2A4, accent: 0xFFA34F, secondaryAccent: 0xF5D968)
                : ThemeColors(background: 0xFFFAF1, surface: 0xF6EBD6, primaryText: 0x322822, secondaryText: 0x745E46, accent: 0xA64B0B, secondaryAccent: 0x78600C)
        case .shiori:
            return dark
                ? ThemeColors(background: 0x16151C, surface: 0x292630, primaryText: 0xF4F1F7, secondaryText: 0xC5BECE, accent: 0xD2C9E0, secondaryAccent: 0xE7BC70)
                : ThemeColors(background: 0xFAF9FC, surface: 0xECE9F0, primaryText: 0x25222D, secondaryText: 0x635B70, accent: 0x51425F, secondaryAccent: 0x856019)
        case .zeta:
            return dark
                ? ThemeColors(background: 0x11161B, surface: 0x232C33, primaryText: 0xF1F5F6, secondaryText: 0xB9C7CB, accent: 0x9FD5D8, secondaryAccent: 0xE17A82)
                : ThemeColors(background: 0xF7FAFA, surface: 0xE5EEF0, primaryText: 0x20292D, secondaryText: 0x56676E, accent: 0x2F6F76, secondaryAccent: 0xA83242)
        case .iroha:
            return dark
                ? ThemeColors(background: 0x131A15, surface: 0x243328, primaryText: 0xF8F4DD, secondaryText: 0xC5C9A6, accent: 0x8CCB63, secondaryAccent: 0xE8C56A)
                : ThemeColors(background: 0xFBFDF6, surface: 0xECF3E2, primaryText: 0x263226, secondaryText: 0x5B6C57, accent: 0x397A36, secondaryAccent: 0x80621D)
        case .kobo:
            return dark
                ? ThemeColors(background: 0x0D1823, surface: 0x183247, primaryText: 0xF0FAFF, secondaryText: 0xB9D7E5, accent: 0x63C9F2, secondaryAccent: 0xF2D26B)
                : ThemeColors(background: 0xF4FBFF, surface: 0xE0F2FA, primaryText: 0x172C3A, secondaryText: 0x506D7B, accent: 0x1677A1, secondaryAccent: 0x79620F)
        case .riona:
            return dark
                ? ThemeColors(background: 0x181317, surface: 0x30232B, primaryText: 0xFFF1F3, secondaryText: 0xD6BAC2, accent: 0xFF7189, secondaryAccent: 0xBCC8E8)
                : ThemeColors(background: 0xFFF7F8, surface: 0xF3E5E9, primaryText: 0x332229, secondaryText: 0x76545F, accent: 0xB32648, secondaryAccent: 0x4D6294)
        case .mumei:
            return dark
                ? ThemeColors(background: 0x1A1512, surface: 0x31251E, primaryText: 0xF9F1E6, secondaryText: 0xD1BCA6, accent: 0xD7A56D, secondaryAccent: 0x7FB7B2)
                : ThemeColors(background: 0xFCF8F2, surface: 0xF0E7DC, primaryText: 0x342820, secondaryText: 0x715E4E, accent: 0x8A5423, secondaryAccent: 0x2F6E69)
        case .kanade:
            return dark
                ? ThemeColors(background: 0x1C1811, surface: 0x342D1C, primaryText: 0xFFF8DE, secondaryText: 0xD9CDAA, accent: 0xF4D34F, secondaryAccent: 0xFF8979)
                : ThemeColors(background: 0xFFFCF1, surface: 0xF6F0D5, primaryText: 0x332F20, secondaryText: 0x6F6643, accent: 0x806600, secondaryAccent: 0xB33B43)
        case .fubuki:
            return dark
                ? ThemeColors(background: 0x0E1821, surface: 0x1B2D3A, primaryText: 0xF1FAFF, secondaryText: 0xB8D0DF, accent: 0x78CFF2, secondaryAccent: 0xAAB7EE)
                : ThemeColors(background: 0xF5FBFF, surface: 0xE1F1F7, primaryText: 0x182C38, secondaryText: 0x4E6B7A, accent: 0x16769E, secondaryAccent: 0x5263A3)
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
            .flatMap(AppTheme.init(rawValue:)) ?? .bijou
        // Retired themes and first launches use Bijou; persist the resolved choice.
        UserDefaults.standard.set(selected.rawValue, forKey: Self.defaultsKey)
    }

    func colors(for scheme: ColorScheme) -> ThemeColors { selected.colors(for: scheme) }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum CardNamePreference: String, CaseIterable, Identifiable {
    case japaneseFirst = "Japanese First"
    case englishFirst = "English First"

    var id: String { rawValue }
}

enum QuickAddBehavior: String, CaseIterable, Identifiable {
    case addImmediately = "Add Immediately"
    case askForDetails = "Ask for Purchase Details"

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .addImmediately: "Immediately"
        case .askForDetails: "Ask for Details"
        }
    }
}

@MainActor
@Observable
final class AppSettings {
    private enum Key {
        static let appearance = "settings.appearance"
        static let cardNamePreference = "settings.cardNamePreference"
        static let quickAddBehavior = "settings.quickAddBehavior"
    }

    var appearance: AppAppearance {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: Key.appearance) }
    }
    var cardNamePreference: CardNamePreference {
        didSet { UserDefaults.standard.set(cardNamePreference.rawValue, forKey: Key.cardNamePreference) }
    }
    var quickAddBehavior: QuickAddBehavior {
        didSet { UserDefaults.standard.set(quickAddBehavior.rawValue, forKey: Key.quickAddBehavior) }
    }

    init() {
        let defaults = UserDefaults.standard
        appearance = defaults.string(forKey: Key.appearance).flatMap(AppAppearance.init(rawValue:)) ?? .system
        cardNamePreference = defaults.string(forKey: Key.cardNamePreference).flatMap(CardNamePreference.init(rawValue:)) ?? .japaneseFirst
        quickAddBehavior = defaults.string(forKey: Key.quickAddBehavior).flatMap(QuickAddBehavior.init(rawValue:)) ?? .addImmediately
    }
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
