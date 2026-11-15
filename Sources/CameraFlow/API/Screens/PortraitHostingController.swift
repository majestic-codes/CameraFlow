//
//  PortraitHostingController.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI
import UIKit

/// Hosts the flow in an interface that stays portrait however the phone is held, in a window that is dark while
/// the flow is on screen, and owns the flow of its presentation. The SwiftUI cover presents it, and
/// `CameraFlowViewController` holds it as its child.
///
/// The flow expects a portrait interface: like the stock Camera it keeps its layout and turns single elements as
/// the phone rotates. A view cannot stop the app from rotating its interface, but a presented controller that
/// fills the window can: on iPhone the system keeps the interface portrait while it is on screen, even in an app
/// that allows landscape. iPad ignores it in an app that does not require full screen and turns the interface with
/// the device, and the flow lays itself out for the quarter the interface stands in. An app without portrait keeps
/// its own quarters, as `FlowInterfaceOrientations` says.
///
/// A system alert takes its style from the window, not from the controller under it or the colour scheme of a
/// view. So the window turns dark while the flow is on screen, and gets its own style back whenever the flow
/// leaves it: when the flow is dismissed, and when a screen the app presents full screen covers it.
///
/// The flow lives as long as the presentation: a screen the app presents over it keeps the set, and the
/// dismissal of the controller, or of a controller it stands in, ends the flow.
final class PortraitHostingController<Content: View>: UIHostingController<PresentedFlow<Content>> {
    /// Called once the controller has been dismissed, by any means.
    var onDismissed: (() -> Void)?
    /// The presentation that owns the flow.
    let presentation: FlowPresentationLifetime<EmbeddedMarkupCanvas>
    private let orientations: FlowInterfaceOrientations
    /// The window the flow made dark, nil while no window is.
    private weak var darkenedWindow: UIWindow?
    /// The style the darkened window had before.
    private var windowStyleBeforeFlow = UIUserInterfaceStyle.unspecified

    /// The host of a flow.
    /// - Parameters:
    ///   - content: The flow.
    ///   - inheritedModifiers: The modifiers of the flow around the view that presents it, under the ones of `content`.
    ///   - handOverObserver: Hears the hand-overs of the flow, nil where the flow's `onFinish` alone receives a set.
    init(
        content: Content,
        inheritedModifiers: FlowModifierEnvironment = FlowModifierEnvironment(),
        handOverObserver: (any PhotoSetHandOverObserver)? = nil
    ) {
        let presentation = FlowPresentationLifetime<EmbeddedMarkupCanvas>(handOverObserver: handOverObserver)
        self.presentation = presentation
        orientations = .ofApp
        let modifiers = inheritedModifiers
        let presented = PresentedFlow(content: content, presentation: presentation, inheritedModifiers: modifiers)
        super.init(rootView: presented)
    }

    @available(*, unavailable, message: "PortraitHostingController is created in code")
    required init?(coder: NSCoder) {
        nil
    }

    /// Whether the flow of the presentation has ended, handed over or left.
    var hasFlowEnded: Bool {
        presentation.hasFlowEnded
    }

    /// The quarters the interface stands in while the flow is on screen.
    var flowOrientations: FlowInterfaceOrientations {
        orientations
    }

    /// Hands the flow its content again, with the modifiers around the view that presents it, as SwiftUI updates that
    /// view.
    func show(_ content: Content, inheritedModifiers: FlowModifierEnvironment) {
        rootView = PresentedFlow(content: content, presentation: presentation, inheritedModifiers: inheritedModifiers)
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        orientations.mask
    }

    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        orientations.preferredOrientation
    }

    override var shouldAutorotate: Bool {
        orientations.quarters.count > 1
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // The views under the cover are still in the window, so accessibility has to be told to leave them out.
        view.accessibilityViewIsModal = true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard darkenedWindow == nil, let window = view.window else { return }
        darkenedWindow = window
        windowStyleBeforeFlow = window.overrideUserInterfaceStyle
        window.overrideUserInterfaceStyle = .dark
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        guard let darkenedWindow else { return }
        darkenedWindow.overrideUserInterfaceStyle = windowStyleBeforeFlow
        self.darkenedWindow = nil
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        guard isLeavingForGood else { return }
        presentation.end()
        onDismissed?()
    }

    /// Whether the controller leaves the screen for good, rather than being covered by another screen: dismissed,
    /// itself, with a controller it stands in or with the controller it was presented from, or taken out of the
    /// controller that holds it.
    private var isLeavingForGood: Bool {
        let holders = sequence(first: self as UIViewController) { controller in
            controller.parent ?? controller.presentingViewController
        }
        return holders.contains { controller in
            controller.isBeingDismissed || controller.isMovingFromParent
        }
    }
}

/// The content of a presented flow, with the presentation that owns the flow in its environment, and the modifiers of
/// the flow that the view presenting it had around it, which the modifiers inside the content apply over.
struct PresentedFlow<Content: View>: View {
    let content: Content
    let presentation: FlowPresentationLifetime<EmbeddedMarkupCanvas>
    var inheritedModifiers = FlowModifierEnvironment()

    var body: some View {
        content
            .environment(\.flowPresentation, presentation)
            .flowModifierEnvironment(inheritedModifiers)
    }
}

private struct FlowPresentationKey: EnvironmentKey {
    static let defaultValue: FlowPresentationLifetime<EmbeddedMarkupCanvas>? = nil
}

extension EnvironmentValues {
    /// The presentation that owns the flow of a `CameraFlowView`, which the controller that presents the view sets.
    /// A view without one owns its flow itself.
    var flowPresentation: FlowPresentationLifetime<EmbeddedMarkupCanvas>? {
        get { self[FlowPresentationKey.self] }
        set { self[FlowPresentationKey.self] = newValue }
    }
}

extension FlowInterfaceOrientations {
    /// The quarters of the flow in the app that runs it, from the Info.plist of its main bundle: on iPad and on iPhone
    /// the list for that device where the app has one, as the system reads it.
    /// - Precondition: the app's `UISupportedInterfaceOrientations` is a list of interface orientations.
    @MainActor static var ofApp: FlowInterfaceOrientations {
        let key = "UISupportedInterfaceOrientations"
        let keys = switch UIDevice.current.userInterfaceIdiom {
        case .pad: [key + "~ipad", key]
        case .phone: [key + "~iphone", key]
        default: [key]
        }
        guard let value = keys.lazy.compactMap(Bundle.main.object(forInfoDictionaryKey:)).first else {
            return FlowInterfaceOrientations(appQuarters: [])
        }
        guard let names = value as? [String] else {
            preconditionFailure("CameraFlow: the app's UISupportedInterfaceOrientations is not a list of names")
        }
        do {
            return FlowInterfaceOrientations(appQuarters: try quarters(named: names))
        } catch {
            preconditionFailure("CameraFlow: UISupportedInterfaceOrientations names \(error.name), no orientation")
        }
    }

    var mask: UIInterfaceOrientationMask {
        quarters.reduce(into: []) { mask, quarter in
            mask.insert(quarter.mask)
        }
    }

    var preferredOrientation: UIInterfaceOrientation {
        switch preferred {
        case .portrait: .portrait
        case .portraitUpsideDown: .portraitUpsideDown
        case .landscapeLeft: .landscapeLeft
        case .landscapeRight: .landscapeRight
        }
    }
}

extension InterfaceQuarter {
    var mask: UIInterfaceOrientationMask {
        switch self {
        case .portrait: .portrait
        case .portraitUpsideDown: .portraitUpsideDown
        case .landscapeLeft: .landscapeLeft
        case .landscapeRight: .landscapeRight
        }
    }
}
#endif
