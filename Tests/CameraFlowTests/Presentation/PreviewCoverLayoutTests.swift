//
//  PreviewCoverLayoutTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Testing
@testable import CameraFlow

@Suite("Preview cover layout")
struct PreviewCoverLayoutTests {
    /// The circle of the 402 points wide screen, and its 4:3 viewfinder.
    private static let circle = CGSize(width: 120, height: 120)
    private static let viewfinder = CGSize(width: 402, height: 536)

    @Test(
        "A still fills its container evenly scaled and centred, whatever its shape",
        arguments: [
            (circle, circle, CGRect(x: 0, y: 0, width: 120, height: 120)),
            (viewfinder, circle, CGRect(x: 0, y: -20, width: 120, height: 160)),
            (CGSize(width: 536, height: 402), circle, CGRect(x: -20, y: 0, width: 160, height: 120)),
            (circle, viewfinder, CGRect(x: -67, y: 0, width: 536, height: 536)),
            (CGSize(width: 201, height: 268), viewfinder, CGRect(x: 0, y: 0, width: 402, height: 536))
        ]
    )
    func fill(stillSize: CGSize, container: CGSize, expected: CGRect) {
        let frame = PreviewCoverLayout.stillFrame(stillSize: stillSize, in: container)
        expectClose(frame, expected)
        #expect(frame.insetBy(dx: -0.01, dy: -0.01).contains(CGRect(origin: .zero, size: container)))
        let stretch = frame.width / stillSize.width - frame.height / stillSize.height
        expectClose(stretch, 0, tolerance: 0.001)
    }

    @Test(
        "A still or a container with no area gets the container's bounds",
        arguments: [
            (CGSize.zero, CGSize(width: 120, height: 120)),
            (CGSize(width: 402, height: 0), CGSize(width: 120, height: 120)),
            (CGSize(width: 402, height: 536), CGSize.zero)
        ]
    )
    func empty(stillSize: CGSize, container: CGSize) {
        let frame = PreviewCoverLayout.stillFrame(stillSize: stillSize, in: container)
        #expect(frame == CGRect(origin: .zero, size: container))
    }
}
