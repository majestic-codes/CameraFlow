//
//  PhotoGainMap.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import ImageIO

/// The gain map of an HDR photo, as ImageIO reads and writes it: an auxiliary image with a pixel buffer, its
/// description and its metadata.
///
/// ImageIO carries the gain map into a copy when it is asked to (`kCGImageDestinationPreserveGainMap`), but not on
/// every system: the iOS 26.1 simulator ignores the option and writes the copy without one. The copy is checked for
/// what it lost, and a lost gain map is scaled here and written into the copy as an auxiliary image, which every
/// system keeps.
struct PhotoGainMap {
    let type: CFString
    let info: [CFString: Any]

    /// The gain map types ImageIO knows: Apple's own, and the ISO one where the system has it.
    static var types: [CFString] {
        var types = [kCGImageAuxiliaryDataTypeHDRGainMap]
        if #available(iOS 18, macOS 15, *) {
            types.append(kCGImageAuxiliaryDataTypeISOGainMap)
        }
        return types
    }

    /// The gain maps of an image of a photo file.
    static func gainMaps(of photo: ImageSourcePhoto) -> [Self] {
        types.compactMap { type in
            let info = photo.auxiliaryInfo(of: type)
            return info.isEmpty ? nil : Self(type: type, info: info)
        }
    }

    /// The gain map for a copy of the photo scaled by `scale`, nil when its pixels cannot be scaled here: a
    /// description that cannot be read, or a pixel format other than one byte per pixel. A scale of one keeps the
    /// gain map as it is, whatever its format.
    func scaled(by scale: Double) -> Self? {
        guard scale != 1 else { return self }
        let pixels: AuxiliaryPixels
        do {
            pixels = try AuxiliaryPixels(info: info, type: type)
        } catch {
            return nil
        }
        return pixels.scaled(by: scale).map { Self(type: type, info: $0.replacingPixels(in: info)) }
    }
}
