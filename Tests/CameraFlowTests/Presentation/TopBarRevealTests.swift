//
//  TopBarRevealTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 09.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@_spi(Testing) @testable import CameraFlow

@Suite("The top bar item to bring into view")
struct TopBarRevealTests {

    @Test("The item that joined the row is the one to reveal")
    func joinedItem() {
        let item = TopBarReveal.newestItem(in: [.flash, .live, .timer, .format], since: [.flash, .live, .timer])
        #expect(item == .format)
    }

    @Test("Of several items that joined, the last one is revealed")
    func lastOfSeveral() {
        let item = TopBarReveal.newestItem(in: [.flash, .live, .aspect, .exposure], since: [.flash, .live])
        #expect(item == .exposure)
    }

    @Test("Nothing is revealed when an item left or the row is the same")
    func nothingJoined() {
        #expect(TopBarReveal.newestItem(in: [.flash, .live], since: [.flash, .live, .timer]) == nil)
        #expect(TopBarReveal.newestItem(in: [.flash, .live], since: [.flash, .live]) == nil)
    }
}
