//
//  FocusLock.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// The stock AE/AF Lock: the focus and the exposure held at a point, which a long press on the viewfinder sets.
enum FocusLock: Equatable {
    /// A long press began: the camera focuses and exposes at the point, and the lock takes once the press has held
    /// for `FocusModel.lockDelay` and the camera has settled. A finger that lets go sooner gives the lock up.
    case pressing
    /// The press held long enough, or VoiceOver asked for the lock: it takes once the camera has settled.
    case settling
    /// The focus and the exposure hold until a tap elsewhere, a change of the lens or of the camera, or the camera
    /// stopping. The exposure bias still changes.
    case locked
}
