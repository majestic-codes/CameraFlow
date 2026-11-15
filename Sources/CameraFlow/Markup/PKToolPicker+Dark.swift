//
//  PKToolPicker+Dark.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import PencilKit
import UIKit

extension PKToolPicker {

    /// The system tool picker in the dark appearance of the flow, with the colours it offers for dark.
    static func makeDark() -> PKToolPicker {
        let toolPicker = PKToolPicker()
        toolPicker.colorUserInterfaceStyle = .dark
        toolPicker.overrideUserInterfaceStyle = .dark
        return toolPicker
    }

    /// Shows the picker while `responder` is the first responder, which it becomes now, and gives `observer` the
    /// tools picked in it.
    @MainActor
    func show(for responder: UIResponder, observer: any PKToolPickerObserver) {
        addObserver(observer)
        setVisible(true, forFirstResponder: responder)
        responder.becomeFirstResponder()
    }

    /// Hides the picker for `responder`, which stops being the first responder, and stops giving `observer` the
    /// tools picked in it.
    @MainActor
    func hide(for responder: UIResponder, observer: any PKToolPickerObserver) {
        setVisible(false, forFirstResponder: responder)
        removeObserver(observer)
        responder.resignFirstResponder()
    }
}
#endif
