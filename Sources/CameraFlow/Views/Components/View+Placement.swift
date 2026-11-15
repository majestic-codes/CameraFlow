//
//  View+Placement.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

extension View {

    /// Gives the view the size of a frame and moves it there inside a top-leading container that spans the screen.
    func placed(in frame: CGRect) -> some View {
        self
            .frame(width: frame.width, height: frame.height)
            .offset(x: frame.minX, y: frame.minY)
    }
}
#endif
