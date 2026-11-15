//
//  CapturePhotoSettingsBuilder.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import AVFoundation
import CoreLocation

/// Turns a checked request into photo settings for the output, or throws when the output cannot honour it.
enum CapturePhotoSettingsBuilder {
    struct Built {
        let settings: AVCapturePhotoSettings
        let encoding: PhotoCaptureEncoding
    }

    static func settings(for request: PhotoCaptureRequest, output: AVCapturePhotoOutput) throws -> Built {
        let built = try formatSettings(for: request.format, output: output)
        let settings = built.settings
        let deviceFlashMode = deviceFlashMode(request.flashMode)
        guard output.supportedFlashModes.contains(deviceFlashMode) || request.flashMode == .off else {
            throw CameraServiceError.unsupported(.flash(request.flashMode))
        }
        if output.supportedFlashModes.contains(deviceFlashMode) {
            settings.flashMode = deviceFlashMode
        }
        let dimensions = CMVideoDimensions(width: request.resolution.width, height: request.resolution.height)
        guard dimensions.width <= output.maxPhotoDimensions.width else {
            throw CameraServiceError.unsupported(.resolution)
        }
        settings.maxPhotoDimensions = dimensions
        if request.isLivePhotoEnabled {
            guard output.isLivePhotoCaptureEnabled else {
                throw CameraServiceError.unsupported(.livePhoto)
            }
            settings.livePhotoMovieFileURL = try CaptureFileStore.temporaryMovieURL()
            if request.locatesLivePhotoMovie, let location = request.location {
                settings.livePhotoMovieMetadata = [movieLocation(location)]
            }
        }
        return built
    }

    /// The settings of a processed photo: HEIF where the output encodes HEVC, JPEG otherwise, at the best quality and
    /// with the lens correction the output was set up for.
    static func processedSettings(for output: AVCapturePhotoOutput) -> Built {
        let usesHEVC = output.availablePhotoCodecTypes.contains(.hevc)
        let codec: AVVideoCodecType = usesHEVC ? .hevc : .jpeg
        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: codec])
        settings.photoQualityPrioritization = qualityPrioritization(for: .heif, output: output)
        settings.isAutoContentAwareDistortionCorrectionEnabled = output.isContentAwareDistortionCorrectionEnabled
        return Built(settings: settings, encoding: usesHEVC ? .heif : .jpeg)
    }

    /// The settings an output watches its scene with for the flash in a mode, as a photo in the format is taken: the
    /// mode where the output offers it and off otherwise, as a capture takes it, at the quality prioritization of that
    /// capture, which moves the light level the flash fires at.
    static func sceneMonitoringSettings(
        for flashMode: CameraFlowFlashMode,
        format: CameraFlowPhotoFormat,
        output: AVCapturePhotoOutput
    ) -> AVCapturePhotoSettings {
        let settings = AVCapturePhotoSettings()
        let deviceFlashMode = deviceFlashMode(flashMode)
        settings.flashMode = output.supportedFlashModes.contains(deviceFlashMode) ? deviceFlashMode : .off
        settings.photoQualityPrioritization = qualityPrioritization(for: format, output: output)
        return settings
    }

    /// The quality prioritization a capture in the format asks for, which the monitoring of its scene follows: the
    /// best the output is set up for, for a processed photo, and the balanced default of the settings for RAW.
    private static func qualityPrioritization(
        for format: CameraFlowPhotoFormat,
        output: AVCapturePhotoOutput
    ) -> AVCapturePhotoOutput.QualityPrioritization {
        switch format {
        case .heif: output.maxPhotoQualityPrioritization
        case .raw: .balanced
        }
    }

    /// The location of the photo as the Live Photo movie carries it, in its ISO 6709 QuickTime metadata.
    private static func movieLocation(_ location: CLLocation) -> AVMetadataItem {
        let item = AVMutableMetadataItem()
        item.identifier = .quickTimeMetadataLocationISO6709
        item.dataType = kCMMetadataBaseDataType_UTF8 as String
        // AVFoundation holds the value of a metadata item as an Objective-C object, which a string bridges to.
        item.value = PhotoLocationMetadata.iso6709(for: location) as AnyObject as? any NSCopying & NSObjectProtocol
        return item
    }

    private static func formatSettings(
        for format: CameraFlowPhotoFormat,
        output: AVCapturePhotoOutput
    ) throws -> Built {
        switch format {
        case .heif:
            let built = processedSettings(for: output)
            // The file embeds a small JPEG of the photo, as the stock camera's does, at the size the output picks.
            if built.settings.availableEmbeddedThumbnailPhotoCodecTypes.contains(.jpeg) {
                built.settings.embeddedThumbnailPhotoFormat = [AVVideoCodecKey: AVVideoCodecType.jpeg]
            }
            return built
        case .raw:
            let rawFormats = output.availableRawPhotoPixelFormatTypes
            guard output.isAppleProRAWEnabled,
                  let rawFormat = rawFormats.first(where: AVCapturePhotoOutput.isAppleProRAWPixelFormat) else {
                throw CameraServiceError.unsupported(.format(.raw))
            }
            let settings = AVCapturePhotoSettings(rawPixelFormatType: rawFormat)
            settings.photoQualityPrioritization = qualityPrioritization(for: .raw, output: output)
            return Built(settings: settings, encoding: .appleProRAW)
        }
    }

    private static func deviceFlashMode(_ flashMode: CameraFlowFlashMode) -> AVCaptureDevice.FlashMode {
        switch flashMode {
        case .auto: .auto
        case .alwaysOn: .on
        case .off: .off
        }
    }
}
#endif
