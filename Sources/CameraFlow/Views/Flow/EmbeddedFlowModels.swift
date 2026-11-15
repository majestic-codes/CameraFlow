//
//  EmbeddedFlowModels.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
/// The models of the flow over the canvas of the screen, the one the views show.
typealias EmbeddedCameraFlowModel = CameraFlowModel<EmbeddedMarkupCanvas>
typealias EmbeddedPhotoMarkupModel = PhotoMarkupModel<EmbeddedMarkupCanvas>
#endif
