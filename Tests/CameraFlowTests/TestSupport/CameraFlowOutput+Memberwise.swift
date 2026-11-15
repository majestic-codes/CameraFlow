//
//  CameraFlowOutput+Memberwise.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

@testable import CameraFlow

extension CameraFlowOutput {
    /// An output in one expression: the photo's size, format and metadata, unless the test says otherwise.
    init(
        size: CameraFlowOutputSize = .original,
        format: CameraFlowOutputFormat = .original,
        metadata: CameraFlowOutputMetadata = .kept
    ) {
        self.init()
        self.size = size
        self.format = format
        self.metadata = metadata
    }
}
