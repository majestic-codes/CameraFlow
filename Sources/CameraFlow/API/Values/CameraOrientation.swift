//
//  CameraOrientation.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// The way the phone is held, in quarters. Landscape left has the top of the phone to the left, as in
/// `UIDeviceOrientation`. The flow's own presentation keeps the interface portrait on iPhone, and only its elements
/// turn. On iPad the interface turns with the device, and the elements turn by what lies between the two.
@_spi(Testing)
public enum CameraOrientation: Sendable, Hashable, CaseIterable {
    /// Upright, the top of the phone up.
    case portrait
    /// On its side, the top of the phone to the left.
    case landscapeLeft
    /// On its side, the top of the phone to the right.
    case landscapeRight
    /// Upside down, the top of the phone down.
    case upsideDown

    /// How far an element turns on the portrait screen to stay upright, in degrees clockwise.
    var elementAngle: Double {
        switch self {
        case .portrait: 0
        case .landscapeLeft: 90
        case .landscapeRight: -90
        case .upsideDown: 180
        }
    }

    /// The quarter whose element angle this is, rounded to whole quarter turns either way.
    init(elementAngle: Double) {
        let clockwiseQuarters: [Self] = [.portrait, .landscapeLeft, .upsideDown, .landscapeRight]
        let turns = Int((elementAngle / 90).rounded())
        self = clockwiseQuarters[(turns % 4 + 4) % 4]
    }

    /// How the phone is held as seen from an interface that stands in a quarter: portrait when the interface stands
    /// the way the phone is held, the phone's own quarter when the interface is portrait.
    func relative(to interface: Self) -> Self {
        Self(elementAngle: elementAngle - interface.elementAngle)
    }

    /// This quarter turned on by another one, as a phone held in `other` and then turned by this quarter.
    func turned(by other: Self) -> Self {
        Self(elementAngle: elementAngle + other.elementAngle)
    }
}
