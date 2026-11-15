//
//  PhotoCaptureRequestTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@testable import CameraFlow

@Suite("Photo capture request")
struct PhotoCaptureRequestTests {
    struct Row: Sendable, CustomTestStringConvertible {
        let name: String
        let flashMode: CameraFlowFlashMode
        let isLivePhotoEnabled: Bool
        let format: CameraFlowPhotoFormat
        /// A size asked for in place of the one the back camera shoots at.
        var size: PhotoCaptureResolution?
        let capabilities: PhotoCaptureCapabilities
        let expectedError: CameraServiceError?

        var testDescription: String {
            name
        }

        /// The size asked for: the one given, or the one the back camera shoots at.
        var resolution: PhotoCaptureResolution? {
            size ?? PhotoCaptureRequestTests.back.resolution
        }
    }

    static let back = SimulatedCameraService.iPhoneBackPhotoCapabilities
    static let front = SimulatedCameraService.iPhoneFrontPhotoCapabilities

    static let rows = [
        Row(
            name: "HEIF 12 MP with Live and flash",
            flashMode: .alwaysOn,
            isLivePhotoEnabled: true,
            format: .heif,
            capabilities: back,
            expectedError: nil
        ),
        Row(
            name: "RAW 12 MP",
            flashMode: .auto,
            isLivePhotoEnabled: false,
            format: .raw,
            capabilities: back,
            expectedError: nil
        ),
        Row(
            name: "Flash on a camera without one",
            flashMode: .alwaysOn,
            isLivePhotoEnabled: false,
            format: .heif,
            capabilities: CaptureTestSupport.withoutFlash,
            expectedError: .unsupported(.flash(.alwaysOn))
        ),
        Row(
            name: "RAW on a camera without ProRAW",
            flashMode: .off,
            isLivePhotoEnabled: false,
            format: .raw,
            capabilities: front,
            expectedError: .unsupported(.format(.raw))
        ),
        Row(
            name: "A size the camera does not deliver",
            flashMode: .off,
            isLivePhotoEnabled: false,
            format: .heif,
            size: PhotoCaptureResolution(width: 8064, height: 6048),
            capabilities: front,
            expectedError: .unsupported(.resolution)
        ),
        Row(
            name: "Live Photo on a camera without it",
            flashMode: .off,
            isLivePhotoEnabled: true,
            format: .heif,
            capabilities: CaptureTestSupport.narrowCapabilities,
            expectedError: .unsupported(.livePhoto)
        ),
        Row(
            name: "Live Photo with ProRAW, which the header forbids",
            flashMode: .off,
            isLivePhotoEnabled: true,
            format: .raw,
            capabilities: back,
            expectedError: .unsupported(.livePhotoWithRAW)
        )
    ]

    @Test("Settings are checked against the camera", arguments: rows)
    func validation(row: Row) throws {
        let resolution = try #require(row.resolution)
        let make = {
            try PhotoCaptureRequest(
                flashMode: row.flashMode,
                isLivePhotoEnabled: row.isLivePhotoEnabled,
                format: row.format,
                resolution: resolution,
                capabilities: row.capabilities
            )
        }
        if let expectedError = row.expectedError {
            #expect(throws: expectedError, performing: make)
        } else {
            let request = try make()
            #expect(request.resolution == resolution)
            #expect(request.format == row.format)
        }
    }

    @Test(
        "A photo size within 10% of 12 MP is the preferred one",
        arguments: [(Int32(4032), Int32(3024)), (Int32(4000), Int32(3000))]
    )
    func preferredSize(width: Int32, height: Int32) {
        let resolution = PhotoCaptureResolution(width: width, height: height)
        #expect(resolution.isPreferred)
        #expect(resolution.megapixels == PhotoCaptureResolution.preferredMegapixels)
    }

    @Test(
        "Another size, 8 MP, 24 MP and 48 MP among them, is not the preferred one",
        arguments: [
            (Int32(3264), Int32(2448)), (Int32(1920), Int32(1080)), (Int32(5712), Int32(4284)),
            (Int32(8064), Int32(6048))
        ]
    )
    func otherSize(width: Int32, height: Int32) {
        #expect(PhotoCaptureResolution(width: width, height: height).isPreferred == false)
    }

    // MARK: - The size a camera shoots at

    /// The photo sizes of a format, the size the flow shoots at and its megapixels.
    struct SizesCase: Sendable, CustomTestStringConvertible {
        let name: String
        let sizes: [[Int32]]
        let offered: PhotoCaptureResolution?
        let megapixels: Int?

        var testDescription: String {
            name
        }
    }

    static let sizesCases = [
        SizesCase(
            name: "the back camera of an iPhone 17 Pro",
            sizes: [[4032, 3024], [5712, 4284], [8064, 6048]],
            offered: PhotoCaptureResolution(width: 4032, height: 3024),
            megapixels: 12
        ),
        SizesCase(
            name: "the 8 MP back camera of an older iPad",
            sizes: [[3264, 2448]],
            offered: PhotoCaptureResolution(width: 3264, height: 2448),
            megapixels: 8
        ),
        SizesCase(
            name: "the 7 MP front camera of an iPhone XR, with a smaller size beside it",
            sizes: [[1920, 1440], [3088, 2316]],
            offered: PhotoCaptureResolution(width: 3088, height: 2316),
            megapixels: 7
        ),
        SizesCase(
            name: "a camera whose sizes are all above 12 MP",
            sizes: [[5712, 4284], [8064, 6048]],
            offered: PhotoCaptureResolution(width: 8064, height: 6048),
            megapixels: 49
        ),
        SizesCase(name: "a format without photo sizes", sizes: [], offered: nil, megapixels: nil)
    ]

    @Test("A camera shoots at 12 MP where its format has it, or at its largest size", arguments: sizesCases)
    func offeredSize(sizesCase: SizesCase) {
        let sizes = sizesCase.sizes.map { (width: $0[0], height: $0[1]) }
        let offered = PhotoCaptureResolution.offered(among: sizes)
        #expect(offered == sizesCase.offered)
        #expect(offered?.megapixels == sizesCase.megapixels)
        #expect(offered?.isPreferred == sizesCase.megapixels.map { $0 == 12 })
    }

    // MARK: - The size a picture drawn smaller needs

    /// The photo sizes of a format, the largest size allowed and the smallest that reaches a short side of 1080.
    struct CoveringCase: Sendable, CustomTestStringConvertible {
        let name: String
        let sizes: [[Int32]]
        let limit: PhotoCaptureResolution
        let smallest: PhotoCaptureResolution?

        var testDescription: String {
            name
        }
    }

    static let coveringCases = [
        CoveringCase(
            name: "a smaller size that covers it",
            sizes: [[4032, 3024], [1920, 1440]],
            limit: PhotoCaptureResolution(width: 4032, height: 3024),
            smallest: PhotoCaptureResolution(width: 1920, height: 1440)
        ),
        CoveringCase(
            name: "a smaller size too small for it",
            sizes: [[1280, 960], [4032, 3024]],
            limit: PhotoCaptureResolution(width: 4032, height: 3024),
            smallest: PhotoCaptureResolution(width: 4032, height: 3024)
        ),
        CoveringCase(
            name: "the size of the limit only",
            sizes: [[4032, 3024], [5712, 4284]],
            limit: PhotoCaptureResolution(width: 4032, height: 3024),
            smallest: PhotoCaptureResolution(width: 4032, height: 3024)
        ),
        CoveringCase(
            name: "no size that covers it within the limit",
            sizes: [[1280, 960], [4032, 3024]],
            limit: PhotoCaptureResolution(width: 1280, height: 960),
            smallest: nil
        )
    ]

    @Test("A picture drawn smaller takes the smallest size that covers it, within the limit", arguments: coveringCases)
    func smallestCovering(coveringCase: CoveringCase) {
        let sizes = coveringCase.sizes.map { (width: $0[0], height: $0[1]) }
        let smallest = PhotoCaptureResolution.smallest(reaching: 1080, among: sizes, within: coveringCase.limit)
        #expect(smallest == coveringCase.smallest)
    }
}
