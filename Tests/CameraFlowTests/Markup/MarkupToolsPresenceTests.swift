//
//  MarkupToolsPresenceTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@testable import CameraFlow

/// When the tool picker of a canvas comes and goes: the canvas opens at its first layout, which may come before or
/// after it is on screen, and it may leave the screen and come back.
@Suite("Tools of a canvas on screen")
struct MarkupToolsPresenceTests {
    private static let canvas = "canvas"

    @Test("A canvas laid out before it comes on screen gets its tools when it comes on screen")
    func openThenAppear() {
        var presence = MarkupToolsPresence<String>()
        #expect(presence.open(Self.canvas) == nil)
        #expect(presence.appear() == Self.canvas)
    }

    @Test("A canvas laid out once it is on screen gets its tools at once")
    func appearThenOpen() {
        var presence = MarkupToolsPresence<String>()
        #expect(presence.appear() == nil)
        #expect(presence.open(Self.canvas) == Self.canvas)
    }

    @Test("Leaving the screen takes the tools away once, and coming back brings them again")
    func leaveAndComeBack() {
        var presence = MarkupToolsPresence<String>()
        _ = presence.open(Self.canvas)
        _ = presence.appear()
        #expect(presence.disappear() == Self.canvas)
        #expect(presence.disappear() == nil)
        #expect(presence.canvas == Self.canvas)
        #expect(presence.appear() == Self.canvas)
    }

    @Test("A canvas that leaves the screen before it is laid out has no tools to take away")
    func leaveBeforeOpening() {
        var presence = MarkupToolsPresence<String>()
        _ = presence.appear()
        #expect(presence.disappear() == nil)
        #expect(presence.open(Self.canvas) == nil)
        #expect(presence.canvas == Self.canvas)
    }
}
