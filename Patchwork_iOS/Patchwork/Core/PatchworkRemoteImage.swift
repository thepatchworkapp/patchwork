import SwiftUI
import UIKit

struct PatchworkRemoteImage<Placeholder: View>: View {
    private let asset: RemoteImageAsset?
    private let legacyURL: String?
    private let preferredVariant: PatchworkImageCache.VariantPreference
    private let contentMode: ContentMode
    private let cache: PatchworkImageCache
    private let placeholder: () -> Placeholder

    @State private var loadedImage: UIImage?

    init(
        asset: RemoteImageAsset?,
        legacyURL: String? = nil,
        preferredVariant: PatchworkImageCache.VariantPreference = .display,
        contentMode: ContentMode = .fill,
        cache: PatchworkImageCache = .shared,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.asset = asset
        self.legacyURL = legacyURL
        self.preferredVariant = preferredVariant
        self.contentMode = contentMode
        self.cache = cache
        self.placeholder = placeholder
    }

    init(
        asset: RemoteImageAsset?,
        legacyURL: String? = nil,
        preferredVariant: PatchworkImageCache.VariantPreference = .display,
        contentMode: ContentMode = .fill,
        cache: PatchworkImageCache = .shared
    ) where Placeholder == DefaultPatchworkRemoteImagePlaceholder {
        self.init(
            asset: asset,
            legacyURL: legacyURL,
            preferredVariant: preferredVariant,
            contentMode: contentMode,
            cache: cache
        ) {
            DefaultPatchworkRemoteImagePlaceholder()
        }
    }

    var body: some View {
        Group {
            if let loadedImage {
                switch contentMode {
                case .fit:
                    Image(uiImage: loadedImage)
                        .resizable()
                        .scaledToFit()
                case .fill:
                    Image(uiImage: loadedImage)
                        .resizable()
                        .scaledToFill()
                }
            } else {
                placeholder()
            }
        }
        .task(id: taskIdentifier) {
            loadedImage = await cache.fetchImage(
                asset: asset,
                preferredVariant: preferredVariant,
                legacyURL: legacyURL
            )
        }
    }

    private var taskIdentifier: String {
        "\(asset?.cacheKey ?? legacyURL ?? "none"):\(preferredVariant.rawValue)"
    }
}

struct DefaultPatchworkRemoteImagePlaceholder: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.08))
            ProgressView()
                .controlSize(.small)
                .tint(.secondary)
        }
    }
}
