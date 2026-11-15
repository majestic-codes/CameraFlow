//
//  CaptureDualFormats.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 09.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import AVFoundation

/// The devices and the formats a multi-camera session can run the back and the front camera in.
enum CaptureDualFormats {
    struct DevicePair {
        let back: AVCaptureDevice
        let front: AVCaptureDevice
    }

    /// The circle's frame is drawn at about a third of the photo's width, which a photo with this short side
    /// covers.
    private static let circlePhotoShortSide: Int32 = 1080

    /// The back camera with the most lenses and the front wide camera that the device can run together, nil where
    /// it cannot run two cameras.
    static func devicePair() -> DevicePair? {
        guard AVCaptureMultiCamSession.isMultiCamSupported else { return nil }
        let backTypes = CaptureDeviceInspector.deviceTypes
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: backTypes,
            mediaType: .video,
            position: .unspecified
        )
        let sets = discovery.supportedMultiCamDeviceSets
        let fronts = discovery.devices.filter { $0.position == .front && $0.deviceType == .builtInWideAngleCamera }
        let backs = backTypes.flatMap { type in
            discovery.devices.filter { $0.position == .back && $0.deviceType == type }
        }
        for back in backs where backFormats(of: back).isEmpty == false {
            for front in fronts where frontFormats(of: front).isEmpty == false {
                if sets.contains(where: { $0.contains(back) && $0.contains(front) }) {
                    return DevicePair(back: back, front: front)
                }
            }
        }
        return nil
    }

    /// The 4:3 formats of the back camera a multi-camera session runs with a photo size the Format panel names,
    /// the largest photo first.
    static func backFormats(of device: AVCaptureDevice) -> [AVCaptureDevice.Format] {
        dualFormats(of: device)
            .filter(hasNamedPhotoSize)
            .sorted { photoArea($0) > photoArea($1) }
    }

    /// The 4:3 front formats a multi-camera session runs, in the order to try them: those with a photo size the
    /// Format panel names and large enough for the circle first, as the front camera can take the viewfinder; within
    /// each group the cheapest first, binned before full sensor readout and small before large.
    static func frontFormats(of device: AVCaptureDevice) -> [AVCaptureDevice.Format] {
        let cheapestFirst = dualFormats(of: device).sorted { first, second in
            if first.isVideoBinned != second.isVideoBinned {
                return first.isVideoBinned
            }
            return videoArea(first) < videoArea(second)
        }
        let preferred = cheapestFirst.filter { hasNamedPhotoSize($0) && isLargeEnoughForCircle($0) }
        let others = cheapestFirst.filter { !(hasNamedPhotoSize($0) && isLargeEnoughForCircle($0)) }
        return preferred + others
    }

    /// The size of a photo for the circle: the smallest of the format that covers the circle and fits in `limit`, or
    /// `limit` itself when no smaller one does.
    static func circlePhotoDimensions(
        of format: AVCaptureDevice.Format,
        within limit: CMVideoDimensions
    ) -> CMVideoDimensions {
        let sizes = format.supportedMaxPhotoDimensions.map { (width: $0.width, height: $0.height) }
        let limitSize = PhotoCaptureResolution(width: limit.width, height: limit.height)
        let smallest = PhotoCaptureResolution.smallest(reaching: circlePhotoShortSide, among: sizes, within: limitSize)
        guard let smallest else { return limit }
        return CMVideoDimensions(width: smallest.width, height: smallest.height)
    }

    private static func largestPhotoDimensions(of format: AVCaptureDevice.Format) -> CMVideoDimensions? {
        format.supportedMaxPhotoDimensions.max { $0.width * $0.height < $1.width * $1.height }
    }

    private static func dualFormats(of device: AVCaptureDevice) -> [AVCaptureDevice.Format] {
        device.formats.filter { format in
            let dimensions = format.formatDescription.dimensions
            return format.isMultiCamSupported && Int(dimensions.width) * 3 == Int(dimensions.height) * 4
        }
    }

    private static func hasNamedPhotoSize(_ format: AVCaptureDevice.Format) -> Bool {
        format.supportedMaxPhotoDimensions.contains { size in
            PhotoCaptureResolution(width: size.width, height: size.height).isPreferred
        }
    }

    private static func isLargeEnoughForCircle(_ format: AVCaptureDevice.Format) -> Bool {
        let photoShortSide = largestPhotoDimensions(of: format).map { min($0.width, $0.height) } ?? 0
        return photoShortSide >= circlePhotoShortSide
    }

    private static func photoArea(_ format: AVCaptureDevice.Format) -> Int {
        largestPhotoDimensions(of: format).map { Int($0.width) * Int($0.height) } ?? 0
    }

    private static func videoArea(_ format: AVCaptureDevice.Format) -> Int {
        let dimensions = format.formatDescription.dimensions
        return Int(dimensions.width) * Int(dimensions.height)
    }
}
#endif
