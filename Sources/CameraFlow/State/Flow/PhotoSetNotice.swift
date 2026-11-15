//
//  PhotoSetNotice.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// What the set has to say about something that did not go as asked: picks from the photo library that did not
/// get into it, a save to the photo library that failed, and a hand-over that did not happen.
enum PhotoSetNotice: Equatable {
    /// This many picks could not be loaded.
    case importFailed(count: Int)
    /// Picks were left out, because the set takes no more than this many photos.
    case limitReached(Int)
    /// The copy of a photo with its drawing could not be written, so the set was not handed over.
    case copyFailed
    /// A pick could not be loaded, or the copy of a photo with its drawing written, for want of room on the device.
    case notEnoughStorage
    /// A photo saved right after its shot, or at a check mark that left the set open, did not reach the photo
    /// library. It stays in the set.
    case librarySaveFailed(CameraFlowPhotoLibrarySaveFailure)
}
