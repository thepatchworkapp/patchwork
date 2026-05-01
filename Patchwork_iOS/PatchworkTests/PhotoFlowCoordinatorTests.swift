import UIKit
import XCTest
@testable import Patchwork

final class PhotoFlowCoordinatorTests: XCTestCase {
    func testGallerySelectionUsesConfiguredPurposeAndSelectionLimit() throws {
        let coordinator = SingleImagePhotoFlowCoordinator(purpose: .userPhoto)

        coordinator.selectGallery()

        guard case .gallery = coordinator.activeSheet else {
            return XCTFail("Expected gallery sheet")
        }
        XCTAssertEqual(coordinator.selectionLimit, 1)

        let image = try makeImage()
        coordinator.presentCrop(for: image)

        guard case .crop(let input) = coordinator.activeSheet else {
            return XCTFail("Expected crop sheet")
        }
        XCTAssertEqual(input.purpose, .userPhoto)
        XCTAssertEqual(input.image.size, image.size)
    }

    func testNilImageDismissesSheetWithoutDraft() {
        let coordinator = SingleImagePhotoFlowCoordinator(purpose: .userPhoto)

        coordinator.selectGallery()
        coordinator.presentCrop(for: nil)

        XCTAssertNil(coordinator.activeSheet)
        XCTAssertNil(coordinator.pendingDraft)
    }

    func testCropConfirmationStoresDraftUntilConsumedAndDismissesSheet() throws {
        let coordinator = SingleImagePhotoFlowCoordinator(purpose: .userPhoto)
        let image = try makeImage()
        coordinator.presentCrop(for: image)

        let draft = PhotoDraft(data: Data([0x01, 0x02]), previewImage: image)
        coordinator.confirmCrop(draft)

        XCTAssertNil(coordinator.activeSheet)
        XCTAssertEqual(coordinator.pendingDraft?.id, draft.id)

        let consumedDraft = coordinator.takePendingDraft()
        XCTAssertEqual(consumedDraft?.id, draft.id)
        XCTAssertNil(coordinator.pendingDraft)
    }

    private func makeImage() throws -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8))
        return renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
    }
}
