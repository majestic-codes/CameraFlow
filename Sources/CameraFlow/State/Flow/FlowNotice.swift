//
//  FlowNotice.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// The one thing the flow says on the line over the viewfinder, as `CameraFlowModel.notice` picks it.
enum FlowNotice: Equatable {
    /// What the camera says, in the shooting mode.
    case camera(CameraNotice)
    /// What the set says, when the camera or the drawing mode has nothing to say.
    case photoSet(PhotoSetNotice)
    /// What the drawing mode says, in the review.
    case markup(MarkupNotice)
}
