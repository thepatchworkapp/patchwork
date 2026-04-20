import Foundation
import ImageIO
import PhotosUI
import UIKit

struct ImageAssetUploadService {
    enum UploadError: LocalizedError {
        case invalidPickerData
        case invalidImageData
        case invalidUploadURL
        case uploadFailed(statusCode: Int)

        var errorDescription: String? {
            switch self {
            case .invalidPickerData:
                return "Could not read selected photo data."
            case .invalidImageData:
                return "Could not process image data for upload."
            case .invalidUploadURL:
                return "Upload URL returned by server is invalid."
            case .uploadFailed(let statusCode):
                return "Image upload failed with status code \(statusCode)."
            }
        }
    }

    private struct EncodedUploadVariant {
        let name: String
        let data: Data
        let width: Int
        let height: Int

        var payload: [String: Any] {
            [
                "contentType": "image/jpeg",
                "width": width,
                "height": height,
                "byteSize": data.count,
            ]
        }
    }

    private struct UploadTarget: Decodable {
        let url: String
        let method: String?
        let headers: [String: String]?

        enum CodingKeys: String, CodingKey {
            case url
            case uploadURL = "uploadUrl"
            case method
            case headers
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.url =
                try container.decodeIfPresent(String.self, forKey: .url)
                ?? container.decode(String.self, forKey: .uploadURL)
            self.method = try container.decodeIfPresent(String.self, forKey: .method)
            self.headers = try container.decodeIfPresent([String: String].self, forKey: .headers)
        }
    }

    private struct UploadTargets: Decodable {
        let thumb: UploadTarget
        let display: UploadTarget
        let large: UploadTarget?
    }

    private struct GenerateUploadURLsResponse: Decodable {
        let assetId: ConvexID
        let uploadTargets: UploadTargets

        enum CodingKeys: String, CodingKey {
            case assetId
            case id
            case legacyId = "_id"
            case uploadUrls
            case variants
            case thumb
            case display
            case large
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.assetId =
                try container.decodeIfPresent(ConvexID.self, forKey: .assetId)
                ?? container.decodeIfPresent(ConvexID.self, forKey: .id)
                ?? container.decode(ConvexID.self, forKey: .legacyId)

            if let nested = try container.decodeIfPresent(UploadTargets.self, forKey: .uploadUrls) {
                self.uploadTargets = nested
                return
            }
            if let nested = try container.decodeIfPresent(UploadTargets.self, forKey: .variants) {
                self.uploadTargets = nested
                return
            }

            self.uploadTargets = UploadTargets(
                thumb: try container.decode(UploadTarget.self, forKey: .thumb),
                display: try container.decode(UploadTarget.self, forKey: .display),
                large: try container.decodeIfPresent(UploadTarget.self, forKey: .large)
            )
        }
    }

    let client: ConvexHTTPClient
    let urlSession: URLSession
    let thumbMaxDimension: CGFloat
    let displayMaxDimension: CGFloat
    let largeMaxDimension: CGFloat
    let jpegCompressionQuality: CGFloat

    init(
        client: ConvexHTTPClient,
        urlSession: URLSession = .shared,
        thumbMaxDimension: CGFloat = 256,
        displayMaxDimension: CGFloat = 1024,
        largeMaxDimension: CGFloat = 2048,
        jpegCompressionQuality: CGFloat = 0.82
    ) {
        self.client = client
        self.urlSession = urlSession
        self.thumbMaxDimension = thumbMaxDimension
        self.displayMaxDimension = displayMaxDimension
        self.largeMaxDimension = largeMaxDimension
        self.jpegCompressionQuality = jpegCompressionQuality
    }

    func uploadImage(
        from pickerItem: PhotosPickerItem,
        purpose: String,
        includeLargeVariant: Bool = true
    ) async throws -> RemoteImageAsset {
        guard let data = try await pickerItem.loadTransferable(type: Data.self), !data.isEmpty else {
            throw UploadError.invalidPickerData
        }

        let sourceContentType = pickerItem.supportedContentTypes.first?.preferredMIMEType ?? "image/jpeg"
        return try await uploadImage(
            data: data,
            sourceContentType: sourceContentType,
            purpose: purpose,
            includeLargeVariant: includeLargeVariant
        )
    }

    func uploadImage(
        data: Data,
        sourceContentType: String = "image/jpeg",
        purpose: String,
        includeLargeVariant: Bool = true
    ) async throws -> RemoteImageAsset {
        let variants = try buildUploadVariants(from: data, includeLargeVariant: includeLargeVariant)
        let variantPayload = variants.reduce(into: [String: Any]()) { partialResult, variant in
            partialResult[variant.name] = variant.payload
        }

        let generated: GenerateUploadURLsResponse = try await client.mutation(
            "files:generateImageAssetUploadUrls",
            args: [
                "purpose": purpose,
                "sourceContentType": sourceContentType,
                "variants": variantPayload,
            ]
        )

        for variant in variants {
            let target: UploadTarget?
            switch variant.name {
            case "thumb":
                target = generated.uploadTargets.thumb
            case "display":
                target = generated.uploadTargets.display
            case "large":
                target = generated.uploadTargets.large
            default:
                target = nil
            }

            guard let target else {
                continue
            }
            try await uploadVariantBlob(variant.data, to: target)
        }

        let commitArgs: [String: Any] = [
            "assetId": generated.assetId,
            "sourceContentType": sourceContentType,
            "variants": variantPayload,
        ]

        let committed: RemoteImageAsset = try await client.mutation(
            "files:commitImageAsset",
            args: commitArgs
        )
        return committed
    }

    private func buildUploadVariants(from sourceData: Data, includeLargeVariant: Bool = true) throws -> [EncodedUploadVariant] {
        var variants: [EncodedUploadVariant] = [
            try makeEncodedVariant(name: "thumb", maxDimension: thumbMaxDimension, sourceData: sourceData),
            try makeEncodedVariant(name: "display", maxDimension: displayMaxDimension, sourceData: sourceData),
        ]

        if includeLargeVariant {
            variants.append(try makeEncodedVariant(name: "large", maxDimension: largeMaxDimension, sourceData: sourceData))
        }

        return variants
    }

    private func makeEncodedVariant(name: String, maxDimension: CGFloat, sourceData: Data) throws -> EncodedUploadVariant {
        let image = try Self.downsampledImage(from: sourceData, maxPixelSize: maxDimension)
        let jpegData = try Self.jpegData(from: image, compressionQuality: jpegCompressionQuality)
        guard let pixelSize = Self.pixelSize(from: jpegData) else {
            throw UploadError.invalidImageData
        }

        return EncodedUploadVariant(
            name: name,
            data: jpegData,
            width: max(1, Int(pixelSize.width.rounded())),
            height: max(1, Int(pixelSize.height.rounded()))
        )
    }

    private func uploadVariantBlob(_ data: Data, to target: UploadTarget) async throws {
        guard let url = URL(string: target.url) else {
            throw UploadError.invalidUploadURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = target.method?.uppercased() ?? "POST"
        request.httpBody = data
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        if let headers = target.headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        let (_, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              200 ..< 300 ~= httpResponse.statusCode else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw UploadError.uploadFailed(statusCode: statusCode)
        }
    }

    static func downsampledImage(from data: Data, maxPixelSize: CGFloat) throws -> UIImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw UploadError.invalidImageData
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, Int(maxPixelSize.rounded())),
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw UploadError.invalidImageData
        }

        return UIImage(cgImage: cgImage)
    }

    static func jpegData(from image: UIImage, compressionQuality: CGFloat) throws -> Data {
        guard let data = image.jpegData(compressionQuality: compressionQuality) else {
            throw UploadError.invalidImageData
        }
        return data
    }

    static func pixelSize(from data: Data) -> CGSize? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = properties[kCGImagePropertyPixelHeight] as? CGFloat else {
            return nil
        }

        return CGSize(width: width, height: height)
    }
}
