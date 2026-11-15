//
//  PhotoCaptureCropper.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import ImageIO

/// Crops a processed photo (HEIF or JPEG) to an aspect ratio around its centre, keeping everything the camera
/// wrote: every property dictionary and the XMP, the colour profile and bit depth, and the auxiliary images (gain
/// maps, mattes) cropped to the same region. The EXIF tags that describe the pixels (their size, the subject area)
/// describe the cropped ones, and the embedded thumbnail is made again of them.
///
/// The crop works on the stored pixels, which makes it independent of the orientation tag: the tag stays as it was.
/// The image is encoded again, so the pixels go through one more lossy generation.
enum PhotoCaptureCropper {
    enum Outcome: Equatable {
        /// The photo already has the ratio; the bytes are the original ones.
        case unchanged
        case cropped(Data)
        /// The photo holds data that cannot be cropped faithfully, and is handed over whole.
        case uncroppable(String)
    }

    /// The cropped image with what goes into its file besides its pixels. The metadata holds the XMP the properties
    /// cannot express, and an image written with both takes the values of the metadata.
    private struct CroppedImage {
        let image: CGImage
        let metadata: CGImageMetadata
        let properties: [CFString: Any]
        let auxiliaryImages: [(type: CFString, info: [CFString: Any])]
    }

    static func crop(_ data: Data, to aspectRatio: CameraFlowAspectRatio) throws -> Outcome {
        let photo = try sourcePhoto(of: data)
        let rectangle = cropRectangle(width: photo.pixelWidth, height: photo.pixelHeight, aspectRatio: aspectRatio)
        if Int(rectangle.width) == photo.pixelWidth, Int(rectangle.height) == photo.pixelHeight {
            return .unchanged
        }
        let frame = CGSize(width: photo.pixelWidth, height: photo.pixelHeight)
        var auxiliaryImages: [(type: CFString, info: [CFString: Any])] = []
        for (type, info) in photo.auxiliaryImages {
            switch PhotoAuxiliaryImage.crop(info, type: type, to: rectangle, in: frame) {
            case let .success(cropped):
                auxiliaryImages.append((type, cropped))
            case let .failure(reason):
                return .uncroppable(reason.description)
            }
        }
        var subjectArea: [Int] = []
        if !photo.subjectArea.isEmpty {
            do {
                subjectArea = try PhotoSubjectArea.cropped(photo.subjectArea, to: rectangle)
            } catch {
                return .uncroppable(error.description)
            }
        }
        guard let image = photo.storedImage() else {
            throw CameraServiceError.cannotCrop("The photo cannot be decoded")
        }
        guard let cropped = image.cropping(to: rectangle) else {
            throw CameraServiceError.cannotCrop("The crop rectangle is outside the photo")
        }
        let pixels = PhotoPixelDescription(width: cropped.width, height: cropped.height, subjectArea: subjectArea)
        let metadata: CGImageMetadata
        do {
            metadata = try photo.metadata(describing: pixels, isUpright: false)
        } catch {
            throw CameraServiceError.cannotCrop(error.description)
        }
        let croppedImage = CroppedImage(
            image: cropped,
            metadata: metadata,
            properties: croppedProperties(of: photo, pixels: pixels),
            auxiliaryImages: auxiliaryImages
        )
        return .cropped(try encode(croppedImage, as: photo))
    }

    /// The centred rectangle of the ratio inside a frame of stored pixels, with even sides.
    static func cropRectangle(width: Int, height: Int, aspectRatio: CameraFlowAspectRatio) -> CGRect {
        let longSide = Double(max(width, height))
        let shortSide = Double(min(width, height))
        let longPerShort = Double(aspectRatio.heightPerWidth)
        var croppedLong = longSide
        var croppedShort = shortSide
        if longSide / shortSide > longPerShort {
            croppedLong = evenFloor(shortSide * longPerShort)
        } else {
            croppedShort = evenFloor(longSide / longPerShort)
        }
        let isLandscape = width >= height
        let croppedWidth = isLandscape ? croppedLong : croppedShort
        let croppedHeight = isLandscape ? croppedShort : croppedLong
        return CGRect(
            x: ((Double(width) - croppedWidth) / 2).rounded(.down),
            y: ((Double(height) - croppedHeight) / 2).rounded(.down),
            width: croppedWidth,
            height: croppedHeight
        )
    }

    private static func evenFloor(_ value: Double) -> Double {
        (value / 2).rounded(.down) * 2
    }

    /// The primary image of the camera's photo.
    private static func sourcePhoto(of data: Data) throws(CameraServiceError) -> ImageSourcePhoto {
        do throws(ImageSourcePhoto.ReadFailure) {
            return try ImageSourcePhoto(data: data)
        } catch {
            throw switch error {
            case .unreadableFile: .cannotCrop("The photo cannot be decoded")
            case .unreadableImage: .cannotCrop("The photo has no readable properties")
            }
        }
    }

    /// The source properties with what the EXIF says of the cropped pixels, and a thumbnail of them asked for.
    /// Everything else is copied as it is.
    private static func croppedProperties(
        of photo: ImageSourcePhoto,
        pixels: PhotoPixelDescription
    ) -> [CFString: Any] {
        var croppedProperties = photo.properties
        croppedProperties[kCGImagePropertyPixelWidth] = pixels.width
        croppedProperties[kCGImagePropertyPixelHeight] = pixels.height
        if !photo.exif.isEmpty {
            let exif = photo.exif.merging(pixels.exifTags) { _, cropped in cropped }
            croppedProperties[kCGImagePropertyExifDictionary] = exif
        }
        croppedProperties[kCGImageDestinationLossyCompressionQuality] = ImageEncoding.defaultCompressionQuality
        croppedProperties[kCGImageDestinationEmbedThumbnail] = true
        return croppedProperties
    }

    /// The cropped photo in the type of the photo.
    private static func encode(
        _ cropped: CroppedImage,
        as photo: ImageSourcePhoto
    ) throws(CameraServiceError) -> Data {
        do {
            return try ImageEncoding.data(typeIdentifier: photo.typeIdentifier) { destination in
                let properties = cropped.properties as CFDictionary
                CGImageDestinationAddImageAndMetadata(destination, cropped.image, cropped.metadata, properties)
                for auxiliary in cropped.auxiliaryImages {
                    CGImageDestinationAddAuxiliaryDataInfo(destination, auxiliary.type, auxiliary.info as CFDictionary)
                }
            }
        } catch {
            throw .cannotCrop("The cropped photo cannot be encoded: \(error)")
        }
    }
}
