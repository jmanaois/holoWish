import Foundation
import ImageIO
import Observation
import UIKit

@MainActor
@Observable
final class TalentArtworkStore {
    private(set) var loadingURLs: Set<URL> = []
    private(set) var revision = 0

    @ObservationIgnored private let memoryCache = NSCache<NSURL, UIImage>()

    init() {
        memoryCache.countLimit = 18
        memoryCache.totalCostLimit = 96 * 1_024 * 1_024
    }

    func image(for url: URL) -> UIImage? {
        _ = revision
        return memoryCache.object(forKey: url as NSURL)
    }

    func load(_ url: URL) async {
        guard image(for: url) == nil, !loadingURLs.contains(url) else { return }
        loadingURLs.insert(url)
        defer { loadingURLs.remove(url) }

        guard let image = await Self.loadImage(remoteURL: url) else { return }
        let cost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? 1
        memoryCache.setObject(image, forKey: url as NSURL, cost: cost)
        revision &+= 1
    }

    func clearDownloadedArtwork() async {
        memoryCache.removeAllObjects()
        await Task.detached(priority: .utility) {
            try? FileManager.default.removeItem(at: Self.artworkDirectory)
        }.value
        revision &+= 1
    }

    nonisolated private static func loadImage(remoteURL: URL) async -> UIImage? {
        let localURL = fileURL(for: remoteURL)
        if let data = try? Data(contentsOf: localURL, options: .mappedIfSafe),
           let image = decode(data) {
            return image
        }

        var request = URLRequest(url: remoteURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 45)
        request.setValue("holoWish/1.0 personal collection app", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200,
              let image = decode(data) else { return nil }

        try? FileManager.default.createDirectory(at: artworkDirectory, withIntermediateDirectories: true)
        try? data.write(to: localURL, options: .atomic)
        return image
    }

    nonisolated private static func decode(_ data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 1_600,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: image)
    }

    nonisolated private static var artworkDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "HoloWish/TalentArtwork", directoryHint: .isDirectory)
    }

    nonisolated private static func fileURL(for remoteURL: URL) -> URL {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in remoteURL.absoluteString.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        let fileName = "\(String(hash, radix: 16))-\(remoteURL.lastPathComponent)"
        return artworkDirectory.appending(path: fileName)
    }
}
