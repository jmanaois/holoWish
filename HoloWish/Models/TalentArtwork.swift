import Foundation

struct TalentArtworkCatalogPayload: Decodable {
    let source: URL
    let records: [TalentArtworkRecord]
}

struct TalentArtworkRecord: Decodable, Hashable {
    let name: String
    let japaneseName: String
    let profileURL: URL
    let artworkURLs: [URL]
}

enum TalentArtworkCatalog {
    static let recordsByName: [String: TalentArtworkRecord] = {
        guard let url = Bundle.main.url(forResource: "talent-artwork", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(TalentArtworkCatalogPayload.self, from: data) else {
            return [:]
        }
        return Dictionary(uniqueKeysWithValues: payload.records.map { ($0.name, $0) })
    }()

    static func record(for theme: AppTheme) -> TalentArtworkRecord? {
        recordsByName[theme.rawValue]
    }
}

extension Card {
    func belongs(to theme: AppTheme) -> Bool {
        name == theme.japaneseName || displayEnglishName == theme.rawValue
    }
}

