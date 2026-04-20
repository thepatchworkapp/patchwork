import XCTest
import UIKit
@testable import Patchwork

final class ImageAssetInfrastructureTests: XCTestCase {
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
}
