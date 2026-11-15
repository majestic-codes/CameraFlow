//
//  InterfaceOrientationReader.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 12.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI
import UIKit

/// Reports the quarter the interface of the window stands in, at once and whenever it turns. The flow's own
/// presentation keeps it portrait on iPhone, and iPad turns it with the device.
struct InterfaceOrientationReader: UIViewRepresentable {
    let onChange: (CameraOrientation) -> Void

    func makeUIView(context: Context) -> InterfaceOrientationView {
        let view = InterfaceOrientationView()
        view.onChange = onChange
        return view
    }

    func updateUIView(_ view: InterfaceOrientationView, context: Context) {
        view.onChange = onChange
    }
}

/// An empty view that follows the geometry of the scene of its window.
final class InterfaceOrientationView: UIView {
    var onChange: ((CameraOrientation) -> Void)?
    private var observation: NSKeyValueObservation?

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
        observation?.invalidate()
        observation = nil
        guard let scene = window?.windowScene else { return }
        report(scene.effectiveGeometry.interfaceOrientation)
        // The scene posts the change of its geometry on the main thread.
        observation = scene.observe(\.effectiveGeometry, options: [.new]) { [weak self] scene, _ in
            MainActor.assumeIsolated {
                self?.report(scene.effectiveGeometry.interfaceOrientation)
            }
        }
    }

    private func report(_ interfaceOrientation: UIInterfaceOrientation) {
        guard let quarter = Self.quarter(of: interfaceOrientation) else { return }
        onChange?(quarter.deviceOrientation)
    }

    /// The quarter of an interface orientation, nil for one that is not known yet.
    private static func quarter(of interfaceOrientation: UIInterfaceOrientation) -> InterfaceQuarter? {
        switch interfaceOrientation {
        case .portrait: .portrait
        case .portraitUpsideDown: .portraitUpsideDown
        case .landscapeLeft: .landscapeLeft
        case .landscapeRight: .landscapeRight
        case .unknown: nil
        @unknown default: nil
        }
    }
}
#endif
