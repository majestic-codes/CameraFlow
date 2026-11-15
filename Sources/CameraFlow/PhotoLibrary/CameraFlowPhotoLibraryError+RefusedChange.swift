//
//  CameraFlowPhotoLibraryError+RefusedChange.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Photos

extension CameraFlowPhotoLibraryError {
    /// The failure of a change Photos refused, told from the error it threw: the missing room as `notEnoughSpace`,
    /// from Photos or from the file system, and any other error by its domain and its code.
    init(refusedChange error: any Error) {
        let isOutOfSpace = (error as? PHPhotosError)?.code == .notEnoughSpace || StorageFailure.isOutOfSpace(error)
        // Foundation's error is the one public form of an error's domain and code, and every error bridges to it.
        let cause = error as NSError
        self = isOutOfSpace ? .notEnoughSpace : .changeRefused(errorDomain: cause.domain, errorCode: cause.code)
    }
}
