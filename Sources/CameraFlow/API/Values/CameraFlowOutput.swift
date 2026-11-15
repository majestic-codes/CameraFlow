//
//  CameraFlowOutput.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 09.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// The size, the file format and the metadata of the photos the app receives from the flow.
///
/// The output is a constraint of the app, not a choice of the user: an option of the camera's Format panel that
/// would break it (RAW under a smaller size, a re-encoded format or stripped metadata) is not offered.
/// Where the app lets the user pick a quality (``CameraFlowConfiguration/photoQuality``), the choice only narrows the
/// output: a photo is never larger or less compressed than the output says.
/// ``CameraFlowConfiguration/output`` applies to the photos taken with the camera and their copies with a drawing or
/// the second camera's circle. By default it applies to the photos picked from the photo library as well: an app that
/// treats those otherwise gives them their own output in ``CameraFlowConfiguration/libraryOutput``, see
/// ``CameraFlowLibraryOutput``. The copy of a camera photo in the system photo library, when the flow saves one, is
/// never constrained: it is the camera's own photo.
///
/// The size of a photo is two steps. The camera captures at its own resolution, which the output never changes: 12 MP
/// where the camera has it (4032 x 3024 for 4:3), its largest otherwise. The 24 MP and 48 MP of a Pro camera are not
/// captured, and neither is a deferred photo (`AVCaptureDeferredPhotoProxy`), which is not a finished full-size photo
/// when it is delivered. ``size`` then scales a larger photo down with ImageIO, after the capture. So
/// ``CameraFlowOutputSize/original`` is the camera's 12 MP, not the most the sensor has, and a
/// ``CameraFlowOutputSize/longSide(maximum:)`` above 4032 gives 12 MP.
///
/// The compression is a setting of its own, the quality inside ``format``: ImageIO writes it as
/// `kCGImageDestinationLossyCompressionQuality`. A photo that is encoded again, because it is scaled, its format
/// changes or its metadata is stripped, is a new lossy generation: see ``CameraFlowOutputFormat`` for what it keeps.
///
/// The default output adds no step of its own: it does not scale, re-encode or strip a file. A photo from the
/// library is the library's file byte for byte. A camera photo is the camera's file byte for byte when it is 4:3 and
/// records neither a location nor a direction, and always as RAW, which records neither. A location or a direction
/// is written into the metadata of the camera's file without encoding the image again. A 16:9 or 1:1 HEIF or JPEG
/// photo is cropped from the sensor's 4:3 and encoded once more, at a compression quality of 0.9, with its metadata
/// and its auxiliary images. A photo that holds data the crop cannot keep, such as depth, is handed over whole with
/// ``CameraFlowPhoto/framedRegion``, as a 16:9 or 1:1 RAW photo is.
public struct CameraFlowOutput: Sendable, Hashable {
    /// The largest size of a photo. Default ``CameraFlowOutputSize/original``.
    public var size = CameraFlowOutputSize.original
    /// The file format of a photo. Default ``CameraFlowOutputFormat/original``.
    public var format = CameraFlowOutputFormat.original
    /// What the file says about the photo besides its pixels. Default ``CameraFlowOutputMetadata/kept``.
    public var metadata = CameraFlowOutputMetadata.kept

    /// Creates the output of the default flow: the files as they are. Change the properties that should differ.
    public init() {}

    /// Whether a file reaches the app in the format and with the metadata it has, which a DNG needs: it cannot be
    /// encoded again or stripped.
    var leavesFilesAsTheyAre: Bool {
        format == .original && metadata == .kept
    }

    /// Stops the program on an output no photo can meet.
    /// - Precondition: a `longSide(maximum:)` is at least 1, and a compression quality lies in 0...1.
    func validate() {
        size.validate(name: "CameraFlowOutput.size")
        if let quality = format.compressionQuality {
            precondition((0...1).contains(quality), "A compression quality lies in 0...1, not \(quality)")
        }
    }
}

/// The largest size of a photo the app receives.
///
/// The cases are fixed for 1.x: a new value comes as a new type or property, never as a new case, so a `switch`
/// needs no `default`.
public enum CameraFlowOutputSize: Sendable, Hashable {
    /// The size the camera captures at, 12 MP where the camera has it (see ``CameraFlowOutput``), and a library photo
    /// as it is. No photo is scaled.
    case original
    /// At most this many pixels on the long side, at least 1, the short side scaled with it. The camera captures at
    /// its own resolution all the same (`AVCapturePhotoSettings.maxPhotoDimensions` stays the camera's), and a photo
    /// that is larger than the limit, from the camera or from the library, is then scaled down with ImageIO: the
    /// aspect ratio, the orientation and the metadata are kept. A photo within the limit is not touched, so a limit
    /// above 4032 gives the camera's 12 MP and never more.
    case longSide(maximum: Int)

    /// The standard quality: 1920 pixels on the long side, so 1920 x 1440 for a 4:3 photo (2.8 MP) and 1920 x 1080
    /// for a 16:9 one.
    public static let standard = Self.longSide(maximum: 1920)

    /// The most pixels a photo may have on its long side, nil without a limit.
    var maximumLongSide: Int? {
        switch self {
        case .original: nil
        case let .longSide(maximum): maximum
        }
    }

    /// The stricter of this size and another: the smaller limit where either has one, `.original` where neither has.
    func narrowed(by other: Self) -> Self {
        let limits = [maximumLongSide, other.maximumLongSide].compactMap(\.self)
        guard let limit = limits.min() else { return .original }
        return .longSide(maximum: limit)
    }

    /// Stops the program on a size no photo can have, named in the message as `name`.
    /// - Precondition: a `longSide(maximum:)` is at least 1.
    func validate(name: String) {
        if case let .longSide(maximum) = self {
            precondition(maximum >= 1, "\(name).longSide must be at least 1 pixel, not \(maximum)")
        }
    }
}

/// The file format of a photo the app receives.
///
/// Re-encoding is one more lossy generation. With the metadata kept, a re-encoded photo keeps everything else its file
/// holds: the HDR gain maps scaled with the pixels, the mattes and the depth, every metadata tag, the XMP included, and
/// in a HEIC the bit depth of a 10-bit photo and both images of a spatial photo. A JPEG is 8-bit and holds one image,
/// so a spatial photo becomes its left eye. A scaled photo of the ``original`` format is encoded again as well, at a
/// compression quality of 0.9: in its own type where ImageIO writes that type (JPEG, HEIC, PNG and TIFF), and as a HEIC
/// otherwise, such as a DNG, a HEIF, a GIF or a WebP picked from the library.
///
/// The cases are fixed for 1.x: a new value comes as a new type or property, never as a new case, so a `switch`
/// needs no `default`.
public enum CameraFlowOutputFormat: Sendable, Hashable {
    /// The type the camera or the library gave the file: a HEIC, or a JPEG on a camera that cannot encode HEVC, a DNG
    /// for RAW, and whatever type a library photo has. The camera's Format panel offers RAW only in this format.
    case original
    /// A JPEG at this compression quality, from 0 (smallest) to 1 (best). A RAW photo cannot be asked for.
    case jpeg(quality: Double)
    /// A HEIC at this compression quality, from 0 (smallest) to 1 (best). A RAW photo cannot be asked for.
    case heic(quality: Double)

    /// The compression quality of a re-encoded photo, nil for the original format.
    var compressionQuality: Double? {
        switch self {
        case .original: nil
        case let .jpeg(quality), let .heic(quality): quality
        }
    }
}

/// What a photo file the app receives says besides its pixels.
///
/// The cases are fixed for 1.x: a new value comes as a new type or property, never as a new case, so a `switch`
/// needs no `default`.
public enum CameraFlowOutputMetadata: Sendable, Hashable {
    /// Everything the camera wrote (EXIF, TIFF, maker notes, XMP, the HDR gain map) plus the GPS dictionary of the
    /// place the photo was taken, or everything the library's file has. A photo picked from the library keeps the
    /// location of its file, where the system picker hands one over, whatever ``CameraFlowConfiguration/photoLocation``
    /// says: only ``stripped`` takes it out.
    case kept
    /// No EXIF, GPS (with the direction), maker notes, XMP or IPTC: the file holds the pixels, upright (the orientation
    /// applied, so the tag is gone), their colour profile and their size, encoded again as 8-bit SDR without gain maps,
    /// mattes or depth, in its own format or the one ``CameraFlowOutputFormat`` asks for. A RAW photo cannot be asked
    /// for. The copy a flow saves to the system photo library keeps its metadata and location: stripping is for what
    /// leaves the device. A flow whose photos cannot carry a location, because its output strips the metadata and it
    /// never saves to the photo library, treats ``CameraFlowConfiguration/photoLocation`` and
    /// ``CameraFlowConfiguration/photoDirection`` as off: it never asks for access, follows neither the location nor
    /// the compass and calls no `locationProvider`.
    case stripped
}

/// The output of the photos picked from the photo library: the camera's, or one of their own.
///
/// ```swift
/// // Constrain the camera photos only: the picks reach the app as the library has them.
/// configuration.output.size = .standard
/// configuration.libraryOutput = .separate(CameraFlowOutput())
///
/// // Constrain the picks only.
/// var picks = CameraFlowOutput()
/// picks.size = .standard
/// configuration.libraryOutput = .separate(picks)
/// ```
///
/// The quality the user picks on the camera's Format panel (``CameraFlowConfiguration/photoQuality``) narrows the
/// output of the camera photos. It narrows the picks too under ``sameAsCamera``, and never under ``separate(_:)``,
/// which is the app's alone.
///
/// The cases are fixed for 1.x: a new value comes as a new type or property, never as a new case, so a `switch`
/// needs no `default`.
public enum CameraFlowLibraryOutput: Sendable, Hashable {
    /// The camera's output, narrowed by the quality the user picked, as for a camera photo. The default.
    case sameAsCamera
    /// This output, whatever quality the user picks. `CameraFlowOutput()` keeps every pick as the library gave it.
    case separate(CameraFlowOutput)

    /// Stops the program on an output no photo can meet.
    func validate() {
        if case let .separate(output) = self {
            output.validate()
        }
    }
}
