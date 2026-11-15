//
//  View+LargeContent.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

extension View {

    /// Shows the name of a control large while it is pressed long at an accessibility text size, as the bars of the
    /// system do. The flow's chrome keeps the stock camera's sizes at every text size, and its glyph-only buttons
    /// have no text to grow.
    func showsLargeContent(_ title: String) -> some View {
        accessibilityShowsLargeContentViewer {
            Text(title)
        }
    }

    /// Shows the name of a control large with its glyph, while it is pressed long at an accessibility text size, as
    /// the bars of the system show their items.
    func showsLargeContent(_ title: String, @ViewBuilder glyph: () -> some View) -> some View {
        let icon = glyph()
        return accessibilityShowsLargeContentViewer {
            Label {
                Text(title)
            } icon: {
                icon
            }
        }
    }
}
#endif
