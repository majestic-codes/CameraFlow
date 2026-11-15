//
//  PhotoLibraryRefusedChangeTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Photos
import Testing
@testable import CameraFlow

/// An error of a service the test makes up, with a domain and a code of its own.
private struct ServiceRefusal: CustomNSError {
    static let errorDomain = "com.example.photos"
    let errorCode = 42
}

@Suite("A change the photo library refused, told by the error Photos threw")
struct PhotoLibraryRefusedChangeTests {

    @Test(
        "The missing room is told apart, whether Photos or the file system reports it",
        arguments: [PHPhotosError(.notEnoughSpace) as any Error, CocoaError(.fileWriteOutOfSpace), POSIXError(.ENOSPC)]
    )
    func outOfSpace(error: any Error) {
        #expect(CameraFlowPhotoLibraryError(refusedChange: error) == .notEnoughSpace)
    }

    @Test("An error of Photos is told by its domain and the raw value of its code")
    func photosError() {
        let refusal = CameraFlowPhotoLibraryError(refusedChange: PHPhotosError(.invalidResource))
        let code = PHPhotosError.Code.invalidResource.rawValue
        #expect(refusal == .changeRefused(errorDomain: PHPhotosError.errorDomain, errorCode: code))
        #expect(PHPhotosError.errorDomain == "PHPhotosErrorDomain")
    }

    @Test("Any other error is told by its own domain and code, so the cause reaches the app")
    func otherError() {
        let file = CameraFlowPhotoLibraryError(refusedChange: CocoaError(.fileReadNoSuchFile))
        let fileCode = CocoaError.Code.fileReadNoSuchFile.rawValue
        #expect(file == .changeRefused(errorDomain: CocoaError.errorDomain, errorCode: fileCode))
        let service = CameraFlowPhotoLibraryError(refusedChange: ServiceRefusal())
        #expect(service == .changeRefused(errorDomain: "com.example.photos", errorCode: 42))
    }
}
