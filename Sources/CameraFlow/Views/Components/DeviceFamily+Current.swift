//
//  DeviceFamily+Current.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import UIKit

extension DeviceFamily {
    /// The family of the device the flow runs on, by the idiom of its interface.
    @MainActor
    static var current: Self {
        UIDevice.current.userInterfaceIdiom == .pad ? .pad : .phone
    }
}
#endif
