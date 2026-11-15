//
//  PencilStrokeFixture.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import Testing
@testable import CameraFlow

/// PencilKit drawings of one straight marker stroke, from (5, 6) to (11, 6) and four points wide, as PencilKit
/// serialised them on macOS 27.
///
/// The tests cannot make a stroke themselves. PencilKit keeps a state in the preferences of the app once a
/// drawing gets a stroke, and stops a process that has no bundle identifier, which the SwiftPM test process is.
/// Reading a drawing and rendering it need no such state.
enum PencilStrokeFixture {
    /// A canvas of the shape of `OrientedPhotoFixture`, a quarter of its pixels on each side.
    static let canvasSize = CGSize(width: 32, height: 24)
    /// The middle of the stroke, which lies over the overlay spot of `OrientedPhotoFixture`.
    static let strokeMiddle = (column: 8, row: 6)

    static func redInk() throws -> MarkupDrawing {
        try drawing(
            base64: """
            d3Jk8AEACAASEAAAAAAAAAAAAAAAAAAAAAASECIs4FnXl0g9vM/wXgQG8xoaBggAEAAYABoGCAEQARgBIjcKFA0AAIA/FQAAAAAd\
            AAAAACUAAIA/EhRjb20uYXBwbGUuaW5rLm1hcmtlchgDQQAAAAAAAAAAKpsBChAKSWCfLZlJvKvqD/2/K32kEgYIABABGAEaBggA\
            EAEYACAAKlgKEK8kJKbvfE6EvPWCiLwE3tsRAAAAAAAAAAAYAiADKPwfMhoAAIBA6AMAAOgD/38AAP9/AACAQAAAAAAAADoYAACg\
            QAAAwEAAAAAAAAAwQQAAwEAAAIA/MhQNAACAPxUAAIBAHQAAYEElAACAQEDA6a/PywU6BggAEAAYAEIQh3IaN9p5TpmERBVsAqWv\
            Yg==
            """
        )
    }

    /// The canvas a 4:3 portrait photo has on a 393 pt wide iPhone, the frame the review shows it in.
    static let portraitCanvasSize = CGSize(width: 393, height: 524)
    /// The middle of `verticalRedInk`'s stroke, in points from the left side of its canvas.
    static let verticalStrokeMiddle: CGFloat = 196.5

    /// A red pen stroke four points wide down the middle of `portraitCanvasSize`, from its top edge to its bottom
    /// edge.
    static func verticalRedInk() throws -> MarkupDrawing {
        try drawing(
            base64: """
            d3Jk8AIACAASEAAAAAAAAAAAAAAAAAAAAAASEGpdBPR0u06rpbVO8Sh11qsaBggAEAAYABoGCAEQARgBIkEKFA0AAIA/FQAAAAAd\
            AAAAACUAAIA/EhFjb20uYXBwbGUuaW5rLnBlbhgDIgtmaXhlZC13aWR0aEEAAAAAAAAAACq2DQoQ3NQmNoYFT0iQCFvP7aaIehIG\
            CAAQARgBGgYIABABGAAgACryDAoQmp62MGMcRt+LQw+0FHRwvhEAAABA5CfNwRiEASADKPwfMhoAAIBA6AMAAOgD/38AAP9/AACA\
            QAAAAAAAADqwDACAREMAAAAAAAAAAACAREMAAIBAbxKDOwCAREMAAABBbxIDPACAREMAAEBBpptEPACAREMAAIBBbxKDPACAREMA\
            AKBBCtejPACAREMAAMBBppvEPACAREMAAOBBQmDlPACAREMAAABCbxIDPQCAREMAABBCvHQTPQCAREMAACBCCtcjPQCAREMAADBC\
            WDk0PQCAREMAAEBCpptEPQCAREMAAFBC9P1UPQCAREMAAGBCQmBlPQCAREMAAHBCj8J1PQCAREMAAIBCbxKDPQCAREMAAIhClkOL\
            PQCAREMAAJBCvHSTPQCAREMAAJhC46WbPQCAREMAAKBCCtejPQCAREMAAKhCMQisPQCAREMAALBCWDm0PQCAREMAALhCf2q8PQCA\
            REMAAMBCppvEPQCAREMAAMhCzczMPQCAREMAANBC9P3UPQCAREMAANhCGy/dPQCAREMAAOBCQmDlPQCAREMAAOhCaJHtPQCAREMA\
            APBCj8L1PQCAREMAAPhCtvP9PQCAREMAAABDbxIDPgCAREMAAARDAisHPgCAREMAAAhDlkMLPgCAREMAAAxDKVwPPgCAREMAABBD\
            vHQTPgCAREMAABRDUI0XPgCAREMAABhD46UbPgCAREMAABxDd74fPgCAREMAACBDCtcjPgCAREMAACRDnu8nPgCAREMAAChDMQgs\
            PgCAREMAACxDxSAwPgCAREMAADBDWDk0PgCAREMAADRD7FE4PgCAREMAADhDf2o8PgCAREMAADxDEoNAPgCAREMAAEBDpptEPgCA\
            REMAAERDObRIPgCAREMAAEhDzcxMPgCAREMAAExDYOVQPgCAREMAAFBD9P1UPgCAREMAAFRDhxZZPgCAREMAAFhDGy9dPgCAREMA\
            AFxDrkdhPgCAREMAAGBDQmBlPgCAREMAAGRD1XhpPgCAREMAAGhDaJFtPgCAREMAAGxD/KlxPgCAREMAAHBDj8J1PgCAREMAAHRD\
            I9t5PgCAREMAAHhDtvN9PgCAREMAAHxDJQaBPgCAREMAAIBDbxKDPgCAREMAAIJDuB6FPgCAREMAAIRDAiuHPgCAREMAAIZDTDeJ\
            PgCAREMAAIhDlkOLPgCAREMAAIpD30+NPgCAREMAAIxDKVyPPgCAREMAAI5Dc2iRPgCAREMAAJBDvHSTPgCAREMAAJJDBoGVPgCA\
            REMAAJRDUI2XPgCAREMAAJZDmpmZPgCAREMAAJhD46WbPgCAREMAAJpDLbKdPgCAREMAAJxDd76fPgCAREMAAJ5DwcqhPgCAREMA\
            AKBDCtejPgCAREMAAKJDVOOlPgCAREMAAKRDnu+nPgCAREMAAKZD5/upPgCAREMAAKhDMQisPgCAREMAAKpDexSuPgCAREMAAKxD\
            xSCwPgCAREMAAK5DDi2yPgCAREMAALBDWDm0PgCAREMAALJDokW2PgCAREMAALRD7FG4PgCAREMAALZDNV66PgCAREMAALhDf2q8\
            PgCAREMAALpDyXa+PgCAREMAALxDEoPAPgCAREMAAL5DXI/CPgCAREMAAMBDppvEPgCAREMAAMJD8KfGPgCAREMAAMRDObTIPgCA\
            REMAAMZDg8DKPgCAREMAAMhDzczMPgCAREMAAMpDF9nOPgCAREMAAMxDYOXQPgCAREMAAM5DqvHSPgCAREMAANBD9P3UPgCAREMA\
            ANJDPQrXPgCAREMAANRDhxbZPgCAREMAANZD0SLbPgCAREMAANhDGy/dPgCAREMAANpDZDvfPgCAREMAANxDrkfhPgCAREMAAN5D\
            +FPjPgCAREMAAOBDQmDlPgCAREMAAOJDi2znPgCAREMAAORD1XjpPgCAREMAAOZDH4XrPgCAREMAAOhDaJHtPgCAREMAAOpDsp3v\
            PgCAREMAAOxD/KnxPgCAREMAAO5DRrbzPgCAREMAAPBDj8L1PgCAREMAAPJD2c73PgCAREMAAPRDI9v5PgCAREMAAPZDbef7PgCA\
            REMAAPhDtvP9PgCAREMAAPpDAAAAPwCAREMAAPxDJQYBPwCAREMAAP5DSgwCPwCAREMAAABEbxIDPwCAREMAAAFEkxgEPwCAREMA\
            AAJEuB4FPwCAREMAAANE3SQGPzIUDQAAQkMVAABAwB0AAKBAJQCABERA4Onck+wFOgYIABAAGABCEOzLurV3s0dolR9054iNysk=
            """,
            canvasSize: portraitCanvasSize
        )
    }

    static func blackInk() throws -> MarkupDrawing {
        try drawing(
            base64: """
            d3Jk8AEACAASEAAAAAAAAAAAAAAAAAAAAAASECIs4FnXl0g9vM/wXgQG8xoaBggAEAAYABoGCAEQARgBIjcKFA0AAAAAFQAAAAAd\
            AAAAACUAAIA/EhRjb20uYXBwbGUuaW5rLm1hcmtlchgDQQAAAAAAAAAAKpsBChBiNNg7D19CTqxmRKwSaH+gEgYIABABGAEaBggA\
            EAEYACAAKlgKEOiQFThR/kWZscTfh2h2WqoRAAAAAAAAAAAYAiADKPwfMhoAAIBA6AMAAOgD/38AAP9/AACAQAAAAAAAADoYAACg\
            QAAAwEAAAAAAAAAwQQAAwEAAAIA/MhQNAACAPxUAAIBAHQAAYEElAACAQEDgnpSK8gc6BggAEAAYAEIQG6nUEXrnRiG7znAA/iSJ\
            pw==
            """
        )
    }

    private static func drawing(base64: String, canvasSize: CGSize = Self.canvasSize) throws -> MarkupDrawing {
        let data = try #require(Data(base64Encoded: base64))
        return try MarkupDrawing(engine: .pencilKit, data: data, canvasSize: canvasSize)
    }
}
