import Foundation
import ImageIO
import Observation
import UIKit

@MainActor
@Observable
final class CardArtworkStore {
    private(set) var downloadedCount = 0
    private(set) var totalCount = 0
    private(set) var isDownloading = false
    private(set) var failedCount = 0

    @ObservationIgnored private let memoryCache = NSCache<NSNumber, UIImage>()
    @ObservationIgnored private let productMemoryCache = NSCache<NSString, UIImage>()
    @ObservationIgnored private var downloadTask: Task<Void, Never>?

    init() {
        memoryCache.countLimit = 100
        memoryCache.totalCostLimit = 96 * 1_024 * 1_024
        productMemoryCache.countLimit = 40
        productMemoryCache.totalCostLimit = 24 * 1_024 * 1_024
    }

    var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(downloadedCount) / Double(totalCount)
    }

    func beginDownloading(_ cards: [Card]) {
        guard !cards.isEmpty, downloadTask == nil else { return }
        totalCount = cards.filter { $0.image != nil }.count
        downloadTask = Task(priority: .background) { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { self?.downloadTask = nil; return }
            await self?.downloadMissingArtwork(cards)
            self?.downloadTask = nil
        }
    }

    func pauseDownloading() {
        downloadTask?.cancel()
        downloadTask = nil
        isDownloading = false
    }

    func image(for card: Card) async -> UIImage? {
        let key = NSNumber(value: card.id)
        if let cached = memoryCache.object(forKey: key) { return cached }
        guard let remoteURL = card.image else { return nil }
        let fileURL = Self.fileURL(for: card)

        if let data = await Self.readData(from: fileURL),
           let image = await Self.decodeThumbnail(data) {
            cache(image, for: key)
            return image
        }

        guard !Task.isCancelled,
              let data = try? await Self.download(remoteURL, to: fileURL),
              let image = await Self.decodeThumbnail(data) else { return nil }
        cache(image, for: key)
        downloadedCount = min(totalCount, downloadedCount + 1)
        return image
    }

    func image(for set: CardSetSummary) async -> UIImage? {
        guard let remoteURL = set.productImage else { return nil }
        let key = NSString(string: set.productCode ?? set.name)
        if let cached = productMemoryCache.object(forKey: key) { return cached }
        let fileURL = Self.fileURL(for: set)

        let data: Data?
        if let localData = await Self.readData(from: fileURL) { data = localData }
        else { data = try? await Self.download(remoteURL, to: fileURL) }
        guard !Task.isCancelled, let data, let image = await Self.decodeThumbnail(data) else { return nil }
        let cost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? 1
        productMemoryCache.setObject(image, forKey: key, cost: cost)
        return image
    }

    private func cache(_ image: UIImage, for key: NSNumber) {
        let cost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? 1
        memoryCache.setObject(image, forKey: key, cost: cost)
    }

    private func downloadMissingArtwork(_ cards: [Card]) async {
        isDownloading = true
        failedCount = 0
        let scan = await Self.scan(cards)
        downloadedCount = scan.downloaded
        guard !scan.missing.isEmpty, !Task.isCancelled else { isDownloading = false; return }

        var reportedDownloaded = scan.downloaded
        var reportedFailures = 0
        var unreportedResults = 0
        var iterator = scan.missing.makeIterator()
        await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<min(2, scan.missing.count) {
                if let card = iterator.next() { group.addTask(priority: .background) { await Self.downloadCard(card) } }
            }
            while let succeeded = await group.next() {
                guard !Task.isCancelled else { group.cancelAll(); break }
                if succeeded { reportedDownloaded += 1 } else { reportedFailures += 1 }
                unreportedResults += 1

                // Publish progress in batches instead of invalidating SwiftUI for every file.
                if unreportedResults >= 20 {
                    downloadedCount = min(totalCount, reportedDownloaded)
                    failedCount = reportedFailures
                    unreportedResults = 0
                }

                if let card = iterator.next() {
                    group.addTask(priority: .background) { await Self.downloadCard(card) }
                }
            }
        }
        downloadedCount = min(totalCount, reportedDownloaded)
        failedCount = reportedFailures
        isDownloading = false
    }

    nonisolated private static func scan(_ cards: [Card]) async -> (downloaded: Int, missing: [Card]) {
        await Task.detached(priority: .utility) {
            let available = cards.filter { $0.image != nil }
            let missing = available.filter { !FileManager.default.fileExists(atPath: fileURL(for: $0).path) }
            return (available.count - missing.count, missing)
        }.value
    }

    nonisolated private static func readData(from url: URL) async -> Data? {
        await Task.detached(priority: .userInitiated) { try? Data(contentsOf: url, options: .mappedIfSafe) }.value
    }

    nonisolated private static func decodeThumbnail(_ data: Data) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 1_200,
                kCGImageSourceShouldCacheImmediately: true
            ]
            guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
            return UIImage(cgImage: image)
        }.value
    }

    nonisolated private static func downloadCard(_ card: Card) async -> Bool {
        guard let remoteURL = card.image else { return false }
        let destination = fileURL(for: card)
        if FileManager.default.fileExists(atPath: destination.path) { return true }
        do {
            _ = try await download(remoteURL, to: destination)
            return true
        } catch {
            return false
        }
    }

    nonisolated private static func download(_ remoteURL: URL, to fileURL: URL) async throws -> Data {
        var request = URLRequest(url: remoteURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 45)
        request.setValue("holoWish/1.0 personal collection app", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              CGImageSourceCreateWithData(data as CFData, nil) != nil else { throw ArtworkError.invalidImage }
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: fileURL, options: .atomic)
        return data
    }

    nonisolated private static func fileURL(for card: Card) -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "HoloWish/Artwork", directoryHint: .isDirectory)
        let remoteName = card.image?.lastPathComponent.replacingOccurrences(of: "/", with: "-") ?? "card.img"
        return base.appending(path: "\(card.id)-\(remoteName)")
    }


    nonisolated private static func fileURL(for set: CardSetSummary) -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "HoloWish/ProductArtwork", directoryHint: .isDirectory)
        let remoteName = set.productImage?.lastPathComponent ?? "product.png"
        let key = set.productCode ?? set.name.replacingOccurrences(of: "/", with: "-")
        return base.appending(path: "\(key)-\(remoteName)")
    }
}

private enum ArtworkError: Error { case invalidImage }
