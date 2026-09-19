import Foundation
import ImageIO
import Observation
import UIKit

@MainActor
@Observable
final class TalentArtworkStore {
    private(set) var loadingURLs: Set<URL> = []
    private(set) var revision = 0

    @ObservationIgnored private let memoryCache = NSCache<NSURL, DecodedArtwork>()

    init() {
        memoryCache.countLimit = 18
        memoryCache.totalCostLimit = 96 * 1_024 * 1_024
    }

    func image(for url: URL) -> UIImage? {
        _ = revision
        return memoryCache.object(forKey: url as NSURL)?.image
    }

    func homeImage(for url: URL) -> UIImage? {
        _ = revision
        return memoryCache.object(forKey: url as NSURL)?.homeImage
    }

    func load(_ url: URL) async {
        guard image(for: url) == nil, !loadingURLs.contains(url) else { return }
        loadingURLs.insert(url)
        defer { loadingURLs.remove(url) }

        guard let artwork = await Self.loadImage(remoteURL: url) else { return }
        let cost = [artwork.image, artwork.homeImage].reduce(0) { total, image in
            total + (image.cgImage.map { $0.bytesPerRow * $0.height } ?? 1)
        }
        memoryCache.setObject(artwork, forKey: url as NSURL, cost: cost)
        revision &+= 1
    }

    func clearDownloadedArtwork() async {
        memoryCache.removeAllObjects()
        await Task.detached(priority: .utility) {
            try? FileManager.default.removeItem(at: Self.artworkDirectory)
        }.value
        revision &+= 1
    }

    nonisolated private static func loadImage(remoteURL: URL) async -> DecodedArtwork? {
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

    nonisolated private static func decode(_ data: Data) -> DecodedArtwork? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 1_600,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return DecodedArtwork(image: UIImage(cgImage: image), homeImage: UIImage(cgImage: trimmedImage(image)))
    }

    private final class DecodedArtwork: Sendable {
        let image: UIImage
        let homeImage: UIImage

        init(image: UIImage, homeImage: UIImage) {
            self.image = image
            self.homeImage = homeImage
        }
    }

    // Keep every visible pixel, including faint hair and accessories. Only the
    // Home presentation uses this crop; the showcase retains the source canvas.
    nonisolated private static func trimmedImage(_ image: CGImage) -> CGImage {
        let width = image.width
        let height = image.height
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        let bounds: CGRect? = rgba.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height,
                                          bitsPerComponent: 8, bytesPerRow: width * 4,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                                            | CGBitmapInfo.byteOrder32Big.rawValue) else { return nil }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            let pixels = buffer.bindMemory(to: UInt8.self)
            var minX = width, minY = height, maxX = -1, maxY = -1
            for y in 0..<height {
                for x in 0..<width where pixels[(y * width + x) * 4 + 3] > 0 {
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x)
                    maxY = max(maxY, y)
                }
            }
            guard maxX >= minX, maxY >= minY else { return nil }
            return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
        }
        guard let bounds else { return image }
        return image.cropping(to: bounds) ?? image
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
