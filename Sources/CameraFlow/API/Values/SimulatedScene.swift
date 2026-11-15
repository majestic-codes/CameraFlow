//
//  SimulatedScene.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// What the simulated camera shows in place of a live preview.
@_spi(Testing)
public enum SimulatedScene: Sendable, Hashable {
    /// A black preview.
    case black
    /// A flat colour, components from 0 to 1.
    case color(red: Double, green: Double, blue: Double)
}
