//
//  CaptureSubjectAreaObserver.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import AVFoundation

/// Brings the changes of the picture of one camera to a handler, for as long as it lives. A camera reports them while
/// it watches its picture, after it focused at a point.
final class CaptureSubjectAreaObserver {
    private let observer: any NSObjectProtocol

    init(device: AVCaptureDevice, onChange: @escaping @Sendable () -> Void) {
        observer = NotificationCenter.default.addObserver(
            forName: AVCaptureDevice.subjectAreaDidChangeNotification,
            object: device,
            queue: nil
        ) { _ in
            onChange()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(observer)
    }
}
#endif
