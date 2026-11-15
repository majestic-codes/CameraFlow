//
//  CameraFlowView.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import CoreLocation
import SwiftUI

/// The whole "Add photo" flow.
///
/// Present it full screen in a portrait interface: from SwiftUI with
/// ``SwiftUICore/View/cameraFlowCover(isPresented:onDismiss:content:)``, from UIKit with
/// ``CameraFlowViewController``. It uses the device camera, and a simulated one in the iOS Simulator only. The app
/// needs `NSCameraUsageDescription`.
///
/// ```swift
/// .cameraFlowCover(isPresented: $isFlowPresented) {
///     CameraFlowView(configuration: configuration)
///         .cameraFlowPhotoLimit(.maximum(5))
///         .onCameraFlowPreferencesChange { preferences in store(preferences) }
///         .onCameraFlowFinish { photos in
///             isFlowPresented = false
///             keep(photos)
///         }
///         .onCameraFlowCancel { isFlowPresented = false }
/// }
/// ```
///
/// A ``CameraFlowConfiguration`` sets up the flow, and SwiftUI modifiers set some of its properties and give the
/// flow its actions: ``SwiftUICore/View/onCameraFlowFinish(perform:)`` receives the accepted set,
/// ``SwiftUICore/View/onCameraFlowCancel(perform:)`` hears the user leave without one, and
/// ``SwiftUICore/View/onCameraFlowPreferencesChange(perform:)`` receives the user's choices. See
/// <doc:SwiftUIModifiers> for the rules: the configuration is the base, a modifier replaces one property of it, the
/// flow reads the configuration once, when it starts, and calls the actions of the latest update of the view.
///
/// A flow opened before the user was ever asked for the camera introduces itself first and asks from its Continue
/// button: see ``CameraFlowOnboarding``, which also turns the introduction off.
///
/// A camera that cannot run says so in the viewfinder and takes no photo: a device without a camera, a camera the
/// user denied (with a button to the app's page of Settings) and one a device policy restricts. The flow stays
/// open: the user closes it, or adds photos from the library where the flow has it.
///
/// The photos the camera takes record where they were taken, as the stock Camera's do: see
/// ``CameraFlowPhotoLocation``. By default the flow follows the location itself while the camera is on screen and
/// asks for when-in-use access in its introduction (`NSLocationWhenInUseUsageDescription`). An app with its own
/// location passes a `locationProvider`, which returns the location for a photo taken now, or nil. Not every photo
/// file can carry it: see ``CameraFlowPhoto``.
///
/// The size, the format and the metadata of the files the app receives are ``CameraFlowConfiguration/output``. A
/// flow that saves to the system photo library (``CameraFlowConfiguration/photoLibrarySaving``) asks for library
/// access when it first needs it, with the usage descriptions ``CameraFlowPhotoLibrarySaving`` names.
///
/// Ownership: the receiver owns every file it gets from ``SwiftUICore/View/onCameraFlowFinish(perform:)`` (see
/// ``CameraFlowPhoto``). The flow deletes every file it does not hand over. Dismiss the view from the finish and the
/// cancel actions.
///
/// Lifetime: presented by ``SwiftUICore/View/cameraFlowCover(isPresented:onDismiss:content:)`` or
/// ``CameraFlowViewController``, the flow lives as long as that presentation. A screen the app presents over it, such
/// as a lock screen, stops the camera and keeps the set, and the camera comes back when that screen leaves. When the
/// presentation ends without the finish or the cancel, because the app took the cover away, the camera is closed and
/// the photos of the set are deleted, and neither action is called: the cancel action reports the user's own exit
/// only. The flow cannot be swiped away: the cross is the user's way out, and it asks before it leaves photos behind,
/// the photos of the set and the ones the camera is still taking or processing.
///
/// A view presented any other way owns its flow itself, for as long as it is on screen: when it goes away, because
/// the app switched the tab or pushed a navigation destination over it, the set is deleted the same way, and a view
/// that comes back starts a new flow with an empty set. So present the flow with
/// ``SwiftUICore/View/cameraFlowCover(isPresented:onDismiss:content:)`` or ``CameraFlowViewController``, not inside a
/// tab or a navigation stack that can take it away.
///
/// A set the user has accepted outlasts the view. Once the check mark is tapped, the hand-over runs to its end
/// whatever happens to the view meanwhile: the copies are written, the photos are saved to the photo library, and the
/// finish action is called once, with files that exist. A flow left on screen after the hand-over takes no more
/// photos.
public struct CameraFlowView: View {
    private let configuration: CameraFlowConfiguration
    /// The texts of ``CameraFlowConfiguration/language`` as the view was created with it.
    private let configuredLocalization: FlowLocalization
    private let locationProvider: (() -> CLLocation?)?
    /// The closures the view was created with.
    private let callbacks: FlowCallbacks
    /// The flow of a view that owns it, nil before the view first appears and in a presented view.
    @State private var screen: FlowScreenModels<EmbeddedMarkupCanvas>?
    /// The receivers of the events of a flow the view owns. A presented flow has those of its presentation.
    @State private var ownReceivers = FlowReceivers()
    @Environment(\.flowPresentation) private var presentation
    @Environment(\.flowConfigurationChanges) private var configurationChanges
    @Environment(\.flowModifierCallbacks) private var modifierCallbacks

    /// Creates the flow with the closures of its events.
    ///
    /// The flow is the one of ``init(configuration:locationProvider:)``, with the same rules and preconditions. The
    /// flow calls the closures of the latest view, and a closure that a modifier of the flow sets on the view or around
    /// it replaces the one of its event. Every closure is called on the main actor.
    /// - Parameters:
    ///   - configuration: What the flow offers and how its camera opens.
    ///   - locationProvider: The app's own location for the photos, nil for the flow's own.
    ///   - onPreferencesChange: Receives the user's choices (``CameraFlowPreferences``).
    ///   - onFinish: Receives the photos of the accepted set.
    ///   - onCancel: Called when the user leaves the flow without a set.
    public init(
        configuration: CameraFlowConfiguration = CameraFlowConfiguration(),
        locationProvider: (() -> CLLocation?)? = nil,
        onPreferencesChange: ((CameraFlowPreferences) -> Void)? = nil,
        onFinish: @escaping ([CameraFlowPhoto]) -> Void,
        onCancel: @escaping () -> Void
    ) {
        let callbacks = FlowCallbacks(onPreferencesChange: onPreferencesChange, onFinish: onFinish, onCancel: onCancel)
        self.init(configuration: configuration, locationProvider: locationProvider, callbacks: callbacks)
    }

    /// Creates the flow, which the SwiftUI modifiers of the flow give its actions:
    /// ``SwiftUICore/View/onCameraFlowFinish(perform:)`` and ``SwiftUICore/View/onCameraFlowCancel(perform:)``, which
    /// the flow needs, and ``SwiftUICore/View/onCameraFlowPreferencesChange(perform:)``.
    ///
    /// ```swift
    /// CameraFlowView(configuration: configuration)
    ///     .onCameraFlowFinish { photos in
    ///         isFlowPresented = false
    ///         keep(photos)
    ///     }
    ///     .onCameraFlowCancel { isFlowPresented = false }
    /// ```
    ///
    /// The configuration, the location provider and the properties the modifiers set are read once, when the flow
    /// starts: a view created again with other values keeps running the flow it has, with the configuration it started
    /// with. The one exception is ``CameraFlowConfiguration/language``: the texts on the screen follow the language of
    /// the latest view, while the lens picker of the Camera Control keeps the one the flow started with. The flow calls
    /// the actions of the latest update of the view, as SwiftUI calls its own. Every action is called on the main
    /// actor, where the view is created. See <doc:SwiftUIModifiers> for how the modifiers apply over the
    /// configuration.
    /// - Parameters:
    ///   - configuration: What the flow offers and how its camera opens, before the modifiers.
    ///   - locationProvider: The app's own location for the photos, called at every shutter release, in place of the
    ///     flow's. A location it returns counts as the flow's own does, while it is valid and at most 60 seconds old,
    ///     or 20 minutes for an approximate one. Nil for the flow's own (``CameraFlowConfiguration/photoLocation``).
    /// - Precondition: checked whenever the view is created. No `locationProvider` while
    ///   ``CameraFlowConfiguration/photoLocation`` is ``CameraFlowPhotoLocation/off``, a
    ///   ``CameraFlowPhotoLimit/maximum(_:)`` of at least 1, a ``CameraFlowOutputSize/longSide(maximum:)`` of at least
    ///   1 in the output, in the library's output and in the quality levels, compression qualities in 0...1, a finite
    ///   zoom factor and exposure bias of the camera, a RAW photo format only with an output that keeps the format and
    ///   the metadata (and so does a quality the app fixed), an album name that is not blank and a suite name of the
    ///   settings memory that `UserDefaults(suiteName:)` opens.
    /// - Precondition: checked when the flow starts. The configuration with the properties the modifiers set passes
    ///   the same checks, and the modifiers give ``SwiftUICore/View/onCameraFlowFinish(perform:)`` and
    ///   ``SwiftUICore/View/onCameraFlowCancel(perform:)``, which the latest view keeps while the flow runs. The app's
    ///   Info.plist has the usage description of every system resource the flow asks for: `NSCameraUsageDescription`
    ///   for the device's camera, `NSPhotoLibraryAddUsageDescription` where the flow may save to the photo library and
    ///   `NSPhotoLibraryUsageDescription` where it may save to an album, and `NSLocationWhenInUseUsageDescription`
    ///   where it asks for the location (``CameraFlowPhotoLocation/automatic``, for photos that can carry one).
    public init(
        configuration: CameraFlowConfiguration = CameraFlowConfiguration(),
        locationProvider: (() -> CLLocation?)? = nil
    ) {
        self.init(configuration: configuration, locationProvider: locationProvider, callbacks: FlowCallbacks())
    }

    private init(
        configuration: CameraFlowConfiguration,
        locationProvider: (() -> CLLocation?)?,
        callbacks: FlowCallbacks
    ) {
        configuration.validate(hasLocationProvider: locationProvider != nil)
        self.configuration = configuration
        configuredLocalization = FlowLocalization(configuration.language)
        self.locationProvider = locationProvider
        self.callbacks = callbacks
    }

    /// The flow. It fills the whole screen, under the safe area too.
    public var body: some View {
        let localization = shownLocalization
        receivers.update(callbacks: callbacks, modifierCallbacks: modifierCallbacks)
        return ZStack {
            CameraPalette.background
                .ignoresSafeArea()
            if let shownScreen {
                CameraFlowScreen(flow: shownScreen.flow, zoomTouch: shownScreen.zoomTouch)
            }
        }
        .interactiveDismissDisabled()
        .flowLocalization(localization)
        .background {
            AccessibilityLanguageScope(language: localization.spokenLanguage)
        }
        .task {
            await run()
        }
    }

    /// The texts of the latest view: its language with the one of the modifiers over it.
    private var shownLocalization: FlowLocalization {
        let language = configurationChanges.applied(to: configuration).language
        return language == configuration.language ? configuredLocalization : FlowLocalization(language)
    }

    /// The receivers of the flow on screen, which every update of the view hands its latest closures.
    private var receivers: FlowReceivers {
        presentation?.receivers ?? ownReceivers
    }

    /// The flow on screen: the presentation's in a presented view, the view's own otherwise.
    private var shownScreen: FlowScreenModels<EmbeddedMarkupCanvas>? {
        guard let presentation else { return screen }
        return presentation.screen
    }

    /// Runs the flow while the view is on screen: the presentation's flow, or a new flow of the view's own. The
    /// configuration and its modifiers are read here, as the flow starts, and a flow that runs already keeps the
    /// configuration it started with. The closures reach the flow through `receivers`, which keep the latest.
    private func run() async {
        let changes = configurationChanges
        let flowReceivers = receivers
        flowReceivers.update(callbacks: callbacks, modifierCallbacks: modifierCallbacks)
        let script = CameraFixtureScript(initialState: changes.applied(to: configuration).camera)
        if let presentation {
            await presentation.run(script: script) {
                makeFlow(changes: changes, receivers: flowReceivers)
            }
            return
        }
        let flow = makeFlow(changes: changes, receivers: flowReceivers)
        let screen = FlowScreenModels(flow: flow)
        self.screen = screen
        await CameraScreenLifetime.run(screen.flow, script: script)
    }

    private func makeFlow(changes: FlowConfigurationChanges, receivers: FlowReceivers) -> EmbeddedCameraFlowModel {
        let setup = FlowSetup(
            configuration: configuration,
            changes: changes,
            receivers: receivers,
            hasLocationProvider: locationProvider != nil
        )
        return CameraScreenFactory.makeFlow(
            configuration: setup.configuration,
            locationProvider: locationProvider,
            onPreferencesChange: setup.onPreferencesChange,
            onFinish: setup.onFinish,
            onCancel: setup.onCancel
        )
    }
}
#endif
