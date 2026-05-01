import XCTest
import UIKit
@testable import Patchwork

final class ImageAssetInfrastructureTests: XCTestCase {
    override func tearDown() {
        ImageCacheURLProtocol.reset()
        super.tearDown()
    }

    func testCacheKeyUsesAssetCacheKeyAndVariant() {
        let asset = RemoteImageAsset(id: "asset_1", cacheKey: "cache_abc", updatedAt: 123, variants: nil)

        let thumbKey = PatchworkImageCache.cacheKey(asset: asset, variant: .thumb)
        let displayKey = PatchworkImageCache.cacheKey(asset: asset, variant: .display)

        XCTAssertEqual(thumbKey, "asset:cache_abc:thumb")
        XCTAssertEqual(displayKey, "asset:cache_abc:display")
        XCTAssertNotEqual(thumbKey, displayKey)
    }

    func testLegacyCacheKeyHashIsStableAndVariantAware() {
        let url = "https://cdn.patchwork.test/avatar.jpg"

        let keyA = PatchworkImageCache.cacheKey(legacyURL: url, variant: .thumb)
        let keyB = PatchworkImageCache.cacheKey(legacyURL: url, variant: .thumb)
        let keyC = PatchworkImageCache.cacheKey(legacyURL: url, variant: .large)

        XCTAssertEqual(keyA, keyB)
        XCTAssertNotEqual(keyA, keyC)
        XCTAssertTrue(keyA.hasPrefix("legacy:"))
    }

    func testConcurrentImageFetchesCoalesceMatchingDownloads() async throws {
        let imageData = try makeImageData(width: 32, height: 32)
        let url = try XCTUnwrap(URL(string: "https://images.patchwork.test/avatar.jpg"))
        ImageCacheURLProtocol.setResponse(data: imageData, delay: 0.05)
        let cache = makeTestImageCache()
        let asset = makeRemoteImageAsset(url: url.absoluteString, cacheKey: "asset_coalesced:1")

        async let first = cache.fetchImage(asset: asset, preferredVariant: .thumb)
        async let second = cache.fetchImage(asset: asset, preferredVariant: .thumb)
        async let third = cache.fetchImage(asset: asset, preferredVariant: .thumb)

        let images = await [first, second, third]

        XCTAssertEqual(images.compactMap { $0 }.count, 3)
        XCTAssertEqual(ImageCacheURLProtocol.requestCount, 1)
    }

    func testCachedImageFetchAvoidsNetworkAfterInitialDownload() async throws {
        let imageData = try makeImageData(width: 32, height: 32)
        let url = try XCTUnwrap(URL(string: "https://images.patchwork.test/warm-cache.jpg"))
        ImageCacheURLProtocol.setResponse(data: imageData)
        let cache = makeTestImageCache()
        let asset = makeRemoteImageAsset(url: url.absoluteString, cacheKey: "asset_warm:1")

        let first = await cache.fetchImage(asset: asset, preferredVariant: .display)
        let second = await cache.fetchImage(asset: asset, preferredVariant: .display)

        XCTAssertNotNil(first)
        XCTAssertNotNil(second)
        XCTAssertEqual(ImageCacheURLProtocol.requestCount, 1)
    }

    func testDiskCacheTrimRemovesExpiredAndOversizeFiles() async throws {
        let directory = temporaryCacheDirectory()
        let oldFile = directory.appendingPathComponent("old.cache")
        let recentA = directory.appendingPathComponent("recent-a.cache")
        let recentB = directory.appendingPathComponent("recent-b.cache")
        try Data(repeating: 1, count: 16).write(to: oldFile)
        try Data(repeating: 2, count: 80).write(to: recentA)
        try Data(repeating: 3, count: 80).write(to: recentB)
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSinceNow: -120)],
            ofItemAtPath: oldFile.path
        )
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSinceNow: -20)],
            ofItemAtPath: recentA.path
        )
        try FileManager.default.setAttributes(
            [.modificationDate: Date()],
            ofItemAtPath: recentB.path
        )

        let cache = makeTestImageCache(
            diskDirectoryURL: directory,
            configuration: PatchworkImageCache.Configuration(
                diskSizeLimit: 5_000,
                diskAgeLimit: 60,
                trimInterval: 0
            )
        )
        await cache.trimDiskCacheForTesting()

        XCTAssertFalse(FileManager.default.fileExists(atPath: oldFile.path))
        let remainingRecentFiles = [recentA, recentB].filter { FileManager.default.fileExists(atPath: $0.path) }
        XCTAssertEqual(remainingRecentFiles.count, 1)
        XCTAssertEqual(remainingRecentFiles.first, recentB)
    }

    func testDownsampledImageRespectsMaxPixelSize() throws {
        let sourceData = try makeImageData(width: 1200, height: 800)

        let image = try ImageAssetUploadService.downsampledImage(from: sourceData, maxPixelSize: 256)
        let maxEdge = max(image.size.width * image.scale, image.size.height * image.scale)

        XCTAssertLessThanOrEqual(maxEdge, 256.0)
    }

    func testJPEGEncodingAndPixelSizeHelper() throws {
        let sourceData = try makeImageData(width: 640, height: 480)
        let downsampled = try ImageAssetUploadService.downsampledImage(from: sourceData, maxPixelSize: 320)
        let encoded = try ImageAssetUploadService.jpegData(from: downsampled, compressionQuality: 0.8)

        let pixelSize = try XCTUnwrap(ImageAssetUploadService.pixelSize(from: encoded))
        XCTAssertGreaterThan(pixelSize.width, 0)
        XCTAssertGreaterThan(pixelSize.height, 0)
        XCTAssertLessThanOrEqual(max(pixelSize.width, pixelSize.height), 320)
    }

    func testAvatarCropRendererProducesSquareJPEG() throws {
        let source = try makeImage(width: 1600, height: 900)

        let cropped = try PatchworkPhotoCropRenderer.renderCrop(
            image: source,
            purpose: .userPhoto,
            scale: 1,
            offset: .zero
        )
        let encoded = try XCTUnwrap(cropped.jpegData(compressionQuality: 0.86))
        let pixelSize = try XCTUnwrap(ImageAssetUploadService.pixelSize(from: encoded))

        XCTAssertEqual(pixelSize.width, 1024)
        XCTAssertEqual(pixelSize.height, 1024)
    }

    func testPortfolioCropRendererProducesFourByThreeJPEG() throws {
        let source = try makeImage(width: 900, height: 1600)

        let cropped = try PatchworkPhotoCropRenderer.renderCrop(
            image: source,
            purpose: .taskerCategoryPortfolio,
            scale: 1.25,
            offset: CGSize(width: 14, height: -20)
        )
        let encoded = try XCTUnwrap(cropped.jpegData(compressionQuality: 0.86))
        let pixelSize = try XCTUnwrap(ImageAssetUploadService.pixelSize(from: encoded))

        XCTAssertEqual(pixelSize.width, 1600)
        XCTAssertEqual(pixelSize.height, 1200)
    }

    func testCameraAvailabilityCanBeCheckedWithoutPrompting() {
        _ = CameraCaptureView.isCameraAvailable
    }

    private func makeImageData(width: CGFloat, height: CGFloat) throws -> Data {
        try XCTUnwrap(makeImage(width: width, height: height).pngData())
    }

    private func makeImage(width: CGFloat, height: CGFloat) throws -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        return renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            UIColor.systemYellow.setFill()
            context.fill(CGRect(x: width * 0.25, y: height * 0.25, width: width * 0.5, height: height * 0.5))
        }
    }

    private func makeTestImageCache(
        diskDirectoryURL: URL? = nil,
        configuration: PatchworkImageCache.Configuration = PatchworkImageCache.Configuration(
            diskSizeLimit: 1024 * 1024,
            diskAgeLimit: 60 * 60,
            trimInterval: 0
        )
    ) -> PatchworkImageCache {
        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.protocolClasses = [ImageCacheURLProtocol.self]
        return PatchworkImageCache(
            urlSession: URLSession(configuration: sessionConfiguration),
            diskDirectoryURL: diskDirectoryURL ?? temporaryCacheDirectory(),
            configuration: configuration
        )
    }

    private func temporaryCacheDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PatchworkImageCacheTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func makeRemoteImageAsset(url: String, cacheKey: String) -> RemoteImageAsset {
        let variant = RemoteImageVariant(
            url: url,
            width: 32,
            height: 32,
            contentType: "image/png",
            byteSize: 100
        )
        return RemoteImageAsset(
            id: cacheKey,
            cacheKey: cacheKey,
            updatedAt: 1,
            variants: RemoteImageVariants(thumb: variant, display: variant, large: nil)
        )
    }
}

private final class ImageCacheURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var responseData = Data()
    private static var responseDelay: TimeInterval = 0
    private static var count = 0

    static var requestCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    static func setResponse(data: Data, delay: TimeInterval = 0) {
        lock.lock()
        responseData = data
        responseDelay = delay
        count = 0
        lock.unlock()
    }

    static func reset() {
        lock.lock()
        responseData = Data()
        responseDelay = 0
        count = 0
        lock.unlock()
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.lock.lock()
        Self.count += 1
        let data = Self.responseData
        let delay = Self.responseDelay
        Self.lock.unlock()

        Task {
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            guard let url = request.url,
                  let response = HTTPURLResponse(
                      url: url,
                      statusCode: 200,
                      httpVersion: nil,
                      headerFields: ["Content-Type": "image/png"]
                  ) else {
                client?.urlProtocol(self, didFailWithError: URLError(.badURL))
                return
            }

            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}
