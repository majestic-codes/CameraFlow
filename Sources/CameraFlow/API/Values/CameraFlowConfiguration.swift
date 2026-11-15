//
//  CameraFlowConfiguration.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// What one "Add photo" flow offers and how its camera opens.
///
/// ```swift
/// var configuration = CameraFlowConfiguration()
/// configuration.photoLimit = .maximum(5)
/// // Offers the Live Photo switch, off at first. The default has no switch.
/// configuration.camera.isLivePhotoEnabled = CameraFlowSetting(false)
/// configuration.camera.photoFormat = .fixed(.heif)
/// configuration.camera.isDualCameraEnabled = .fixed(false)
/// configuration.output.size = .standard
/// configuration.output.format = .jpeg(quality: 0.8)
/// configuration.photoQuality = CameraFlowSetting(.high)
/// configuration.photoQualityLevels.medium = CameraFlowQualityLevel(size: .longSide(maximum: 1440))
/// configuration.photoLibrarySaving.destination = .album(named: "Field photos")
/// configuration.photoLibrarySaving.isEnabled = CameraFlowSetting(true)
/// configuration.settingsMemory = .userDefaults(suiteName: "group.example.shared")
/// configuration.onboarding = .off
/// configuration.photoLocation = .appRequestsAccess
/// configuration.language = .specific(Locale.Language(identifier: "uk"))
/// ```
///
/// ## The groups of parameters
///
/// | Group | Set by | The user changes it | Remembered | Reported |
/// |---|---|---|---|---|
/// | 1. App constraints | The app | Never | No | No |
/// | 2. User settings | The app: the first value, and whether it is fixed | In the camera | Yes | Yes |
/// | 3. Session only | The app: the first value | In the camera | No | No |
/// | 4. Internal | Launch fixtures and tests | Never | No | No |
///
/// - Group 1: ``isLibraryPickerEnabled``, ``photoLimit``, ``completion``, ``output``, ``libraryOutput``,
///   ``photoQualityLevels``, `photoLibrarySaving.destination`, `photoLibrarySaving.moment`, ``settingsMemory``,
///   ``onboarding``, ``photoLocation``, ``photoDirection``, ``language``, and
///   ``CameraFlowSetting/isUserAdjustable`` of every ``CameraFlowSetting``.
/// - Group 2: `camera.flashMode`, `camera.isLivePhotoEnabled`, `camera.aspectRatio`, `camera.timer`,
///   `camera.photoFormat`, `camera.isDualCameraEnabled`, ``photoQuality`` and `photoLibrarySaving.isEnabled`.
/// - Group 3: `camera.exposureBias` and `camera.zoomFactor`, and on the screen the focus, the open panel and which
///   camera is in the circle.
/// - Group 4: the `@_spi(Testing)` properties of ``CameraFlowInitialState`` and `simulatedAccess`.
///
/// ``preferences`` is no setting of its own: it carries the user's stored choices of group 2 back into the flow, one
/// optional value for each (``CameraFlowPreferences``).
///
/// ## A user setting, from the first value to the next flow
///
/// Every setting of group 2 is a ``CameraFlowSetting``, and one mechanism serves them all:
///
/// - The flow reports every change the user makes as a ``CameraFlowPreferences``: in SwiftUI through
///   ``SwiftUICore/View/onCameraFlowPreferencesChange(perform:)``, in UIKit through ``CameraFlowViewController``.
/// - By default the flow remembers the user's choices itself (``settingsMemory``), so an app does nothing.
/// - An app that keeps the choices itself sets `settingsMemory = .off`, stores what is reported and passes it back
///   in ``preferences``.
///
/// The value a setting opens with is the first of these that exists:
///
/// 1. the app's value, when the app fixed the setting (``CameraFlowSetting/fixed(_:)``),
/// 2. the value the app passed in ``preferences``,
/// 3. the value the flow remembers,
/// 4. the app's value (``CameraFlowSetting/value``).
///
/// A value the camera cannot honour (Live Photo on a camera without it or outside 4:3, the second camera on a device
/// that cannot run it, a quality the output leaves no room for, RAW where it is not offered) is taken as the nearest
/// one it can while the photo is taken. What is remembered and what is reported stay as the user chose them.
///
/// A flow is created with its configuration checked: a value no flow can honour stops the program, as the
/// precondition of ``CameraFlowView/init(configuration:locationProvider:)`` lists them.
public struct CameraFlowConfiguration: Sendable, Hashable {
    /// Group 1. The round library button and the "+" tile. Default true.
    public var isLibraryPickerEnabled = true
    /// Group 1. The most photos one set holds, camera and library together. Default
    /// ``CameraFlowPhotoLimit/unlimited``.
    public var photoLimit = CameraFlowPhotoLimit.unlimited
    /// Group 1. Whether the user accepts the set with the check mark or the flow ends by itself after one photo.
    /// Default ``CameraFlowCompletion/userConfirms``. See ``CameraFlowCompletion`` for how the one photo skips the
    /// review and the markup.
    public var completion = CameraFlowCompletion.userConfirms
    /// Groups 2 and 3. The state the camera opens in: the flash, Live Photo, the aspect ratio, the timer, the
    /// exposure, the format, the second camera's circle and the zoom, and which of its ``CameraFlowSetting`` values
    /// the user may change. Default: a fresh start with every setting adjustable, except Live Photo, which is off and
    /// fixed.
    public var camera = CameraFlowInitialState()
    /// Group 1. The size, the file format and the metadata of the photos the camera takes, and of the photos picked
    /// from the library unless ``libraryOutput`` gives them their own. Default: no step of its own, see
    /// ``CameraFlowOutput``.
    public var output = CameraFlowOutput()
    /// Group 1. The output of the photos picked from the photo library. Default
    /// ``CameraFlowLibraryOutput/sameAsCamera``: the output above, narrowed by the user's quality as a camera photo
    /// is.
    public var libraryOutput = CameraFlowLibraryOutput.sameAsCamera
    /// Group 2. The quality of the photos within the output, and whether the user picks it. Adjustable: the quality
    /// row of the Format tile, with the approximate size of one photo under it, and an indicator in the top bar
    /// while it is not ``CameraFlowQuality/high``. Default ``CameraFlowQuality/high`` and fixed, so the flow has no
    /// such row and every photo is as the output has it.
    public var photoQuality = CameraFlowSetting.fixed(CameraFlowQuality.high)
    /// Group 1. What the medium and the low quality give. Default: at most 1920 pixels on the long side for both,
    /// the medium one in the format of the output and the low one as a HEIC at a compression quality of 0.5.
    public var photoQualityLevels = CameraFlowQualityLevels()
    /// Whether the photos the camera takes are also saved to the system photo library and whether the user decides
    /// (group 2), and where they go and when (group 1). Default off and fixed, into the library when the set is
    /// accepted.
    public var photoLibrarySaving = CameraFlowPhotoLibrarySaving()
    /// The choices of group 2 the app stored from an earlier flow, applied over what the flow remembers. For an
    /// app that keeps the choices itself. Default nothing.
    public var preferences = CameraFlowPreferences()
    /// Group 1. Whether the flow remembers the user's choices of group 2 between openings, and where. Default: the
    /// standard `UserDefaults` under the prefix `CameraFlow.`. A suite that `UserDefaults` cannot open stops the
    /// program when the flow is created: see ``CameraFlowSettingsMemory/userDefaults(suiteName:keyPrefix:)``.
    public var settingsMemory = CameraFlowSettingsMemory.userDefaults()
    /// Group 1. Whether the flow introduces itself before the system asks for the camera, the location and the
    /// photo library. Default ``CameraFlowOnboarding/automatic``: a step for each access the flow needs that the
    /// user has not answered.
    public var onboarding = CameraFlowOnboarding.automatic
    /// Group 1. Whether the photos the camera takes record where they were taken, and whether the flow asks for
    /// location access. Default ``CameraFlowPhotoLocation/automatic``: the flow follows the location while the camera
    /// is on screen and asks for access, in its introduction where it has one, while the user has not answered.
    public var photoLocation = CameraFlowPhotoLocation.automatic
    /// Group 1. The language of the flow's own texts and of the numbers in them. Default
    /// ``CameraFlowLanguage/system``: the language the system resolves for the app. The system's own screens, such
    /// as the photo picker and the access alerts, keep the language of the app and the device: see
    /// ``CameraFlowLanguage``.
    public var language = CameraFlowLanguage.system
    /// Group 1. Whether the photos the camera takes record the direction the camera pointed in, from the compass.
    /// Default ``CameraFlowPhotoDirection/off``. It asks for no access and never holds the shutter: see
    /// ``CameraFlowPhotoDirection``.
    public var photoDirection = CameraFlowPhotoDirection.off
    /// Group 4. What the user was asked before a flow over the simulated camera opens.
    @_spi(Testing)
    public var simulatedAccess = SimulatedAccess.granted

    /// Creates the configuration of the default flow. Change the properties that should differ.
    public init() {}

    /// Stops the program on a configuration no flow can honour.
    func validate() {
        photoLimit.validate()
        camera.validate()
        output.validate()
        libraryOutput.validate()
        photoQualityLevels.validate()
        photoLibrarySaving.validate()
        settingsMemory.validate()
        precondition(
            camera.photoFormat.value != .raw || allowsRAW,
            "CameraFlow: camera.photoFormat is .raw while the output, or the quality the app fixed, encodes the photos "
                + "again or strips their metadata, which a DNG cannot have"
        )
    }

    /// Whether a RAW photo can ever be taken: the output keeps the format and the metadata of the camera's file, and
    /// so does the quality the app fixed. A quality the user picks can be the high one, which is the output itself.
    private var allowsRAW: Bool {
        let quality = photoQuality.isUserAdjustable ? CameraFlowQuality.high : photoQuality.value
        return quality.output(within: output, levels: photoQualityLevels).leavesFilesAsTheyAre
    }
}
