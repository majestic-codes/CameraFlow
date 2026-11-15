//
//  InterfaceQuarter.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// The quarter the interface of a window stands in, as the system names it. The raw value is the name an app's
/// `UISupportedInterfaceOrientations` gives it in its Info.plist.
enum InterfaceQuarter: String, CaseIterable, Sendable {
    case portrait = "UIInterfaceOrientationPortrait"
    case portraitUpsideDown = "UIInterfaceOrientationPortraitUpsideDown"
    case landscapeLeft = "UIInterfaceOrientationLandscapeLeft"
    case landscapeRight = "UIInterfaceOrientationLandscapeRight"

    /// The quarter the device is held in while the interface stands this way: an interface turned to landscape
    /// right has the top of the device to the left, and the other way round.
    var deviceOrientation: CameraOrientation {
        switch self {
        case .portrait: .portrait
        case .portraitUpsideDown: .upsideDown
        case .landscapeRight: .landscapeLeft
        case .landscapeLeft: .landscapeRight
        }
    }
}
