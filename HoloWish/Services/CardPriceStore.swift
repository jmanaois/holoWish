import Foundation
import Observation

struct YuyuteiPriceQuote: Codable, Hashable, Identifiable, Sendable {
    let cardNumber: String
    let rarity: String
    let title: String
    let priceYen: Int
    let inStock: Bool
    let url: URL

    var id: String { url.absoluteString }
}

struct CardPriceResult: Codable, Sendable {
    let fetchedAt: Date
    let quotes: [YuyuteiPriceQuote]
}

@MainActor
@Observable
final class CardPriceStore {
    nonisolated private static let freshnessInterval: TimeInterval = 12 * 60 * 60

    private(set) var results: [String: CardPriceResult] = [:]
    private(set) var loadingNumbers: Set<String> = []
    private(set) var errors: [String: String] = [:]

    func result(for card: Card) -> CardPriceResult? { results[key(for: card)] }
    func isLoading(_ card: Card) -> Bool { loadingNumbers.contains(key(for: card)) }
    func error(for card: Card) -> String? { errors[key(for: card)] }

    func lookup(_ card: Card, force: Bool = false) async {
        let key = key(for: card)
        guard !loadingNumbers.contains(key) else { return }
        errors[key] = nil

        if !force, let result = results[key], Self.isFresh(result) { return }
        if !force, let cached = await Self.readCache(for: key), Self.isFresh(cached) {
            results[key] = Self.sorted(cached, currentRarity: card.rarity)
            return
        }

        loadingNumbers.insert(key)
        defer { loadingNumbers.remove(key) }
        do {
            let result = try await Self.fetch(cardNumber: card.number, currentRarity: card.rarity)
            results[key] = result
            await Self.writeCache(result, for: key)
        } catch {
            errors[key] = "Price lookup is temporarily unavailable."
        }
    }

    func searchURL(for card: Card) -> URL {
        Self.searchURL(cardNumber: card.number)
    }

    private func key(for card: Card) -> String { card.number.localizedLowercase }

    nonisolated private static func isFresh(_ result: CardPriceResult) -> Bool {
        Date().timeIntervalSince(result.fetchedAt) < freshnessInterval
    }

    nonisolated private static func sorted(_ result: CardPriceResult, currentRarity: String) -> CardPriceResult {
        CardPriceResult(fetchedAt: result.fetchedAt, quotes: result.quotes.sorted {
            let leftMatches = $0.rarity.caseInsensitiveCompare(currentRarity) == .orderedSame
            let rightMatches = $1.rarity.caseInsensitiveCompare(currentRarity) == .orderedSame
            if leftMatches != rightMatches { return leftMatches }
            return $0.priceYen > $1.priceYen
        })
    }

    nonisolated private static func fetch(cardNumber: String, currentRarity: String) async throws -> CardPriceResult {
        var request = URLRequest(url: searchURL(cardNumber: cardNumber), cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        request.setValue("ja-JP,ja;q=0.9,en-US;q=0.8", forHTTPHeaderField: "Accept-Language")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              let html = String(data: data, encoding: .utf8) else { throw PriceLookupError.invalidResponse }
        let quotes = await Task.detached(priority: .utility) {
            parse(html: html, exactCardNumber: cardNumber)
        }.value
        return sorted(CardPriceResult(fetchedAt: Date(), quotes: quotes), currentRarity: currentRarity)
    }

    nonisolated private static func searchURL(cardNumber: String) -> URL {
        var components = URLComponents(string: "https://yuyu-tei.jp/sell/hocg/s/search")!
        components.queryItems = [URLQueryItem(name: "search_word", value: cardNumber)]
        return components.url!
    }

    nonisolated private static func parse(html: String, exactCardNumber: String) -> [YuyuteiPriceQuote] {
        let pattern = #"<a\s+href=\"(https://yuyu-tei\.jp/sell/hocg/card/[^\"]+)\"><div\s+class=\"position-relative product-img\">\s*<img[^>]+alt=\"([^\"]+)\"[^>]+class=\"card img-fluid\"[^>]*>[\s\S]*?<strong[^>]*>\s*([\d,]+)\s*円\s*</strong>[\s\S]*?<label[^>]+cart_sell_zaiko[^>]*>\s*在庫\s*:\s*([◯×])"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        var seen: Set<String> = []
        return regex.matches(in: html, range: range).compactMap { match in
            guard let urlText = substring(html, match.range(at: 1)),
                  let alt = substring(html, match.range(at: 2)),
                  let priceText = substring(html, match.range(at: 3)),
                  let stockText = substring(html, match.range(at: 4)),
                  let url = URL(string: urlText) else { return nil }
            let parts = decodeEntities(alt).split(maxSplits: 2, whereSeparator: \.isWhitespace).map(String.init)
            guard parts.count == 3,
                  parts[0].caseInsensitiveCompare(exactCardNumber) == .orderedSame,
                  let price = Int(priceText.replacingOccurrences(of: ",", with: "")),
                  seen.insert(url.absoluteString).inserted else { return nil }
            return YuyuteiPriceQuote(
                cardNumber: parts[0], rarity: parts[1], title: parts[2],
                priceYen: price, inStock: stockText == "◯", url: url
            )
        }
    }

    nonisolated private static func substring(_ value: String, _ range: NSRange) -> String? {
        guard let range = Range(range, in: value) else { return nil }
        return String(value[range])
    }

    nonisolated private static func decodeEntities(_ value: String) -> String {
        value.replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
    }

    nonisolated private static func readCache(for key: String) async -> CardPriceResult? {
        await Task.detached(priority: .utility) {
            guard let data = try? Data(contentsOf: cacheURL(for: key), options: .mappedIfSafe) else { return nil }
            return try? JSONDecoder().decode(CardPriceResult.self, from: data)
        }.value
    }

    nonisolated private static func writeCache(_ result: CardPriceResult, for key: String) async {
        await Task.detached(priority: .utility) {
            let url = cacheURL(for: key)
            guard let data = try? JSONEncoder().encode(result) else { return }
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: url, options: .atomic)
        }.value
    }

    nonisolated private static func cacheURL(for key: String) -> URL {
        let safeKey = key.replacingOccurrences(of: "/", with: "-")
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "HoloWish/Prices", directoryHint: .isDirectory)
            .appending(path: "\(safeKey).json")
    }
}

private enum PriceLookupError: Error { case invalidResponse }
