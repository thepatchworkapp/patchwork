import UIKit
import XCTest
@testable import Patchwork

final class PhotoCropJPEGHelperTests: XCTestCase {
    func testAvatarCropRendererProducesExpectedPixelSizeAndJPEGMetadata() throws {
        let source = makeImage(width: 1400, height: 900)

        let rendered = try PatchworkPhotoCropRenderer.renderCrop(
            image: source,
            purpose: .userPhoto,
            scale: 1.35,
            offset: CGSize(width: 80, height: -45)
        )
        XCTAssertEqual(Int(rendered.size.width), 1024)
        XCTAssertEqual(Int(rendered.size.height), 1024)

        let jpegData = try ImageAssetUploadService.jpegData(from: rendered, compressionQuality: 0.84)
        let pixelSize = try XCTUnwrap(ImageAssetUploadService.pixelSize(from: jpegData))
        XCTAssertEqual(Int(pixelSize.width.rounded()), 1024)
        XCTAssertEqual(Int(pixelSize.height.rounded()), 1024)
    }

    func testPortfolioCropRendererProducesExpectedPixelSizeAndJPEGMetadata() throws {
        let source = makeImage(width: 900, height: 1400)

        let rendered = try PatchworkPhotoCropRenderer.renderCrop(
            image: source,
            purpose: .taskerCategoryPortfolio,
            scale: 1.9,
            offset: CGSize(width: -42, height: 28)
        )
        XCTAssertEqual(Int(rendered.size.width), 1600)
        XCTAssertEqual(Int(rendered.size.height), 1200)

        let jpegData = try ImageAssetUploadService.jpegData(from: rendered, compressionQuality: 0.86)
        let pixelSize = try XCTUnwrap(ImageAssetUploadService.pixelSize(from: jpegData))
        XCTAssertEqual(Int(pixelSize.width.rounded()), 1600)
        XCTAssertEqual(Int(pixelSize.height.rounded()), 1200)
    }

    func testAspectFillSizeAlwaysCoversCropBounds() {
        let filled = PatchworkPhotoCropRenderer.aspectFillSize(
            imageSize: CGSize(width: 640, height: 320),
            cropSize: CGSize(width: 300, height: 300)
        )

        XCTAssertGreaterThanOrEqual(filled.width, 300)
        XCTAssertGreaterThanOrEqual(filled.height, 300)
    }

    private func makeImage(width: CGFloat, height: CGFloat) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        return renderer.image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))

            UIColor.systemOrange.setFill()
            context.fill(
                CGRect(
                    x: width * 0.3,
                    y: height * 0.25,
                    width: width * 0.45,
                    height: height * 0.5
                )
            )
        }
    }
}
