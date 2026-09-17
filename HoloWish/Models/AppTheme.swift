import Observation
import SwiftUI

struct AppTheme: RawRepresentable, CaseIterable, Hashable, Identifiable {
    let rawValue: String

    private let definition: TalentThemeDefinition

    var id: String { rawValue }
    var japaneseName: String { definition.japaneseName }
    var portraitFileName: String { definition.portraitFileName }
    var category: AppThemeCategory { definition.category }
    var status: TalentStatus? { definition.status }
    var paletteDescription: String {
        if let status { return "\(japaneseName) • \(status.label)" }
        return japaneseName
    }

    init?(rawValue: String) {
        guard let definition = TalentThemeDefinition.all.first(where: {
            $0.name == rawValue || $0.legacyNames.contains(rawValue)
        }) else { return nil }
        self.rawValue = definition.name
        self.definition = definition
    }

    private init(_ definition: TalentThemeDefinition) {
        rawValue = definition.name
        self.definition = definition
    }

    static func == (lhs: AppTheme, rhs: AppTheme) -> Bool { lhs.rawValue == rhs.rawValue }
    func hash(into hasher: inout Hasher) { hasher.combine(rawValue) }

    static let allCases = TalentThemeDefinition.all.map { AppTheme($0) }
    static let bijou = AppTheme(rawValue: "Koseki Bijou")!

    static func cases(in category: AppThemeCategory, matching query: String) -> [AppTheme] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
        return allCases.filter { theme in
            theme.category == category && (
                normalized.isEmpty ||
                theme.rawValue.localizedLowercase.contains(normalized) ||
                theme.japaneseName.localizedLowercase.contains(normalized)
            )
        }
    }

    func colors(for scheme: ColorScheme) -> ThemeColors {
        definition.palette.colors(for: scheme)
    }
}

enum AppThemeCategory: String, CaseIterable, Identifiable {
    case hololive = "hololive"
    case indonesia = "hololive Indonesia"
    case english = "hololive English"
    case devIs = "hololive DEV_IS"
    case holoAN = "holoAN"
    case alumni = "Alumni & Staff"

    var id: String { rawValue }
}

enum TalentStatus: String {
    case affiliate
    case alumni
    case retired

    var label: String { rawValue.capitalized }
}

private struct TalentThemeDefinition {
    let name: String
    let japaneseName: String
    let portraitFileName: String
    let category: AppThemeCategory
    let status: TalentStatus?
    let palette: TalentPalette
    let legacyNames: [String]

    init(
        name: String,
        japaneseName: String,
        portraitFileName: String,
        category: AppThemeCategory,
        status: TalentStatus?,
        accent: UInt32,
        secondaryAccent: UInt32,
        legacyNames: [String] = []
    ) {
        self.name = name
        self.japaneseName = japaneseName
        self.portraitFileName = portraitFileName
        self.category = category
        self.status = status
        palette = TalentPalette(accent: accent, secondaryAccent: secondaryAccent)
        self.legacyNames = legacyNames
    }

    static let all: [TalentThemeDefinition] = [
        .init(name: "Tokino Sora", japaneseName: "ときのそら", portraitFileName: "Tokino-Sora_list_thumb.png", category: .hololive, status: nil, accent: 0x0548EA, secondaryAccent: 0x7E4C49),
        .init(name: "Robocosan", japaneseName: "ロボ子さん", portraitFileName: "Robocosan_list_thumb.png", category: .hololive, status: nil, accent: 0x975E8D, secondaryAccent: 0x83333B),
        .init(name: "Aki Rosenthal", japaneseName: "アキ・ローゼンタール", portraitFileName: "Aki-Rosenthal_list_thumb.png", category: .hololive, status: nil, accent: 0xDD0C88, secondaryAccent: 0x6B80D3),
        .init(name: "Akai Haato", japaneseName: "赤井はあと", portraitFileName: "Akai-Haato_list_thumb.png", category: .hololive, status: nil, accent: 0xDB1032, secondaryAccent: 0x3E70B7),
        .init(name: "Shirakami Fubuki", japaneseName: "白上フブキ", portraitFileName: "Shirakami-Fubuki_list_thumb.png", category: .hololive, status: nil, accent: 0x57C8EA, secondaryAccent: 0x272534),
        .init(name: "Natsuiro Matsuri", japaneseName: "夏色まつり", portraitFileName: "Natsuiro-Matsuri_list_thumb.png", category: .hololive, status: nil, accent: 0xE8A045, secondaryAccent: 0xA3D54D),
        .init(name: "Nakiri Ayame", japaneseName: "百鬼あやめ", portraitFileName: "Nakiri-Ayame_list_thumb.png", category: .hololive, status: nil, accent: 0xDB3248, secondaryAccent: 0xDEB162),
        .init(name: "Yuzuki Choco", japaneseName: "癒月ちょこ", portraitFileName: "Yuzuki-Choco_list_thumb.png", category: .hololive, status: nil, accent: 0xDE5B88, secondaryAccent: 0xDDAA86),
        .init(name: "Oozora Subaru", japaneseName: "大空スバル", portraitFileName: "Oozora-Subaru_list_thumb.png", category: .hololive, status: nil, accent: 0xC3E623, secondaryAccent: 0xD45D46),
        .init(name: "AZKi", japaneseName: "AZKi", portraitFileName: "AZKi_list_thumb.png", category: .hololive, status: nil, accent: 0xE42C82, secondaryAccent: 0xD8A19B),
        .init(name: "Ookami Mio", japaneseName: "大神ミオ", portraitFileName: "Ookami-Mio_thumb.png", category: .hololive, status: nil, accent: 0xDA1D37, secondaryAccent: 0xDC8C5C),
        .init(name: "Sakura Miko", japaneseName: "さくらみこ", portraitFileName: "Sakura-Miko_list_thumb.png", category: .hololive, status: nil, accent: 0xE36071, secondaryAccent: 0xEDBE76),
        .init(name: "Nekomata Okayu", japaneseName: "猫又おかゆ", portraitFileName: "Nekomata-Okayu_list_thumb.png", category: .hololive, status: nil, accent: 0xBE67E6, secondaryAccent: 0xE5AEA1),
        .init(name: "Inugami Korone", japaneseName: "戌神ころね", portraitFileName: "Inugami-Korone_list_thumb.png", category: .hololive, status: nil, accent: 0xDEB618, secondaryAccent: 0x935D56),
        .init(name: "Hoshimachi Suisei", japaneseName: "星街すいせい", portraitFileName: "Hoshimachi-Suisei_list_thumb.png", category: .hololive, status: nil, accent: 0x43DBF0, secondaryAccent: 0x262577),
        .init(name: "Usada Pekora", japaneseName: "兎田ぺこら", portraitFileName: "Usada-Pekora_list_thumb.png", category: .hololive, status: nil, accent: 0x6ABBE9, secondaryAccent: 0xDD7B41),
        .init(name: "Shiranui Flare", japaneseName: "不知火フレア", portraitFileName: "Shiranui-Flare_list_thumb.png", category: .hololive, status: nil, accent: 0xDD3D19, secondaryAccent: 0x4690BE),
        .init(name: "Shirogane Noel", japaneseName: "白銀ノエル", portraitFileName: "Shirogane-Noel_list_thumb.png", category: .hololive, status: nil, accent: 0x7A5E4B, secondaryAccent: 0x293341),
        .init(name: "Houshou Marine", japaneseName: "宝鐘マリン", portraitFileName: "Houshou-Marine_list_thumb.png", category: .hololive, status: nil, accent: 0xC73E2B, secondaryAccent: 0xCCA86E),
        .init(name: "Tsunomaki Watame", japaneseName: "角巻わため", portraitFileName: "Tsunomaki-Watame_list_thumb.png", category: .hololive, status: nil, accent: 0xE2DD91, secondaryAccent: 0xD57F88),
        .init(name: "Tokoyami Towa", japaneseName: "常闇トワ", portraitFileName: "Tokoyami-Towa_list_thumb.png", category: .hololive, status: nil, accent: 0xA8A3EA, secondaryAccent: 0xE65393),
        .init(name: "Himemori Luna", japaneseName: "姫森ルーナ", portraitFileName: "Himemori-Luna_list_thumb.png", category: .hololive, status: nil, accent: 0xDE77B3, secondaryAccent: 0x91AED7),
        .init(name: "Yukihana Lamy", japaneseName: "雪花ラミィ", portraitFileName: "Yukihana-Lamy_list_thumb.png", category: .hololive, status: nil, accent: 0x60C1ED, secondaryAccent: 0x72503D),
        .init(name: "Momosuzu Nene", japaneseName: "桃鈴ねね", portraitFileName: "Momosuzu-Nene_list_thumb.png", category: .hololive, status: nil, accent: 0xE69055, secondaryAccent: 0xEC9FAA),
        .init(name: "Shishiro Botan", japaneseName: "獅白ぼたん", portraitFileName: "Shishiro-Botan_list_thumb.png", category: .hololive, status: nil, accent: 0x78D6B4, secondaryAccent: 0x2A2534),
        .init(name: "Omaru Polka", japaneseName: "尾丸ポルカ", portraitFileName: "Omaru-Polka_list_thumb.png", category: .hololive, status: nil, accent: 0xCD282F, secondaryAccent: 0xD7B77F),
        .init(name: "La+ Darknesss", japaneseName: "ラプラス・ダークネス", portraitFileName: "La-Darknesss_list_thumb.png", category: .hololive, status: nil, accent: 0x471B90, secondaryAccent: 0xE8AF5D),
        .init(name: "Takane Lui", japaneseName: "鷹嶺ルイ", portraitFileName: "Takane-Lui_list_thumb.png", category: .hololive, status: nil, accent: 0x831550, secondaryAccent: 0xDB9695),
        .init(name: "Hakui Koyori", japaneseName: "博衣こより", portraitFileName: "Hakui-Koyori_list_thumb.png", category: .hololive, status: nil, accent: 0xE197B5, secondaryAccent: 0x62D6CA),
        .init(name: "Kazama Iroha", japaneseName: "風真いろは", portraitFileName: "Kazama-Iroha_list_thumb.png", category: .hololive, status: nil, accent: 0x68CBC5, secondaryAccent: 0xCEAF73),
        .init(name: "Sakamata Chloe", japaneseName: "沙花叉クロヱ", portraitFileName: "Sakamata-Chloe_list_thumb.png", category: .hololive, status: .affiliate, accent: 0xC03331, secondaryAccent: 0x927F3F),
        .init(name: "Ayunda Risu", japaneseName: "アユンダ・リス", portraitFileName: "Ayunda-Risu_list_thumb.png", category: .indonesia, status: nil, accent: 0xED9896, secondaryAccent: 0xD7A666),
        .init(name: "Moona Hoshinova", japaneseName: "ムーナ・ホシノヴァ", portraitFileName: "Moona-Hoshinova_list_thumb.png", category: .indonesia, status: nil, accent: 0x9070CA, secondaryAccent: 0xDCC692),
        .init(name: "Airani Iofifteen", japaneseName: "アイラニ・イオフィフティーン", portraitFileName: "Airani-Iofifteen_list_thumb.png", category: .indonesia, status: nil, accent: 0x9DE83A, secondaryAccent: 0x344262),
        .init(name: "Kureiji Ollie", japaneseName: "クレイジー・オリー", portraitFileName: "Kureiji-Ollie_list_thumb.png", category: .indonesia, status: nil, accent: 0xD60F52, secondaryAccent: 0x263240),
        .init(name: "Anya Melfissa", japaneseName: "アーニャ・メルフィッサ", portraitFileName: "Anya-Melfissa_list_thumb.png", category: .indonesia, status: nil, accent: 0xEAAE31, secondaryAccent: 0x987470),
        .init(name: "Pavolia Reine", japaneseName: "パヴォリア・レイネ", portraitFileName: "Pavolia-Reine_list_thumb.png", category: .indonesia, status: nil, accent: 0x1052B9, secondaryAccent: 0x6AC4B5),
        .init(name: "Vestia Zeta", japaneseName: "ベスティア・ゼータ", portraitFileName: "Vestia-Zeta_list_thumb.png", category: .indonesia, status: nil, accent: 0x7787C8, secondaryAccent: 0xCE9485),
        .init(name: "Kaela Kovalskia", japaneseName: "カエラ・コヴァルスキア", portraitFileName: "Kaela-Kovalskia_list_thumb.png", category: .indonesia, status: nil, accent: 0xDC2529, secondaryAccent: 0xDDA94F),
        .init(name: "Kobo Kanaeru", japaneseName: "こぼ・かなえる", portraitFileName: "Kobo-Kanaeru_list_thumb.png", category: .indonesia, status: nil, accent: 0x393464, secondaryAccent: 0x84B0CF),
        .init(name: "Mori Calliope", japaneseName: "森カリオペ", portraitFileName: "Mori-Calliope_list_thumb.png", category: .english, status: nil, accent: 0xCA1647, secondaryAccent: 0x7D5A47),
        .init(name: "Takanashi Kiara", japaneseName: "小鳥遊キアラ", portraitFileName: "Takanashi-Kiara_list_thumb.png", category: .english, status: nil, accent: 0xDB4017, secondaryAccent: 0x3F4B8B),
        .init(name: "Ninomae Ina’nis", japaneseName: "一伊那尓栖", portraitFileName: "Ninomae-Inanis_list_thumb.png", category: .english, status: nil, accent: 0xD6936A, secondaryAccent: 0x564969),
        .init(name: "Watson Amelia", japaneseName: "ワトソン・アメリア", portraitFileName: "Watson-Amelia_list_thumb.png", category: .english, status: .affiliate, accent: 0xF4CB64, secondaryAccent: 0x895952),
        .init(name: "IRyS", japaneseName: "IRyS", portraitFileName: "IRyS_list_thumb.png", category: .english, status: nil, accent: 0xDB0F5B, secondaryAccent: 0xA27AB7),
        .init(name: "Ouro Kronii", japaneseName: "オーロ・クロニー", portraitFileName: "Ouro-Kronii_list_thumb.png", category: .english, status: nil, accent: 0x1E1995, secondaryAccent: 0x86BFDD),
        .init(name: "Hakos Baelz", japaneseName: "ハコス・ベールズ", portraitFileName: "Hakos-Baelz_list_thumb.png", category: .english, status: nil, accent: 0xDB3429, secondaryAccent: 0xD19526),
        .init(name: "Shiori Novella", japaneseName: "シオリ・ノヴェラ", portraitFileName: "Shiori-Novella_list_thumb.png", category: .english, status: nil, accent: 0x8E82AF, secondaryAccent: 0xDA9D9A),
        .init(name: "Koseki Bijou", japaneseName: "古石ビジュー", portraitFileName: "Koseki-Bijou_list_thumb.png", category: .english, status: nil, accent: 0x5E50E8, secondaryAccent: 0x7D4B5E),
        .init(name: "Nerissa Ravencroft", japaneseName: "ネリッサ・レイヴンクロフト", portraitFileName: "Nerissa-Ravencroft_list_thumb.png", category: .english, status: nil, accent: 0x222DB8, secondaryAccent: 0x2E627D),
        .init(name: "Fuwawa Abyssgard", japaneseName: "フワワ・アビスガード", portraitFileName: "Fuwawa-Abyssgard_list_thumb.png", category: .english, status: nil, accent: 0x4393DD, secondaryAccent: 0xE9B7AB),
        .init(name: "Mococo Abyssgard", japaneseName: "モココ・アビスガード", portraitFileName: "Mococo-Abyssgard_list_thumb.png", category: .english, status: nil, accent: 0xF39FC4, secondaryAccent: 0xB69977),
        .init(name: "Elizabeth Rose Bloodflame", japaneseName: "エリザベス・ローズ・ブラッドフレイム", portraitFileName: "Elizabeth-Rose-Bloodflame_list_thumb.png", category: .english, status: nil, accent: 0xC4383B, secondaryAccent: 0x7A83BA),
        .init(name: "Gigi Murin", japaneseName: "ジジ・ムリン", portraitFileName: "Gigi-Murin_list_thumb.png", category: .english, status: nil, accent: 0xE09C35, secondaryAccent: 0xC50D1A),
        .init(name: "Cecilia Immergreen", japaneseName: "セシリア・イマーグリーン", portraitFileName: "Cecilia-Immergreen_list_thumb.png", category: .english, status: nil, accent: 0x13985C, secondaryAccent: 0x8E735F),
        .init(name: "Raora Panthera", japaneseName: "ラオーラ・パンテーラ", portraitFileName: "Raora-Panthera_list_thumb.png", category: .english, status: nil, accent: 0xDF6991, secondaryAccent: 0x5B6C85),
        .init(name: "Otonose Kanade", japaneseName: "音乃瀬奏", portraitFileName: "Otonose-Kanade_list_thumb.png", category: .devIs, status: nil, accent: 0xF5C76B, secondaryAccent: 0xE39386),
        .init(name: "Ichijou Ririka", japaneseName: "一条莉々華", portraitFileName: "Ichijou-Ririka_list_thumb.png", category: .devIs, status: nil, accent: 0xEE6294, secondaryAccent: 0xD7A081),
        .init(name: "Juufuutei Raden", japaneseName: "儒烏風亭らでん", portraitFileName: "Juufuutei-Raden_list_thumb.png", category: .devIs, status: nil, accent: 0x2E6F62, secondaryAccent: 0x3C384A),
        .init(name: "Todoroki Hajime", japaneseName: "轟はじめ", portraitFileName: "Todoroki-Hajime_list_thumb.png", category: .devIs, status: nil, accent: 0xA09DED, secondaryAccent: 0xE2A19B),
        .init(name: "Isaki Riona", japaneseName: "響咲リオナ", portraitFileName: "Isaki-Riona_list_thumb.png", category: .devIs, status: nil, accent: 0xCC2D5F, secondaryAccent: 0x865C7F),
        .init(name: "Koganei Niko", japaneseName: "虎金妃笑虎", portraitFileName: "Koganei-Niko_list_thumb.png", category: .devIs, status: nil, accent: 0xEC711E, secondaryAccent: 0x272E3B),
        .init(name: "Mizumiya Su", japaneseName: "水宮枢", portraitFileName: "Mizumiya-Su_list_thumb.png", category: .devIs, status: nil, accent: 0x6BCEE5, secondaryAccent: 0xCE8A85),
        .init(name: "Rindo Chihaya", japaneseName: "輪堂千速", portraitFileName: "Rindo-Chihaya_list_thumb.png", category: .devIs, status: nil, accent: 0x37BABA, secondaryAccent: 0xD3A2A0),
        .init(name: "Kikirara Vivi", japaneseName: "綺々羅々ヴィヴィ", portraitFileName: "Kikirara-Vivi_list_thumb.png", category: .devIs, status: nil, accent: 0xE355A1, secondaryAccent: 0xA47DEB),
        .init(name: "Izuki Michiru", japaneseName: "井月みちる", portraitFileName: "Izuki-Michiru_list_thumb.png", category: .holoAN, status: nil, accent: 0xC6457A, secondaryAccent: 0xCCB185),
        .init(name: "Hanazono Sayaka", japaneseName: "花園さやか", portraitFileName: "Hanazono-Sayaka_list_thumb.png", category: .holoAN, status: nil, accent: 0xE7C680, secondaryAccent: 0x896964),
        .init(name: "Kazeshiro Yuki", japaneseName: "風白ゆき", portraitFileName: "Hanazono-Sayaka_list_thumb-1.png", category: .holoAN, status: nil, accent: 0x88BCE5, secondaryAccent: 0x5F5786),
        .init(name: "Minato Aqua", japaneseName: "湊あくあ", portraitFileName: "Minato-Aqua_list_thumb.png", category: .alumni, status: .alumni, accent: 0xDC86BF, secondaryAccent: 0x434789),
        .init(name: "Murasaki Shion", japaneseName: "紫咲シオン", portraitFileName: "Murasaki-Shion_list_thumb.png", category: .alumni, status: .alumni, accent: 0xAC6CDF, secondaryAccent: 0x5B597F),
        .init(name: "Amane Kanata", japaneseName: "天音かなた", portraitFileName: "Amane-Kanata_list_thumb.png", category: .alumni, status: .alumni, accent: 0x77BDE7, secondaryAccent: 0xCDAF7D),
        .init(name: "Kiryu Coco", japaneseName: "桐生ココ", portraitFileName: "Kiryu-Coco_list_thumb.png", category: .alumni, status: .alumni, accent: 0xDA751F, secondaryAccent: 0xBD2E3B),
        .init(name: "Gawr Gura", japaneseName: "がうる・ぐら", portraitFileName: "Gawr-Gura_list_thumb.png", category: .alumni, status: .alumni, accent: 0x4E76BD, secondaryAccent: 0xBC4449),
        .init(name: "Tsukumo Sana", japaneseName: "九十九佐命", portraitFileName: "Tsukumo-Sana_list_thumb.png", category: .alumni, status: .alumni, accent: 0xD19A74, secondaryAccent: 0xD482AA),
        .init(name: "Ceres Fauna", japaneseName: "セレス・ファウナ", portraitFileName: "Ceres-Fauna_list_thumb.png", category: .alumni, status: .alumni, accent: 0x38CA69, secondaryAccent: 0xDDB578),
        .init(name: "Nanashi Mumei", japaneseName: "七詩ムメイ", portraitFileName: "Nanashi-Mumei_list_thumb.png", category: .alumni, status: .alumni, accent: 0xC19576, secondaryAccent: 0x132B36),
        .init(name: "Hiodoshi Ao", japaneseName: "火威青", portraitFileName: "Hiodoshi-Ao_list_thumb.png", category: .alumni, status: .alumni, accent: 0x1F3667, secondaryAccent: 0xD4A196),
        .init(name: "Harusaki Nodoka", japaneseName: "春先のどか", portraitFileName: "Harusaki-Nodoka_list_thumb.png", category: .alumni, status: .retired, accent: 0xCEE4A2, secondaryAccent: 0xC1A092),
        .init(name: "Friend A (A-chan)", japaneseName: "友人A（えーちゃん）", portraitFileName: "Friend-A_list_thumb.png", category: .alumni, status: .retired, accent: 0x343171, secondaryAccent: 0xECAEA1),
    ]
}

private struct TalentPalette: Hashable {
    let accent: UInt32
    let secondaryAccent: UInt32

    func colors(for scheme: ColorScheme) -> ThemeColors {
        if scheme == .dark {
            let background = accent.mixed(with: 0x000000, amount: 0.88)
            let surface = accent.mixed(with: 0x000000, amount: 0.72)
            return ThemeColors(
                background: background,
                surface: surface,
                primaryText: accent.mixed(with: 0xFFFFFF, amount: 0.92),
                secondaryText: secondaryAccent.mixed(with: 0xFFFFFF, amount: 0.72),
                accent: accent.adjustedForContrast(against: [background, surface], toward: 0xFFFFFF),
                secondaryAccent: secondaryAccent.adjustedForContrast(against: [background, surface], toward: 0xFFFFFF)
            )
        }

        let background = accent.mixed(with: 0xFFFFFF, amount: 0.96)
        let surface = accent.mixed(with: 0xFFFFFF, amount: 0.88)
        return ThemeColors(
            background: background,
            surface: surface,
            primaryText: accent.mixed(with: 0x101015, amount: 0.82),
            secondaryText: secondaryAccent.mixed(with: 0x34323A, amount: 0.72),
            accent: accent.adjustedForContrast(against: [background, surface], toward: 0x000000),
            secondaryAccent: secondaryAccent.adjustedForContrast(against: [background, surface], toward: 0x000000)
        )
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

private extension UInt32 {
    func mixed(with other: UInt32, amount: Double) -> UInt32 {
        let amount = Swift.min(Swift.max(amount, 0), 1)
        let red = component(shift: 16) * (1 - amount) + other.component(shift: 16) * amount
        let green = component(shift: 8) * (1 - amount) + other.component(shift: 8) * amount
        let blue = component(shift: 0) * (1 - amount) + other.component(shift: 0) * amount
        return UInt32((red * 255).rounded()) << 16
            | UInt32((green * 255).rounded()) << 8
            | UInt32((blue * 255).rounded())
    }

    func adjustedForContrast(against backgrounds: [UInt32], toward target: UInt32) -> UInt32 {
        var candidate = self
        var amount = 0.0
        while backgrounds.contains(where: { candidate.contrastRatio(with: $0) < 4.5 }), amount < 1 {
            amount += 0.04
            candidate = mixed(with: target, amount: amount)
        }
        return candidate
    }

    func contrastRatio(with other: UInt32) -> Double {
        let lighter = Swift.max(relativeLuminance, other.relativeLuminance)
        let darker = Swift.min(relativeLuminance, other.relativeLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    var relativeLuminance: Double {
        func linear(_ value: Double) -> Double {
            value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(component(shift: 16))
            + 0.7152 * linear(component(shift: 8))
            + 0.0722 * linear(component(shift: 0))
    }

    func component(shift: UInt32) -> Double {
        Double((self >> shift) & 0xFF) / 255
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
