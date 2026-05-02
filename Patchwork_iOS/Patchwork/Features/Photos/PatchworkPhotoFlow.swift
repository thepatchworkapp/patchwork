import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

enum PhotoIntakeSource: String, CaseIterable, Hashable, Identifiable {
    case camera
    case gallery

    var id: String { rawValue }

    var title: String {
        switch self {
        case .camera:
            return "Take Photo"
        case .gallery:
            return "Choose from Library"
        }
    }

    var systemImage: String {
        switch self {
        case .camera:
            return "camera.fill"
        case .gallery:
            return "photo.on.rectangle.angled"
        }
    }

    var isAvailable: Bool {
        switch self {
        case .camera:
            return UIImagePickerController.isSourceTypeAvailable(.camera)
        case .gallery:
            return true
        }
    }
}

struct PhotoSourceChoice: Identifiable, Hashable {
    let source: PhotoIntakeSource
    let isEnabled: Bool

    var id: PhotoIntakeSource { source }

    init(source: PhotoIntakeSource) {
        self.source = source
        self.isEnabled = source.isAvailable
    }

    var title: String { source.title }
    var systemImage: String { source.systemImage }
}

struct PhotoIntakeRequest: Identifiable, Hashable {
    let id: UUID
    let purpose: PhotoPurpose
    let source: PhotoIntakeSource
    let selectionLimit: Int

    init(
        id: UUID = UUID(),
        purpose: PhotoPurpose,
        source: PhotoIntakeSource,
        selectionLimit: Int = 1
    ) {
        self.id = id
        self.purpose = purpose
        self.source = source
        self.selectionLimit = max(1, selectionLimit)
    }
}

enum PhotoPurpose: String, Hashable {
    case userPhoto
    case taskerPhoto
    case taskerCategoryPortfolio

    var convexPurpose: String {
        rawValue
    }

    var cropAspectRatio: CGSize {
        switch self {
        case .userPhoto, .taskerPhoto:
            return CGSize(width: 1, height: 1)
        case .taskerCategoryPortfolio:
            return CGSize(width: 4, height: 3)
        }
    }

    var cropTitle: String {
        switch self {
        case .userPhoto:
            return "Frame profile photo"
        case .taskerPhoto:
            return "Frame tasker photo"
        case .taskerCategoryPortfolio:
            return "Frame portfolio photo"
        }
    }

    var outputPixelSize: CGSize {
        switch self {
        case .userPhoto, .taskerPhoto:
            return CGSize(width: 1024, height: 1024)
        case .taskerCategoryPortfolio:
            return CGSize(width: 1600, height: 1200)
        }
    }
}

struct PhotoDraft: Identifiable {
    let id: UUID
    var data: Data
    var previewImage: UIImage
    var uploadedAsset: RemoteImageAsset?

    init(id: UUID = UUID(), data: Data, previewImage: UIImage, uploadedAsset: RemoteImageAsset? = nil) {
        self.id = id
        self.data = data
        self.previewImage = previewImage
        self.uploadedAsset = uploadedAsset
    }
}

struct PhotoCropInput: Identifiable {
    let id = UUID()
    let image: UIImage
    let purpose: PhotoPurpose
}

enum PatchworkPhotoCropRenderer {
    static func renderCrop(
        image: UIImage,
        purpose: PhotoPurpose,
        scale: CGFloat,
        offset: CGSize,
        normalizeInput: Bool = true
    ) throws -> UIImage {
        let normalizedImage = normalizeInput ? image.normalizedForPatchworkCropping() : image
        let outputSize = purpose.outputPixelSize
        let aspect = purpose.cropAspectRatio
        let cropSize = CGSize(width: 1000, height: 1000 * aspect.height / aspect.width)
        let fittedSize = aspectFillSize(imageSize: normalizedImage.size, cropSize: cropSize)
        let outputScaleX = outputSize.width / cropSize.width
        let outputScaleY = outputSize.height / cropSize.height
        let drawSize = CGSize(
            width: fittedSize.width * scale * outputScaleX,
            height: fittedSize.height * scale * outputScaleY
        )
        let drawOrigin = CGPoint(
            x: (outputSize.width - drawSize.width) / 2 + offset.width * outputScaleX,
            y: (outputSize.height - drawSize.height) / 2 + offset.height * outputScaleY
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: outputSize, format: format)
        return renderer.image { context in
            UIColor.systemBackground.setFill()
            context.fill(CGRect(origin: .zero, size: outputSize))
            normalizedImage.draw(in: CGRect(origin: drawOrigin, size: drawSize))
        }
    }

    static func aspectFillSize(imageSize: CGSize, cropSize: CGSize) -> CGSize {
        let scale = max(cropSize.width / max(imageSize.width, 1), cropSize.height / max(imageSize.height, 1))
        return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }
}

struct AvatarPhotoControl<Placeholder: View>: View {
    let localImage: UIImage?
    let remoteAsset: RemoteImageAsset?
    let size: CGFloat
    let isBusy: Bool
    let accessibilityIdentifier: String
    let action: () -> Void
    let placeholder: () -> Placeholder

    init(
        localImage: UIImage? = nil,
        remoteAsset: RemoteImageAsset? = nil,
        size: CGFloat = 108,
        isBusy: Bool = false,
        accessibilityIdentifier: String,
        action: @escaping () -> Void,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.localImage = localImage
        self.remoteAsset = remoteAsset
        self.size = size
        self.isBusy = isBusy
        self.accessibilityIdentifier = accessibilityIdentifier
        self.action = action
        self.placeholder = placeholder
    }

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomTrailing) {
                avatarImage
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(PatchworkTheme.strokeStrong, lineWidth: 1)
                    )
                    .contentShape(Circle())

                ZStack {
                    Circle()
                        .fill(PatchworkTheme.surface)
                        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
                    Image(systemName: hasImage ? "pencil" : "plus")
                        .font(.system(size: size >= 96 ? 16 : 13, weight: .bold))
                        .foregroundStyle(PatchworkTheme.brand)
                }
                .frame(width: size >= 96 ? 34 : 28, height: size >= 96 ? 34 : 28)
                .overlay(
                    Circle()
                        .stroke(PatchworkTheme.strokeStrong, lineWidth: 1)
                )
                .offset(x: size >= 96 ? 10 : 8, y: size >= 96 ? 10 : 8)

                if isBusy {
                    Circle()
                        .fill(.black.opacity(0.22))
                        .frame(width: size, height: size)
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                        .frame(width: size, height: size)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .accessibilityLabel(hasImage ? "Edit profile photo" : "Add profile photo")
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    @ViewBuilder
    private var avatarImage: some View {
        if let localImage {
            Image(uiImage: localImage)
                .resizable()
                .scaledToFill()
        } else if let remoteAsset {
            PatchworkRemoteImage(
                asset: remoteAsset,
                preferredVariant: .display,
                contentMode: .fill
            ) {
                placeholder()
            }
        } else {
            placeholder()
        }
    }

    private var hasImage: Bool {
        localImage != nil || remoteAsset != nil
    }
}

private enum PortfolioPhotoGridItem: Identifiable {
    case draft(PhotoDraft)
    case remote(RemoteImageAsset)

    var id: String {
        switch self {
        case let .draft(draft):
            return "draft:\(draft.id.uuidString)"
        case let .remote(asset):
            return "remote:\(asset.id)"
        }
    }
}

struct PortfolioPhotoGridControl: View {
    let localDrafts: [PhotoDraft]
    let remoteAssets: [RemoteImageAsset]
    let maxItemCount: Int
    let isBusy: Bool
    let addAccessibilityIdentifier: String
    let onAdd: () -> Void
    let onRemoveLocal: (PhotoDraft) -> Void
    let onRemoveRemote: (RemoteImageAsset) -> Void

    init(
        localDrafts: [PhotoDraft] = [],
        remoteAssets: [RemoteImageAsset] = [],
        maxItemCount: Int = 12,
        isBusy: Bool = false,
        addAccessibilityIdentifier: String = "PortfolioPhotoGrid.addButton",
        onAdd: @escaping () -> Void,
        onRemoveLocal: @escaping (PhotoDraft) -> Void = { _ in },
        onRemoveRemote: @escaping (RemoteImageAsset) -> Void = { _ in }
    ) {
        self.localDrafts = localDrafts
        self.remoteAssets = remoteAssets
        self.maxItemCount = max(1, maxItemCount)
        self.isBusy = isBusy
        self.addAccessibilityIdentifier = addAccessibilityIdentifier
        self.onAdd = onAdd
        self.onRemoveLocal = onRemoveLocal
        self.onRemoveRemote = onRemoveRemote
    }

    private var items: [PortfolioPhotoGridItem] {
        localDrafts.map(PortfolioPhotoGridItem.draft) + remoteAssets.map(PortfolioPhotoGridItem.remote)
    }

    private var canAddMore: Bool {
        items.count < maxItemCount
    }

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(minimum: 76), spacing: 10), count: 3),
            spacing: 10
        ) {
            ForEach(items) { item in
                photoItemView(item)
            }

            if canAddMore {
                Button(action: onAdd) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(PatchworkTheme.surface.opacity(0.85))

                        VStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .bold))
                            Text("Add")
                                .font(.patchworkCaption)
                        }
                        .foregroundStyle(PatchworkTheme.brand)
                    }
                    .frame(height: 96)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(PatchworkTheme.strokeStrong, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isBusy)
                .accessibilityIdentifier(addAccessibilityIdentifier)
                .accessibilityLabel("Add portfolio photo")
            }
        }
    }

    @ViewBuilder
    private func photoItemView(_ item: PortfolioPhotoGridItem) -> some View {
        ZStack(alignment: .topTrailing) {
            switch item {
            case let .draft(draft):
                Image(uiImage: draft.previewImage)
                    .resizable()
                    .scaledToFill()
            case let .remote(asset):
                PatchworkRemoteImage(
                    asset: asset,
                    preferredVariant: .display,
                    contentMode: .fill
                ) {
                    PatchworkTheme.brandSoft
                }
            }

            Button {
                switch item {
                case let .draft(draft):
                    onRemoveLocal(draft)
                case let .remote(asset):
                    onRemoveRemote(asset)
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(.black.opacity(0.58), in: Circle())
            }
            .buttonStyle(.plain)
            .padding(6)
            .accessibilityLabel("Remove photo")
        }
        .frame(height: 96)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(PatchworkTheme.stroke, lineWidth: 1)
        )
    }
}

struct CameraCaptureView: UIViewControllerRepresentable {
    let onComplete: (UIImage?) -> Void

    static var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = .camera
        controller.mediaTypes = [UTType.image.identifier]
        controller.delegate = context.coordinator
        controller.allowsEditing = false
        controller.modalPresentationStyle = .fullScreen
        return controller
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let onComplete: (UIImage?) -> Void

        init(onComplete: @escaping (UIImage?) -> Void) {
            self.onComplete = onComplete
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            onComplete(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onComplete(nil)
        }
    }
}

struct GalleryPickerView: UIViewControllerRepresentable {
    let selectionLimit: Int
    let onComplete: ([UIImage]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = selectionLimit
        configuration.preferredAssetRepresentationMode = .current

        let controller = PHPickerViewController(configuration: configuration)
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let onComplete: ([UIImage]) -> Void

        init(onComplete: @escaping ([UIImage]) -> Void) {
            self.onComplete = onComplete
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            Task {
                let images = await Self.loadImages(from: results)
                await MainActor.run {
                    onComplete(images)
                }
            }
        }

        private static func loadImages(from results: [PHPickerResult]) async -> [UIImage] {
            var images: [UIImage] = []

            for result in results {
                guard result.itemProvider.canLoadObject(ofClass: UIImage.self) else {
                    continue
                }

                if let image = await loadImage(from: result.itemProvider) {
                    images.append(image)
                }
            }

            return images
        }

        private static func loadImage(from provider: NSItemProvider) async -> UIImage? {
            await withCheckedContinuation { continuation in
                provider.loadObject(ofClass: UIImage.self) { object, _ in
                    continuation.resume(returning: object as? UIImage)
                }
            }
        }
    }
}

struct PhotoCropEditor: View {
    let input: PhotoCropInput
    let onCancel: () -> Void
    let onConfirm: (PhotoDraft) -> Void

    @StateObject private var imageContext: CropImageContext
    @StateObject private var cropState = PhotoCropInteractionState()
    @State private var resetToken = 0
    @State private var errorMessage: String?

    init(input: PhotoCropInput, onCancel: @escaping () -> Void, onConfirm: @escaping (PhotoDraft) -> Void) {
        self.input = input
        self.onCancel = onCancel
        self.onConfirm = onConfirm
        _imageContext = StateObject(wrappedValue: CropImageContext(image: input.image))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Text("Pinch to zoom and drag to position.")
                    .font(.patchworkCaption)
                    .foregroundStyle(PatchworkTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                GeometryReader { proxy in
                    let cropSize = cropFrameSize(in: proxy.size)

                    ZStack {
                        Color.black.opacity(0.88)

                        PhotoCropZoomView(
                            image: imageContext.displayPreviewImage,
                            cropState: cropState,
                            resetToken: resetToken
                        )
                            .frame(width: cropSize.width, height: cropSize.height)
                            .accessibilityLabel("Photo crop preview")

                        cropOverlay(cropSize: cropSize)
                    }
                    .frame(width: cropSize.width, height: cropSize.height)
                    .clipShape(RoundedRectangle(cornerRadius: input.purpose == .taskerCategoryPortfolio ? 18 : cropSize.width / 2, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: input.purpose == .taskerCategoryPortfolio ? 18 : cropSize.width / 2, style: .continuous)
                            .stroke(.white.opacity(0.92), lineWidth: 2)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxHeight: 430)

                if let errorMessage {
                    PatchworkInlineStatusBanner(tone: .error, text: errorMessage)
                }

                Button("Reset", action: resetCrop)
                .buttonStyle(PatchworkSecondaryButtonStyle())
                .accessibilityIdentifier("PhotoCrop.resetButton")
            }
            .padding(20)
            .background(PatchworkBackdrop(tint: PatchworkTheme.brand))
            .navigationTitle(input.purpose.cropTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .accessibilityIdentifier("PhotoCrop.cancelButton")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Use Photo", action: confirmCrop)
                        .accessibilityIdentifier("PhotoCrop.useButton")
                }
            }
        }
    }

    private final class CropImageContext: ObservableObject {
        let normalizedSourceImage: UIImage
        let displayPreviewImage: UIImage

        init(image: UIImage) {
            let normalized = image.normalizedForPatchworkCropping()
            normalizedSourceImage = normalized
            displayPreviewImage = normalized.downsampledForPatchworkDisplay(maxPixelSize: 1_536)
        }
    }

    private func cropFrameSize(in containerSize: CGSize) -> CGSize {
        let aspect = input.purpose.cropAspectRatio
        let maxWidth = containerSize.width.isFinite ? max(1, containerSize.width) : 1
        let maxHeight = containerSize.height.isFinite ? max(1, containerSize.height) : 1

        var width = maxWidth
        var height = width * aspect.height / aspect.width

        if height > maxHeight {
            height = maxHeight
            width = height * aspect.width / aspect.height
        }

        return CGSize(width: width, height: height)
    }

    private func cropOverlay(cropSize: CGSize) -> some View {
        Group {
            if input.purpose == .taskerCategoryPortfolio {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.42), lineWidth: 1)
            } else {
                Circle()
                    .stroke(.white.opacity(0.42), lineWidth: 1)
            }
        }
        .frame(width: cropSize.width, height: cropSize.height)
        .allowsHitTesting(false)
    }

    private func confirmCrop() {
        do {
            let cropScale = cropState.scale
            let cropOffset = cropState.offset
            let rendered = try PatchworkPhotoCropRenderer.renderCrop(
                image: imageContext.normalizedSourceImage,
                purpose: input.purpose,
                scale: cropScale,
                offset: cropOffset,
                normalizeInput: false
            )
            guard let data = rendered.jpegData(compressionQuality: 0.86), !data.isEmpty else {
                throw ImageAssetUploadService.UploadError.invalidImageData
            }
            onConfirm(PhotoDraft(data: data, previewImage: rendered))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resetCrop() {
        cropState.reset()
        resetToken &+= 1
        errorMessage = nil
    }

}

private final class PhotoCropInteractionState: ObservableObject {
    var scale: CGFloat = 1
    var offset: CGSize = .zero

    func reset() {
        scale = 1
        offset = .zero
    }
}

private struct PhotoCropZoomView: UIViewRepresentable {
    let image: UIImage
    let cropState: PhotoCropInteractionState
    let resetToken: Int

    func makeUIView(context: Context) -> PhotoCropZoomContainerView {
        PhotoCropZoomContainerView()
    }

    func updateUIView(_ uiView: PhotoCropZoomContainerView, context: Context) {
        uiView.configure(image: image, cropState: cropState, resetToken: resetToken)
    }
}

private final class PhotoCropZoomContainerView: UIView, UIScrollViewDelegate {
    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private weak var cropState: PhotoCropInteractionState?
    private var configuredImage: UIImage?
    private var lastBoundsSize: CGSize = .zero
    private var lastResetToken: Int?
    private var isApplyingViewport = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func configure(image: UIImage, cropState: PhotoCropInteractionState, resetToken: Int) {
        self.cropState = cropState

        let imageChanged = configuredImage !== image
        if imageChanged {
            configuredImage = image
            imageView.image = image
        }

        let resetRequested = lastResetToken != resetToken
        lastResetToken = resetToken

        guard imageChanged || resetRequested else {
            return
        }

        configureImageFrame(resetViewport: true)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        scrollView.frame = bounds

        guard bounds.size != lastBoundsSize else {
            return
        }

        lastBoundsSize = bounds.size
        configureImageFrame(resetViewport: true)
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateCropState()
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        updateCropState()
    }

    private func setup() {
        backgroundColor = .clear
        clipsToBounds = true

        scrollView.delegate = self
        scrollView.backgroundColor = .clear
        scrollView.clipsToBounds = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bounces = false
        scrollView.bouncesZoom = false
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 5
        scrollView.decelerationRate = .fast
        addSubview(scrollView)

        imageView.contentMode = .scaleToFill
        imageView.isUserInteractionEnabled = true
        scrollView.addSubview(imageView)
    }

    private func configureImageFrame(resetViewport: Bool) {
        guard let image = configuredImage, bounds.width > 0, bounds.height > 0 else {
            return
        }

        let fittedSize = PatchworkPhotoCropRenderer.aspectFillSize(imageSize: image.size, cropSize: bounds.size)
        isApplyingViewport = true
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 5
        scrollView.zoomScale = 1
        imageView.frame = CGRect(origin: .zero, size: fittedSize)
        scrollView.contentSize = fittedSize

        if resetViewport {
            resetViewportToCenter()
        } else {
            applyCropStateToViewport()
        }

        isApplyingViewport = false
        updateCropState()
    }

    private func resetViewportToCenter() {
        scrollView.zoomScale = 1
        scrollView.contentOffset = centeredContentOffset(contentSize: scrollView.contentSize)
        cropState?.reset()
    }

    private func applyCropStateToViewport() {
        guard let cropState else {
            resetViewportToCenter()
            return
        }

        let scale = min(max(cropState.scale, scrollView.minimumZoomScale), scrollView.maximumZoomScale)
        scrollView.zoomScale = scale
        let contentSize = scrollView.contentSize
        let centeredOffset = centeredContentOffset(contentSize: contentSize)
        scrollView.contentOffset = CGPoint(
            x: centeredOffset.x - cropState.offset.width,
            y: centeredOffset.y - cropState.offset.height
        )
    }

    private func updateCropState() {
        guard !isApplyingViewport, bounds.width > 0, bounds.height > 0 else {
            return
        }

        let contentSize = scrollView.contentSize
        let centeredOffset = centeredContentOffset(contentSize: contentSize)
        cropState?.scale = scrollView.zoomScale
        cropState?.offset = CGSize(
            width: centeredOffset.x - scrollView.contentOffset.x,
            height: centeredOffset.y - scrollView.contentOffset.y
        )
    }

    private func centeredContentOffset(contentSize: CGSize) -> CGPoint {
        CGPoint(
            x: max(0, (contentSize.width - bounds.width) / 2),
            y: max(0, (contentSize.height - bounds.height) / 2)
        )
    }
}

extension UIImage {
    func normalizedForPatchworkCropping() -> UIImage {
        guard imageOrientation != .up else {
            return self
        }

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    func downsampledForPatchworkDisplay(maxPixelSize: CGFloat) -> UIImage {
        let maxPixelSize = max(1, maxPixelSize)
        let longestEdge = max(size.width, size.height)
        guard longestEdge.isFinite, longestEdge > maxPixelSize else {
            return self
        }

        let resizeScale = maxPixelSize / longestEdge
        let targetSize = CGSize(width: size.width * resizeScale, height: size.height * resizeScale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false

        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
