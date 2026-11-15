//
//  AccessibilityLanguageScope.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI
import UIKit

/// Makes VoiceOver speak a language while the view is in a window, and gives the app its own back when the view
/// leaves it: when the flow is dismissed, and while a screen the app presents covers it. The language applies to
/// the whole app, the only scope VoiceOver takes it in for the labels of SwiftUI.
///
/// The app is found up the responder chain of the view, so the code also builds in an app extension, which has no
/// app to speak for and is left alone.
struct AccessibilityLanguageScope: UIViewRepresentable {
    /// The language as a BCP 47 tag, nil to leave the app's own.
    let language: String?

    func makeUIView(context: Context) -> AccessibilityLanguageView {
        let view = AccessibilityLanguageView()
        view.language = language
        return view
    }

    func updateUIView(_ view: AccessibilityLanguageView, context: Context) {
        view.language = language
    }
}

/// An empty view that sets the accessibility language of its app while it is in a window.
final class AccessibilityLanguageView: UIView {
    var language: String? {
        didSet {
            guard language != oldValue, window != nil else { return }
            restore()
            apply()
        }
    }

    /// The app whose language the view set, nil while it sets none.
    private weak var application: UIApplication?
    /// The language the app had before.
    private var languageBefore: String?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        restore()
        if window != nil {
            apply()
        }
    }

    private func apply() {
        guard let language else { return }
        let responders = sequence(first: self as UIResponder) { responder in
            responder.next
        }
        guard let application = responders.lazy.compactMap({ $0 as? UIApplication }).first else { return }
        self.application = application
        languageBefore = application.accessibilityLanguage
        application.accessibilityLanguage = language
    }

    private func restore() {
        guard let application else { return }
        application.accessibilityLanguage = languageBefore
        self.application = nil
        languageBefore = nil
    }
}
#endif
