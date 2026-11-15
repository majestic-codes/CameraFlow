//
//  FocusLockBadgeStyleTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import SwiftUI
import Testing
@testable import CameraFlow

/// The type of the AE/AF LOCK badge as the stock badge sets it.
@Suite("The type of the AE/AF LOCK badge")
struct FocusLockBadgeStyleTests {

    @Test(
        "The badge follows the text size in the stock steps",
        arguments: [
            (DynamicTypeSize.xSmall, 14.0), (.medium, 14), (.large, 14), (.xLarge, 15), (.xxLarge, 17),
            (.xxxLarge, 19), (.accessibility1, 19), (.accessibility5, 19)
        ]
    )
    func steps(textSize: DynamicTypeSize, size: CGFloat) {
        #expect(CameraTextStyle.focusLockBadgeSize(at: textSize) == size)
    }

    @Test("At every size the letters are 25 thousandths of it apart, in the medium weight at the narrowed width")
    func letters() {
        for size: CGFloat in [14, 15, 17, 19] {
            let style = CameraTextStyle.focusLockBadge(size: size)
            #expect(style.size == size)
            #expect(style.tracking == size * 25 / 1000)
            #expect(style.weight == CameraTextStyle.Weight.medium)
            #expect(style.widthAxis == CameraTextStyle.valueWidthAxis)
        }
        #expect(CameraTextStyle.focusLockBadge == .focusLockBadge(size: 14))
    }
}
