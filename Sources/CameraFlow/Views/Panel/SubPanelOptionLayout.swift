//
//  SubPanelOptionLayout.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// Placement of the parts of a sub-panel content inside `SubPanelOptionCanvas`, in points from the card's top-left
/// corner (`CameraMetrics.SubPanel`). Horizontally centred parts follow the card's width.
extension View {

    /// Places the view's leading edge at `leading` and its first baseline at `baseline`.
    func subPanelPlaced(leading: CGFloat, baseline: CGFloat) -> some View {
        fixedSize()
            .alignmentGuide(.leading) { _ in -leading }
            .alignmentGuide(.top) { dimensions in dimensions[.firstTextBaseline] - baseline }
    }

    /// Centres the view across the card with its first baseline at `baseline`.
    func subPanelCentered(baseline: CGFloat) -> some View {
        fixedSize()
            .frame(maxWidth: .infinity)
            .alignmentGuide(.top) { dimensions in dimensions[.firstTextBaseline] - baseline }
    }

    /// Centres the view across the card with its vertical centre at `centerY`.
    func subPanelCentered(centerY: CGFloat) -> some View {
        fixedSize()
            .frame(maxWidth: .infinity)
            .alignmentGuide(.top) { dimensions in dimensions.height / 2 - centerY }
    }
}

/// The container every sub-panel content builds on: it fills the card it is placed in and lays its parts out from
/// the card's top-left corner.
struct SubPanelOptionCanvas<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            content
        }
    }
}
#endif
