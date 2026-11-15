//
//  PhotoFileFacts.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import ImageIO

/// What a photo file contains, read back with ImageIO, to compare an original with a copy edited from it.
struct PhotoFileFacts {
    let fileName: String
    let typeIdentifier: String
    let byteCount: Int?
    let pixelWidth: Int
    let pixelHeight: Int
    let orientation: Int
    let exifKeyCount: Int
    let hasGPS: Bool
    let hasMakerApple: Bool
    let profileName: String
    let bitDepth: Int?
    let auxiliaryImages: [String]

    enum ReadError: Error {
        case notReadableByImageIO(URL)
        case noImageProperties(URL)
        /// The image of the file does not say how many pixels wide and high it is.
        case noPixelSize(URL)
    }

    init(fileURL: URL) throws {
        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else {
            throw ReadError.notReadableByImageIO(fileURL)
        }
        let index = CGImageSourceGetPrimaryImageIndex(source)
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [String: Any] else {
            throw ReadError.noImageProperties(fileURL)
        }
        guard
            let pixelWidth = properties[kCGImagePropertyPixelWidth as String] as? Int,
            let pixelHeight = properties[kCGImagePropertyPixelHeight as String] as? Int
        else {
            throw ReadError.noPixelSize(fileURL)
        }
        let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any]
        fileName = fileURL.lastPathComponent
        typeIdentifier = CGImageSourceGetType(source).map { $0 as String } ?? "unknown"
        byteCount = try fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        orientation = properties[kCGImagePropertyOrientation as String] as? Int ?? 1
        exifKeyCount = exif?.count ?? 0
        hasGPS = properties[kCGImagePropertyGPSDictionary as String] != nil
        hasMakerApple = properties[kCGImagePropertyMakerAppleDictionary as String] != nil
        profileName = properties[kCGImagePropertyProfileName as String] as? String ?? "none"
        bitDepth = properties[kCGImagePropertyDepth as String] as? Int
        auxiliaryImages = Self.auxiliaryTypeNames
            .filter { type, _ in CGImageSourceCopyAuxiliaryDataInfoAtIndex(source, index, type) != nil }
            .map { _, name in name }
    }

    /// The facts as one line, in the same order for every file.
    var line: String {
        [
            fileName,
            typeIdentifier,
            "\(pixelWidth)x\(pixelHeight)",
            "bytes \(byteCount.map(String.init) ?? "unknown")",
            "orientation \(orientation)",
            "exif \(exifKeyCount)",
            "gps \(hasGPS)",
            "maker \(hasMakerApple)",
            "profile \(profileName)",
            "depth \(bitDepth.map(String.init) ?? "unknown")",
            "auxiliary [\(auxiliaryImages.joined(separator: ", "))]"
        ].joined(separator: " | ")
    }

    /// The auxiliary images a photo file may carry, with the names used in the reports.
    private static var auxiliaryTypeNames: [(CFString, String)] {
        var names: [(CFString, String)] = [
            (kCGImageAuxiliaryDataTypeHDRGainMap, "HDRGainMap"),
            (kCGImageAuxiliaryDataTypeDepth, "Depth"),
            (kCGImageAuxiliaryDataTypeDisparity, "Disparity"),
            (kCGImageAuxiliaryDataTypePortraitEffectsMatte, "PortraitEffectsMatte"),
            (kCGImageAuxiliaryDataTypeSemanticSegmentationSkinMatte, "SkinMatte"),
            (kCGImageAuxiliaryDataTypeSemanticSegmentationHairMatte, "HairMatte"),
            (kCGImageAuxiliaryDataTypeSemanticSegmentationTeethMatte, "TeethMatte"),
            (kCGImageAuxiliaryDataTypeSemanticSegmentationGlassesMatte, "GlassesMatte"),
            (kCGImageAuxiliaryDataTypeSemanticSegmentationSkyMatte, "SkyMatte")
        ]
        if #available(iOS 18, *) {
            names.append((kCGImageAuxiliaryDataTypeISOGainMap, "ISOGainMap"))
        }
        return names
    }
}
