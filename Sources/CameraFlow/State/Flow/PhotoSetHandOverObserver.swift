//
//  PhotoSetHandOverObserver.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// The receiver of a set as the set tells it of a hand-over, besides the photos it hands over: a hand-over begins and
/// ends, and right before the set gives its files away it asks whether anyone takes them.
@MainActor
protocol PhotoSetHandOverObserver: AnyObject {

    /// A hand-over of the set began. It ends with `handOverEnded()`, whichever way it ends.
    func handOverBegan()
    /// Whether a set handed over now reaches anyone.
    var receivesSets: Bool { get }
    /// The set of the hand-over reached nobody, so it was deleted with its files: the flow ended without a set.
    func setDeleted()
    /// The hand-over ended: the set was handed over, deleted, or left open.
    func handOverEnded()
}
