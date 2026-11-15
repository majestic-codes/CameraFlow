//
//  CameraFlowPreferencesTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 09.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@testable import CameraFlow

@Suite("Preferences: what the app keeps for the user", .temporaryDirectory, .timeLimit(.minutes(1)))
struct CameraFlowPreferencesTests {
    private static var savingOn: CameraFlowPreferences {
        var preferences = CameraFlowPreferences()
        preferences.isPhotoLibrarySavingEnabled = true
        return preferences
    }

    // MARK: - Coding

    @Test("Preferences survive a round trip through JSON, with the cases written by name and a switch as a Boolean")
    func roundTrip() throws {
        let data = try JSONEncoder().encode(Self.savingOn)
        #expect(try #require(String(data: data, encoding: .utf8)) == #"{"isPhotoLibrarySavingEnabled":true}"#)
        #expect(try JSONDecoder().decode(CameraFlowPreferences.self, from: data) == Self.savingOn)
    }

    @Test("A stored value from an older version decodes with nil for what it lacks, and ignores what it has extra")
    func missingAndUnknownFields() throws {
        let json = #"{"isPhotoLibrarySavingEnabled":true,"somethingNewer":true,"exposureBias":1.5}"#
        let decoded = try JSONDecoder().decode(CameraFlowPreferences.self, from: Data(json.utf8))
        #expect(decoded == Self.savingOn)
        let empty = try JSONDecoder().decode(CameraFlowPreferences.self, from: Data("{}".utf8))
        #expect(empty == CameraFlowPreferences())
    }

    @Test("Every setting of the user survives a round trip")
    func everySetting() throws {
        let data = try JSONEncoder().encode(Self.everything)
        #expect(try JSONDecoder().decode(CameraFlowPreferences.self, from: data) == Self.everything)
        #expect(try Self.decode(Self.storedFields) == Self.everything)
    }

    @Test(
        "Every setting of the user is stored under its own name with its raw value",
        arguments: storedFields.sorted { $0.key < $1.key }
    )
    func storedField(name: String, value: String) throws {
        let data = try JSONEncoder().encode(Self.everything)
        let json = try #require(String(data: data, encoding: .utf8))
        let field = "\"\(name)\":\(value)"
        #expect(json.contains(field), "\(field) is missing in \(json)")
    }

    @Test("A record without some of the properties decodes with nil for them")
    func partialRecord() throws {
        let stored = [
            "flashMode": #""on""#, "isLivePhotoEnabled": "true", "aspectRatio": #""16:9""#, "timer": "10",
            "photoFormat": #""RAW""#, "isDualCameraEnabled": "false"
        ]
        var expected = CameraFlowPreferences()
        expected.flashMode = .alwaysOn
        expected.isLivePhotoEnabled = true
        expected.aspectRatio = .sixteenByNine
        expected.timer = .tenSeconds
        expected.photoFormat = .raw
        expected.isDualCameraEnabled = false
        #expect(try Self.decode(stored) == expected)
    }

    @Test(
        "A stored value that is not one of its property's reads as a missing one, and every other property is kept",
        arguments: [
            ("flashMode", #""strobe""#),
            ("isLivePhotoEnabled", #""enabled""#),
            ("aspectRatio", "1.5"),
            ("timer", "7"),
            ("photoFormat", #""TIFF""#),
            ("isDualCameraEnabled", #"{"isOn":true}"#),
            ("isPhotoLibrarySavingEnabled", #""disabled""#),
            ("photoQuality", #"["low"]"#)
        ]
    )
    func garbage(name: String, value: String) throws {
        var damaged = Self.storedFields
        damaged[name] = value
        var missing = Self.storedFields
        missing[name] = nil
        let decoded = try Self.decode(damaged)
        #expect(decoded == (try Self.decode(missing)))
        #expect(decoded != Self.everything)
    }

    @Test("A stored value that is not a record at all does not decode", arguments: ["[]", #""on""#, "3"])
    func notARecord(json: String) {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(CameraFlowPreferences.self, from: Data(json.utf8))
        }
    }

    private static var everything: CameraFlowPreferences {
        var preferences = CameraFlowPreferences()
        preferences.flashMode = .off
        preferences.isLivePhotoEnabled = true
        preferences.aspectRatio = .square
        preferences.timer = .fiveSeconds
        preferences.photoFormat = .raw
        preferences.isDualCameraEnabled = false
        preferences.isPhotoLibrarySavingEnabled = true
        preferences.photoQuality = .medium
        return preferences
    }

    /// The stored form of `everything`: each property's name with its value as JSON.
    private static let storedFields = [
        "flashMode": #""off""#, "isLivePhotoEnabled": "true", "aspectRatio": #""1:1""#, "timer": "5",
        "photoFormat": #""RAW""#, "isDualCameraEnabled": "false",
        "isPhotoLibrarySavingEnabled": "true", "photoQuality": #""medium""#
    ]

    private static func decode(_ fields: [String: String]) throws -> CameraFlowPreferences {
        let members = fields.map { "\"\($0.key)\":\($0.value)" }
        let json = "{" + members.joined(separator: ",") + "}"
        return try JSONDecoder().decode(CameraFlowPreferences.self, from: Data(json.utf8))
    }
}
