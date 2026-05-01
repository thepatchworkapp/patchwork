import CryptoKit
import Foundation
import UIKit

actor PatchworkImageCache {
    struct Configuration {
        let memoryCountLimit: Int
        let decodedImageMemoryLimit: Int
        let diskSizeLimit: Int
        let diskAgeLimit: TimeInterval
        let trimInterval: TimeInterval

        init(
            memoryCountLimit: Int = 200,
            decodedImageMemoryLimit: Int = 80 * 1024 * 1024,
            diskSizeLimit: Int = 150 * 1024 * 1024,
            diskAgeLimit: TimeInterval = 30 * 24 * 60 * 60,
            trimInterval: TimeInterval = 60 * 60
        ) {
            self.memoryCountLimit = memoryCountLimit
            self.decodedImageMemoryLimit = decodedImageMemoryLimit
            self.diskSizeLimit = diskSizeLimit
            self.diskAgeLimit = diskAgeLimit
            self.trimInterval = trimInterval
        }
    }

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

    private let dataCache = NSCache<NSString, NSData>()
    private let decodedImageCache = NSCache<NSString, UIImage>()
    private let diskDirectoryURL: URL
    private let fileManager: FileManager
    private let urlSession: URLSession
    private let configuration: Configuration
    private var inFlightDownloads: [String: Task<Data?, Never>] = [:]
    private var lastTrimDate: Date?

    init(
        fileManager: FileManager = .default,
        urlSession: URLSession = .shared,
        diskDirectoryURL: URL? = nil,
        configuration: Configuration = Configuration()
    ) {
        self.fileManager = fileManager
        self.urlSession = urlSession
        self.configuration = configuration

        let defaultDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("PatchworkImageCache", isDirectory: true)
        self.diskDirectoryURL = diskDirectoryURL ?? defaultDirectory ?? URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("PatchworkImageCache", isDirectory: true)

        dataCache.countLimit = configuration.memoryCountLimit
        decodedImageCache.totalCostLimit = configuration.decodedImageMemoryLimit

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
        return await image(forKey: legacyKey, url: url)
    }

    func prefetch(
        asset: RemoteImageAsset?,
        preferredVariant: VariantPreference = .display,
        legacyURL: String? = nil
    ) async {
        _ = await fetchImage(asset: asset, preferredVariant: preferredVariant, legacyURL: legacyURL)
    }

    func prefetch(requests: [PrefetchRequest]) async {
        for request in deduplicated(requests) {
            _ = await fetchImage(
                asset: request.asset,
                preferredVariant: request.preferredVariant,
                legacyURL: request.legacyURL
            )
        }
    }

#if DEBUG
    func trimDiskCacheForTesting() {
        trimDiskCacheIfNeeded(force: true)
    }
#endif

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
            if let image = await image(forKey: key, url: url) {
                return image
            }
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

    private func image(forKey key: String, url: URL) async -> UIImage? {
        if let decoded = decodedImageCache.object(forKey: key as NSString) {
            return decoded
        }

        if let cached = cachedData(forKey: key),
           let image = decodedImage(from: cached, forKey: key) {
            return image
        }

        guard let downloaded = await data(forKey: key, url: url) else {
            return nil
        }

        store(data: downloaded, forKey: key)
        return decodedImage(from: downloaded, forKey: key)
    }

    private func data(forKey key: String, url: URL) async -> Data? {
        if let existingTask = inFlightDownloads[key] {
            return await existingTask.value
        }

        let task = Task<Data?, Never> {
            await download(url: url)
        }
        inFlightDownloads[key] = task
        let data = await task.value
        inFlightDownloads[key] = nil
        return data
    }

    private func decodedImage(from data: Data, forKey key: String) -> UIImage? {
        guard let image = UIImage(data: data) else {
            return nil
        }
        decodedImageCache.setObject(image, forKey: key as NSString, cost: image.decodedCacheCost)
        return image
    }

    private func cachedData(forKey key: String) -> Data? {
        if let inMemory = dataCache.object(forKey: key as NSString) {
            return Data(referencing: inMemory)
        }

        let diskURL = fileURL(for: key)
        guard let diskData = try? Data(contentsOf: diskURL) else {
            return nil
        }

        dataCache.setObject(diskData as NSData, forKey: key as NSString)
        updateAccessDate(for: diskURL)
        return diskData
    }

    private func store(data: Data, forKey key: String) {
        dataCache.setObject(data as NSData, forKey: key as NSString)
        let diskURL = fileURL(for: key)
        try? data.write(to: diskURL, options: .atomic)
        trimDiskCacheIfNeeded()
    }

    private func fileURL(for key: String) -> URL {
        diskDirectoryURL.appendingPathComponent(key).appendingPathExtension("cache")
    }

    private func deduplicated(_ requests: [PrefetchRequest]) -> [PrefetchRequest] {
        var seen = Set<PrefetchRequest>()
        var result: [PrefetchRequest] = []
        for request in requests where seen.insert(request).inserted {
            result.append(request)
        }
        return result
    }

    private func updateAccessDate(for url: URL) {
        try? fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
    }

    private func trimDiskCacheIfNeeded(force: Bool = false) {
        let now = Date()
        if !force,
           let lastTrimDate,
           now.timeIntervalSince(lastTrimDate) < configuration.trimInterval {
            return
        }

        lastTrimDate = now
        trimDiskCache(now: now)
    }

    private func trimDiskCache(now: Date) {
        guard let enumerator = fileManager.enumerator(
            at: diskDirectoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .totalFileAllocatedSizeKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        var entries: [(url: URL, date: Date, size: Int)] = []
        var totalSize = 0

        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "cache" else {
                continue
            }

            let values = try? fileURL.resourceValues(forKeys: [
                .contentModificationDateKey,
                .totalFileAllocatedSizeKey,
                .fileSizeKey,
            ])
            let date = values?.contentModificationDate ?? .distantPast
            let size = values?.totalFileAllocatedSize ?? values?.fileSize ?? 0

            if now.timeIntervalSince(date) > configuration.diskAgeLimit {
                try? fileManager.removeItem(at: fileURL)
                continue
            }

            entries.append((fileURL, date, size))
            totalSize += size
        }

        guard totalSize > configuration.diskSizeLimit else {
            return
        }

        for entry in entries.sorted(by: { $0.date < $1.date }) {
            try? fileManager.removeItem(at: entry.url)
            totalSize -= entry.size
            if totalSize <= configuration.diskSizeLimit {
                break
            }
        }
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

private extension UIImage {
    var decodedCacheCost: Int {
        let width = Int(size.width * scale)
        let height = Int(size.height * scale)
        return max(width * height * 4, 1)
    }
}
