//
//  CameraFlowInitialState.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// The settings of the camera screen: zoom, flash, Live Photo, aspect ratio, timer, exposure, format and the second
/// camera's circle.
///
/// Each setting but the zoom is a ``CameraFlowSetting``: the value the camera opens with, and whether the user may
/// change it on the screen. Every property has the value of a fresh start by default, adjustable by the user, except
/// Live Photo, which is off and fixed: a flow offers Live Photo only when the app makes it adjustable or fixes it on.
///
/// Flash, Live Photo, aspect ratio, timer, format and the circle are user settings, group 2 of
/// ``CameraFlowConfiguration``: an adjustable one opens with the app's stored preference or with what the flow
/// remembers, and the user's change is remembered and reported. The exposure bias and the zoom are of group 3: they
/// hold for one flow, like the stock camera's, and are neither remembered nor reported.
public struct CameraFlowInitialState: Sendable, Hashable {
    /// Group 3. Zoom factor as shown on the lens buttons, a finite number clamped to the range of the camera.
    /// Default nil, which keeps the main camera at 1.
    public var zoomFactor: Double?
    /// Opens the zoom dial right away and keeps it open until the first touch.
    @_spi(Testing)
    public var isZoomDialOpen = false
    /// Group 2. Flash mode. A camera without a flash takes every photo without it, and the chosen mode comes back
    /// with a camera that has one. Adjustable: the Flash indicator in the top bar and the Flash tile. Default auto and
    /// adjustable.
    ///
    /// In auto the Flash indicator turns yellow while the scene would fire the flash for the next photo, at the quality
    /// that photo is taken with: the best for HEIF and JPEG, balanced for RAW. With Differentiate Without Color, Auto
    /// is outlined while the flash would not fire and filled when it would. While the flash cannot fire, because the
    /// device is too hot or the battery too low, the indicator shows a bolt with a warning, the photos go without the
    /// flash, a tap on the indicator explains why, and the chosen mode is kept.
    public var flashMode = CameraFlowSetting(CameraFlowFlashMode.auto)
    /// Group 2. Whether Live Photo is on. It has no effect while the format is RAW, while the aspect ratio is not
    /// 4:3 (the movie is never cropped, so it would not match its photo) or on a camera without Live Photo.
    /// Adjustable: the Live indicator in the top bar and the Live tile. Default off and fixed, so the flow has no
    /// Live Photo at all, and its camera starts faster and takes less memory.
    ///
    /// The movie of a Live Photo has no sound: the flow never uses the microphone, so the app needs no
    /// microphone permission.
    public var isLivePhotoEnabled = CameraFlowSetting.fixed(false)
    /// Group 2. Aspect ratio of the viewfinder and of the photos. Adjustable: the Aspect tile. Default 4:3 and
    /// adjustable.
    public var aspectRatio = CameraFlowSetting(CameraFlowAspectRatio.fourByThree)
    /// Group 2. Delay between the shutter tap and the photo. Adjustable: the Timer tile. Default off and adjustable.
    public var timer = CameraFlowSetting(CameraFlowTimer.off)
    /// Group 3. Exposure bias in stops, a finite number clamped to -2...2 and to what the camera accepts. Adjustable:
    /// the Exposure tile and the drag beside the focus reticle. Default 0 and adjustable. The user's bias is neither
    /// remembered nor part of ``CameraFlowPreferences``.
    public var exposureBias = CameraFlowSetting(0.0)
    /// Group 2. File format of the photos. Adjustable: the format row of the Format tile. Default HEIF and
    /// adjustable.
    ///
    /// RAW is offered only where the camera has it and the output takes a DNG as it is: in the
    /// ``CameraFlowOutputFormat/original`` format, with the metadata kept and at a size no smaller than the camera's
    /// photo (``CameraFlowOutputSize/original``, or a long side of at least 4032 at 12 MP). Under a quality below
    /// ``CameraFlowQuality/high`` it stays on the panel dimmed. The app's value is RAW only with an output, and a
    /// quality the app fixed, that keep the format and the metadata: a flow created otherwise stops the program. A
    /// camera that cannot give RAW within the output takes HEIF.
    public var photoFormat = CameraFlowSetting(CameraFlowPhotoFormat.heif)
    /// Group 2. Whether the second camera shows in a circle in the top right corner of the viewfinder. Adjustable:
    /// the circle indicator in the top bar and the Dual Capture tile. Default off and adjustable. Which camera is
    /// in the circle is of group 3.
    ///
    /// The circle needs a device that runs the back and the front camera at the same time: elsewhere the flow has no
    /// circle and no control, whatever this says, and a remembered "on" opens with the circle off. The circle shows
    /// the camera that is not in the viewfinder, and the flip button swaps the two. While it is on, a photo comes with
    /// a copy that has the circle's picture composited in at the place the viewfinder showed it
    /// (``CameraFlowPhoto/markedUp``), and the original from the viewfinder's camera stays as the output has it.
    /// The pair may offer less than one camera alone, such as no Live Photo or no RAW: a chosen setting it
    /// lacks is left out while the circle is on and comes back with it off. Fix it off to keep the circle off the
    /// screen everywhere. Fixed on, the circle opens on without a control. When the device turns it off to cool
    /// down, it stays off for the rest of that flow.
    public var isDualCameraEnabled = CameraFlowSetting(false)
    /// What the control panel shows.
    @_spi(Testing)
    public var panel = CameraPanelPresentation.hidden
    /// Uses the simulated camera even when the device has a real one.
    @_spi(Testing)
    public var usesSimulatedCamera = false
    /// What the simulated camera shows.
    @_spi(Testing)
    public var simulatedScene = SimulatedScene.black
    /// Takes this many photos one after another once the camera has started, as if the shutter were tapped.
    @_spi(Testing)
    public var automaticCaptureCount = 0
    /// The way the phone is held while the camera is simulated.
    @_spi(Testing)
    public var simulatedOrientation = CameraOrientation.portrait
    /// How many times the simulated camera fails to start before it starts, so the flow shows the failure it can be
    /// started again from.
    @_spi(Testing)
    public var simulatedStartFailureCount = 0
    /// Opens the circle swapped: the front camera in the viewfinder and the back one in the circle. It has an
    /// effect only when the circle opens on.
    @_spi(Testing)
    public var isDualCameraSwapped = false

    /// Creates the state of a fresh start. Change the properties that should differ.
    public init() {}

    /// Stops the program on a state no camera can open in.
    /// - Precondition: the zoom factor and the exposure bias are finite numbers.
    func validate() {
        if let zoomFactor {
            precondition(
                zoomFactor.isFinite,
                "CameraFlowInitialState.zoomFactor must be a finite number, not \(zoomFactor)"
            )
        }
        let bias = exposureBias.value
        precondition(bias.isFinite, "CameraFlowInitialState.exposureBias must be a finite number, not \(bias)")
    }
}
