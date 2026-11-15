//
//  CameraFlowPreferences.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 09.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// What the user chose among the settings the user may change (group 2 of ``CameraFlowConfiguration``): flash, Live
/// Photo, aspect ratio, timer, format, the second camera's circle, the quality of the photos and saving to the photo
/// library.
///
/// The flow reports the preferences, in SwiftUI through ``SwiftUICore/View/onCameraFlowPreferencesChange(perform:)``
/// and in UIKit through the `onPreferencesChange` closure of ``CameraFlowViewController`` and to the controller's
/// delegate, after every change the user makes to one of these settings, and never for a change the flow makes on its
/// own, such as RAW the camera lacks taken as HEIF. A property holds what the user chose last, in this flow or in an
/// earlier one, and is nil while the user never chose: what the flow remembers (``CameraFlowSettingsMemory``) and what
/// the app passed in ``CameraFlowConfiguration/preferences`` are carried along, the app's value first.
///
/// By default the flow remembers the preferences itself and an app does nothing with them. An app that keeps them
/// itself sets ``CameraFlowConfiguration/settingsMemory`` to ``CameraFlowSettingsMemory/off``, stores every reported
/// value and passes it back through ``CameraFlowConfiguration/preferences``. A preference applies while the setting
/// is adjustable in that flow, and the app's ``CameraFlowSetting/value`` holds otherwise. One the camera cannot
/// honour (Live Photo, the circle, a quality the output leaves no room for) opens as the nearest the camera can, and
/// stays as it is here.
///
/// Each property is the value of its setting under the setting's own name: `camera.flashMode` is `flashMode`,
/// `camera.isLivePhotoEnabled` is `isLivePhotoEnabled`, and `photoLibrarySaving.isEnabled` is
/// `isPhotoLibrarySavingEnabled`.
///
/// The coding is stable: every property is optional and is encoded under its own name, enumerations as their raw
/// values and switches as JSON Booleans, so a value stored by an older version decodes with nil for what it lacks,
/// and an unknown property is ignored. A property whose stored value is not one of its values decodes as nil and the
/// others are kept.
public struct CameraFlowPreferences: Codable, Sendable, Hashable {
    /// The flash mode. Nil while the user never chose.
    public var flashMode: CameraFlowFlashMode?
    // A preference is nil while the user never chose, so the value of a switch is an optional Boolean.
    // swiftlint:disable discouraged_optional_boolean
    /// Whether Live Photo is on. Nil while the user never chose.
    public var isLivePhotoEnabled: Bool?
    /// The aspect ratio. Nil while the user never chose.
    public var aspectRatio: CameraFlowAspectRatio?
    /// The timer. Nil while the user never chose.
    public var timer: CameraFlowTimer?
    /// The file format. Nil while the user never chose.
    public var photoFormat: CameraFlowPhotoFormat?
    /// Whether the second camera's circle is on. Nil while the user never chose.
    public var isDualCameraEnabled: Bool?
    /// Whether the photos are saved to the system photo library. Nil while the user never chose.
    public var isPhotoLibrarySavingEnabled: Bool?
    // swiftlint:enable discouraged_optional_boolean
    /// The quality of the photos the app receives. Nil while the user never chose.
    public var photoQuality: CameraFlowQuality?

    /// Preferences with nothing chosen.
    public init() {}

    /// These preferences with every property that is nil taken from the others.
    func filled(from others: Self) -> Self {
        var filled = self
        filled.flashMode = flashMode ?? others.flashMode
        filled.isLivePhotoEnabled = isLivePhotoEnabled ?? others.isLivePhotoEnabled
        filled.aspectRatio = aspectRatio ?? others.aspectRatio
        filled.timer = timer ?? others.timer
        filled.photoFormat = photoFormat ?? others.photoFormat
        filled.isDualCameraEnabled = isDualCameraEnabled ?? others.isDualCameraEnabled
        filled.isPhotoLibrarySavingEnabled = isPhotoLibrarySavingEnabled ?? others.isPhotoLibrarySavingEnabled
        filled.photoQuality = photoQuality ?? others.photoQuality
        return filled
    }
}

extension CameraFlowPreferences {
    /// Reads stored preferences. Throws only for a value that is not a keyed record at all.
    public init(from decoder: any Decoder) throws {
        var droppedKeys: [String] = []
        try self.init(from: decoder, droppedKeys: &droppedKeys)
    }

    /// Reads stored preferences and names the properties whose stored value is not one of theirs, which read as nil.
    /// Throws only for a value that is not a keyed record at all.
    init(from decoder: any Decoder, droppedKeys: inout [String]) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        flashMode = Self.value(CameraFlowFlashMode.self, in: container, forKey: .flashMode, dropped: &droppedKeys)
        isLivePhotoEnabled = Self.value(Bool.self, in: container, forKey: .isLivePhotoEnabled, dropped: &droppedKeys)
        aspectRatio = Self.value(CameraFlowAspectRatio.self, in: container, forKey: .aspectRatio, dropped: &droppedKeys)
        timer = Self.value(CameraFlowTimer.self, in: container, forKey: .timer, dropped: &droppedKeys)
        photoFormat = Self.value(CameraFlowPhotoFormat.self, in: container, forKey: .photoFormat, dropped: &droppedKeys)
        isDualCameraEnabled = Self.value(Bool.self, in: container, forKey: .isDualCameraEnabled, dropped: &droppedKeys)
        let savingKey = CodingKeys.isPhotoLibrarySavingEnabled
        isPhotoLibrarySavingEnabled = Self.value(Bool.self, in: container, forKey: savingKey, dropped: &droppedKeys)
        photoQuality = Self.value(CameraFlowQuality.self, in: container, forKey: .photoQuality, dropped: &droppedKeys)
    }

    /// The stored value of one property. The stored bytes are outside the flow's control, so a value that is not
    /// one of the property's reads as nil, like a missing one, its key goes into `dropped`, and the other
    /// properties are kept.
    private static func value<Value: Decodable>(
        _ type: Value.Type,
        in container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys,
        dropped: inout [String]
    ) -> Value? {
        do {
            return try container.decodeIfPresent(type, forKey: key)
        } catch {
            // The stored-preference exception of AGENTS.md: a value that is not one of the property's reads as
            // nil, and the caller hears of its key.
            dropped.append(key.stringValue)
            return nil
        }
    }
}
