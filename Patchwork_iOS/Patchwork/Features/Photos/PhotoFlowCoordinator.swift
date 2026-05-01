import SwiftUI
import UIKit

final class SingleImagePhotoFlowCoordinator: ObservableObject {
    enum ActiveSheet: Identifiable {
        case camera
        case gallery
        case crop(PhotoCropInput)

        var id: String {
            switch self {
            case .camera:
                return "camera"
            case .gallery:
                return "gallery"
            case .crop(let input):
                return "crop-\(input.id)"
            }
        }
    }

    let purpose: PhotoPurpose
    let selectionLimit: Int

    @Published var showsPhotoOptions = false
    @Published var activeSheet: ActiveSheet?
    @Published private(set) var pendingDraft: PhotoDraft?

    init(purpose: PhotoPurpose, selectionLimit: Int = 1) {
        self.purpose = purpose
        self.selectionLimit = max(1, selectionLimit)
    }

    func showOptions() {
        showsPhotoOptions = true
    }

    func selectCamera() {
        guard CameraCaptureView.isCameraAvailable else {
            activeSheet = nil
            return
        }
        activeSheet = .camera
    }

    func selectGallery() {
        activeSheet = .gallery
    }

    func cancel() {
        showsPhotoOptions = false
        activeSheet = nil
    }

    func presentCrop(for image: UIImage?) {
        guard let image else {
            activeSheet = nil
            return
        }
        activeSheet = .crop(PhotoCropInput(image: image, purpose: purpose))
    }

    func cancelCrop() {
        activeSheet = nil
    }

    func confirmCrop(_ draft: PhotoDraft) {
        pendingDraft = draft
        activeSheet = nil
    }

    func takePendingDraft() -> PhotoDraft? {
        defer { pendingDraft = nil }
        return pendingDraft
    }
}
