import CryptoKit
import Foundation
import UIKit

actor PatchworkImageCache {
    enum VariantPreference: String, CaseIterable, Hashable {
        case thumb
        case display
        case large
    }

    struct PrefetchRequest: Hashable {
        let asset: RemoteImageAsset?
        let preferredVariant: VariantPreference
        let legacyURL: String?

        init(
            asset: RemoteImageAsset?,
            preferredVariant: VariantPreference = .display,
            legacyURL: String? = nil
        ) {
            self.asset = asset
            self.preferredVariant = preferredVariant
            self.legacyURL = legacyURL
        }
    }

    static let shared = PatchworkImageCache()

    private let memoryCache = NSCache<NSString, NSData>()
    private let diskDirectoryURL: URL
    private let fileManager: FileManager
    private let urlSession: URLSession

    init(
        fileManager: FileManager = .default,
        urlSession: URLSession = .shared,
        diskDirectoryURL: URL? = nil,
        memoryCountLimit: Int = 200
    ) {
        self.fileManager = fileManager
        self.urlSession = urlSession

        let defaultDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("PatchworkImageCache", isDirectory: true)
        self.diskDirectoryURL = diskDirectoryURL ?? defaultDirectory ?? URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("PatchworkImageCache", isDirectory: true)

        memoryCache.countLimit = memoryCountLimit

        do {
            try fileManager.createDirectory(
                at: self.diskDirectoryURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            // Ignore directory-creation failures and keep in-memory caching available.
        }
    }

    static func cacheKey(asset: RemoteImageAsset, variant: VariantPreference) -> String {
        "asset:\(asset.cacheKey):\(variant.rawValue)"
    }

    static func cacheKey(legacyURL: String, variant: VariantPreference) -> String {
        "legacy:\(legacyHash(for: legacyURL)):\(variant.rawValue)"
    }

    static func legacyHash(for legacyURL: String) -> String {
        let digest = SHA256.hash(data: Data(legacyURL.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    func fetchImage(
        asset: RemoteImageAsset?,
        preferredVariant: VariantPreference = .display,
        legacyURL: String? = nil
    ) async -> UIImage? {
        if let loadedFromAsset = await fetchImageFromAsset(asset, preferredVariant: preferredVariant) {
            return loadedFromAsset
        }

        guard let legacyURL,
              let url = URL(string: legacyURL),
              !legacyURL.isEmpty else {
            return nil
        }

        let legacyKey = Self.cacheKey(legacyURL: legacyURL, variant: preferredVariant)
        if let data = cachedData(forKey: legacyKey) {
            return UIImage(data: data)
        }

        guard let downloaded = await download(url: url) else {
            return nil
        }
        store(data: downloaded, forKey: legacyKey)
        return UIImage(data: downloaded)
    }

    func prefetch(
        asset: RemoteImageAsset?,
        preferredVariant: VariantPreference = .display,
        legacyURL: String? = nil
    ) async {
        _ = await fetchImage(asset: asset, preferredVariant: preferredVariant, legacyURL: legacyURL)
    }

    func prefetch(requests: [PrefetchRequest]) async {
        for request in requests {
            _ = await fetchImage(
                asset: request.asset,
                preferredVariant: request.preferredVariant,
                legacyURL: request.legacyURL
            )
        }
    }

    private func fetchImageFromAsset(
        _ asset: RemoteImageAsset?,
        preferredVariant: VariantPreference
    ) async -> UIImage? {
        guard let asset else {
            return nil
        }

        for variant in preferredOrder(for: preferredVariant) {
            guard let variantURL = urlString(for: asset, variant: variant),
                  let url = URL(string: variantURL) else {
                continue
            }

            let key = Self.cacheKey(asset: asset, variant: variant)
            if let cached = cachedData(forKey: key) {
                return UIImage(data: cached)
            }

            guard let downloaded = await download(url: url) else {
                continue
            }

            store(data: downloaded, forKey: key)
            return UIImage(data: downloaded)
        }

        return nil
    }

    private func preferredOrder(for preferredVariant: VariantPreference) -> [VariantPreference] {
        switch preferredVariant {
        case .thumb:
            return [.thumb, .display, .large]
        case .display:
            return [.display, .large, .thumb]
        case .large:
            return [.large, .display, .thumb]
        }
    }

    private func urlString(for asset: RemoteImageAsset, variant: VariantPreference) -> String? {
        switch variant {
        case .thumb:
            return asset.variants?.thumb?.url
        case .display:
            return asset.variants?.display?.url
        case .large:
            return asset.variants?.large?.url
        }
    }

    private func cachedData(forKey key: String) -> Data? {
        if let inMemory = memoryCache.object(forKey: key as NSString) {
            return Data(referencing: inMemory)
        }

        let diskURL = fileURL(for: key)
        guard let diskData = try? Data(contentsOf: diskURL) else {
            return nil
        }

        memoryCache.setObject(diskData as NSData, forKey: key as NSString)
        return diskData
    }

    private func store(data: Data, forKey key: String) {
        memoryCache.setObject(data as NSData, forKey: key as NSString)
        let diskURL = fileURL(for: key)
        try? data.write(to: diskURL, options: .atomic)
    }

    private func fileURL(for key: String) -> URL {
        diskDirectoryURL.appendingPathComponent(key).appendingPathExtension("cache")
    }

    private func download(url: URL) async -> Data? {
        do {
            let (data, response) = try await urlSession.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  200 ..< 300 ~= httpResponse.statusCode else {
                return nil
            }
            return data
        } catch {
            return nil
        }
    }
}
