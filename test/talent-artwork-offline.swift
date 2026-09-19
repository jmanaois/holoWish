// Compile with TalentArtworkStore.swift for an iOS simulator and run with simctl spawn.
// Uses a stub catalog and intercepted requests; no official artwork is downloaded.
import Foundation
import UIKit

struct TestArtworkRecord { let artworkURLs: [URL] }
enum TalentArtworkCatalog {
    static let recordsByName = ["Test": TestArtworkRecord(artworkURLs: [
        URL(string: "https://outfit-test.invalid/one.png")!,
        URL(string: "https://outfit-test.invalid/two.png")!
    ])]
}

final class StubProtocol: URLProtocol, @unchecked Sendable {
    static let state = NetworkState()
    final class NetworkState: @unchecked Sendable {
        let lock = NSLock()
        private var offline = false
        private var failSecond = true
        private var requests = 0
        func configure(offline: Bool, failSecond: Bool = false) {
            lock.lock(); defer { lock.unlock() }
            self.offline = offline; self.failSecond = failSecond
        }
        func response(for url: URL) -> (Bool, Bool) {
            lock.lock(); defer { lock.unlock() }
            requests += 1
            return (offline, failSecond && url.lastPathComponent == "two.png")
        }
        var count: Int { lock.lock(); defer { lock.unlock() }; return requests }
    }
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "outfit-test.invalid" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let (offline, badImage) = Self.state.response(for: request.url!)
        if offline {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        let png = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1sAAAAASUVORK5CYII=")!
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: badImage ? Data("not an image".utf8) : png)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@main struct OfflineArtworkCheck {
    @MainActor static func wait(_ store: TalentArtworkStore) async throws {
        for _ in 0..<1000 {
            if !store.isDownloading { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        fatalError("Download failed to finish")
    }
    @MainActor static func main() async throws {
        URLProtocol.registerClass(StubProtocol.self)
        let store = TalentArtworkStore()
        await store.clearDownloadedArtwork()
        store.beginDownloading()
        store.beginDownloading() // Must not launch a duplicate sweep.
        try await wait(store)
        precondition(store.downloadedCount == 1 && store.failedCount == 1, "downloaded=\(store.downloadedCount), failed=\(store.failedCount), requests=\(StubProtocol.state.count), directory=\(FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask))")
        precondition(StubProtocol.state.count == 2)
        StubProtocol.state.configure(offline: false)
        store.beginDownloading()
        try await wait(store)
        precondition(store.downloadedCount == 2 && store.failedCount == 0)
        precondition(StubProtocol.state.count == 3, "Retry must skip saved outfits")
        StubProtocol.state.configure(offline: true)
        let reopened = TalentArtworkStore()
        reopened.beginDownloading()
        try await wait(reopened)
        for url in TalentArtworkCatalog.recordsByName["Test"]!.artworkURLs {
            await reopened.load(url)
            precondition(reopened.image(for: url) != nil, "Offline image failed to decode")
            precondition(reopened.homeImage(for: url) != nil)
        }
        precondition(reopened.downloadedCount == 2)
        precondition(StubProtocol.state.count == 3, "Offline reload must use disk")
        reopened.beginDownloading()
        reopened.pauseDownloading()
        try await wait(reopened)
        await reopened.clearDownloadedArtwork()
        precondition(reopened.downloadedCount == 0)
        reopened.beginDownloading()
        try await wait(reopened)
        precondition(reopened.downloadedCount == 0 && reopened.failedCount == 2)
        print("PASS: bulk download, failure/retry, duplicate start, offline reopen/decode, pause, and clear")
    }
}
