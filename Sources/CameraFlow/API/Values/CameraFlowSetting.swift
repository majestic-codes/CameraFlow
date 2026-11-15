//
//  CameraFlowSetting.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 09.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// A setting of the flow with the value the app chooses, and whether the user may change it in the flow.
///
/// An adjustable setting has its control on the camera screen: an indicator in the top bar or a tile in the "more"
/// panel, or both. A fixed setting has no control and its value holds for the whole flow: nothing stored changes
/// it, and it is neither remembered nor reported.
///
/// An adjustable setting of group 2 (see ``CameraFlowConfiguration``) opens with the value the app passed in
/// ``CameraFlowConfiguration/preferences``, or else with the one the flow remembers (``CameraFlowSettingsMemory``),
/// or else with the value here. Every change the user makes to it is remembered and reported as a
/// ``CameraFlowPreferences``. The exposure bias, of group 3, always opens with the value here.
///
/// A camera that cannot honour the value (RAW it does not have, Live Photo under RAW, a flash it lacks)
/// takes the nearest it can, as the panel would, adjustable or not.
public struct CameraFlowSetting<Value: Sendable & Equatable>: Sendable, Equatable {
    /// The value the flow opens with, and the only value when the user may not change it.
    public var value: Value
    /// Whether the user may change the value in the flow. Default true.
    public var isUserAdjustable: Bool

    /// A setting with a value, adjustable by the user unless said otherwise.
    /// - Parameters:
    ///   - value: The value the flow opens with.
    ///   - isUserAdjustable: Whether the user may change the value in the flow. Default true.
    public init(_ value: Value, isUserAdjustable: Bool = true) {
        self.value = value
        self.isUserAdjustable = isUserAdjustable
    }

    /// A setting the user may not change: its control is not shown and the value holds for the whole flow.
    /// - Parameter value: The value of the whole flow.
    public static func fixed(_ value: Value) -> Self {
        Self(value, isUserAdjustable: false)
    }

    /// The value the flow opens with: the stored preference, the app's or else the remembered one, when the user
    /// may change the setting and has one, the setting's own value otherwise.
    func resolved(with preference: Value?) -> Value {
        guard isUserAdjustable, let preference else { return value }
        return preference
    }
}

extension CameraFlowSetting: Hashable where Value: Hashable {}

extension CameraFlowSetting<Bool> {
    /// Whether the flow can ever have the switch on: the app set it on, or the user may switch it.
    var canBeOn: Bool {
        value || isUserAdjustable
    }
}
