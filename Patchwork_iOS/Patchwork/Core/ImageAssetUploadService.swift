import Foundation
import ImageIO
import PhotosUI
import SwiftUI
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
                "kind": name,
                "contentType": "image/jpeg",
                "width": width,
                "height": height,
                "byteSize": data.count,
            ]
        }

        func committedPayload(storageId: ConvexID) -> [String: Any] {
            var result = payload
            result["storageId"] = storageId
            return result
        }
    }

    private struct UploadTarget: Decodable {
        let kind: String
        let uploadUrl: String
        let contentType: String?
        let width: Int?
        let height: Int?
        let byteSize: Int?

        enum CodingKeys: String, CodingKey {
            case kind
            case uploadUrl
            case contentType
            case width
            case height
            case byteSize
        }
    }

    private struct GenerateUploadURLsResponse: Decodable {
        let uploadUrls: [UploadTarget]
    }

    private struct UploadBlobResponse: Decodable {
        let storageId: ConvexID
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

        return try await uploadImage(
            data: data,
            purpose: purpose,
            includeLargeVariant: includeLargeVariant
        )
    }

    func uploadImage(
        data: Data,
        purpose: String,
        includeLargeVariant: Bool = true
    ) async throws -> RemoteImageAsset {
        let variants = try buildUploadVariants(from: data, includeLargeVariant: includeLargeVariant)
        let variantPayload = variants.map(\.payload)

        let generated: GenerateUploadURLsResponse = try await client.mutation(
            "files:generateImageAssetUploadUrls",
            args: [
                "purpose": purpose,
                "variants": variantPayload,
            ]
        )

        var committedVariants: [[String: Any]] = []
        for variant in variants {
            guard let target = generated.uploadUrls.first(where: { $0.kind == variant.name }) else {
                throw UploadError.invalidUploadURL
            }
            let storageId = try await uploadVariantBlob(variant.data, to: target)
            committedVariants.append(variant.committedPayload(storageId: storageId))
        }

        let commitArgs: [String: Any] = [
            "purpose": purpose,
            "sourceContentType": "image/jpeg",
            "variants": committedVariants,
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

    private func uploadVariantBlob(_ data: Data, to target: UploadTarget) async throws -> ConvexID {
        guard let url = URL(string: target.uploadUrl) else {
            throw UploadError.invalidUploadURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = data
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")

        let (responseData, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              200 ..< 300 ~= httpResponse.statusCode else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw UploadError.uploadFailed(statusCode: statusCode)
        }

        do {
            return try JSONDecoder().decode(UploadBlobResponse.self, from: responseData).storageId
        } catch {
            throw UploadError.invalidImageData
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
