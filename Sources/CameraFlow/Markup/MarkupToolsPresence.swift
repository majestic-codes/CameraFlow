//
//  MarkupToolsPresence.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// When the tools of a canvas are up: from the moment the canvas is open and on screen, whichever comes last, until
/// it leaves the screen. `Canvas` is what the engine draws the canvas with, which takes the tools.
struct MarkupToolsPresence<Canvas> {
    /// What the engine draws with, once the canvas is open.
    private(set) var canvas: Canvas?
    private var isOnScreen = false

    /// The canvas opened with `canvas`: gives it back when the tools come up now.
    mutating func open(_ canvas: Canvas) -> Canvas? {
        self.canvas = canvas
        return isOnScreen ? canvas : nil
    }

    /// The canvas came on screen: gives back what the engine draws with when the tools come up now.
    mutating func appear() -> Canvas? {
        isOnScreen = true
        return canvas
    }

    /// The canvas leaves the screen: gives back what the engine draws with when the tools were up and go now.
    mutating func disappear() -> Canvas? {
        defer {
            isOnScreen = false
        }
        return isOnScreen ? canvas : nil
    }
}
