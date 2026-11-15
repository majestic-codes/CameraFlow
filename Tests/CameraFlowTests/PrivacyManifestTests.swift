//
//  PrivacyManifestTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@testable import CameraFlow

/// The privacy manifest as a property list.
private struct PrivacyManifest: Decodable {
    let isTracking: Bool
    let trackingDomains: [String]
    let collectedDataTypes: [PrivacyCollectedDataType]
    let accessedAPIs: [PrivacyAccessedAPI]

    enum CodingKeys: String, CodingKey {
        case isTracking = "NSPrivacyTracking"
        case trackingDomains = "NSPrivacyTrackingDomains"
        case collectedDataTypes = "NSPrivacyCollectedDataTypes"
        case accessedAPIs = "NSPrivacyAccessedAPITypes"
    }
}

private struct PrivacyAccessedAPI: Decodable, Equatable {
    let category: String
    let reasons: [String]

    enum CodingKeys: String, CodingKey {
        case category = "NSPrivacyAccessedAPIType"
        case reasons = "NSPrivacyAccessedAPITypeReasons"
    }
}

private struct PrivacyCollectedDataType: Decodable {
    let name: String

    enum CodingKeys: String, CodingKey {
        case name = "NSPrivacyCollectedDataType"
    }
}

#if os(macOS)
/// An API Apple wants a reason for, by the category of the manifest: a name of the system's the sources use, or a
/// C function they call.
struct RequiredReasonAPI: Sendable, CustomTestStringConvertible {
    enum Use: Sendable {
        /// The name as a whole word, such as `.creationDate` but not `creationDateFormatter`.
        case name
        /// A call of the function, such as `stat(path, &info)` but not `status` or `state`.
        case call
    }

    let category: String
    let symbol: String
    let use: Use

    var testDescription: String {
        symbol
    }

    /// The use of the API in a line of code. A word ends where a letter, a digit or an underscore meets anything
    /// else, a dot among it, as in code.
    var pattern: Regex<AnyRegexOutput> {
        get throws {
            let pattern = switch use {
            case .name: try Regex("\\b\(symbol)\\b")
            case .call: try Regex("\\b\(symbol)\\s*\\(")
            }
            return pattern.wordBoundaryKind(.simple)
        }
    }

    /// A line of code that uses the API.
    var sample: String {
        switch use {
        case .name: "let value = resource.\(symbol)"
        case .call: "let result = \(symbol)(path, &information)"
        }
    }
}
#endif

/// `PrivacyInfo.xcprivacy` as the package bundle carries it.
@Suite("Privacy manifest")
struct PrivacyManifestTests {

    private func loadManifest() throws -> PrivacyManifest {
        let url = try #require(Bundle.module.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let data = try Data(contentsOf: url)
        return try PropertyListDecoder().decode(PrivacyManifest.self, from: data)
    }

    @Test("The bundle carries a manifest that tracks nothing and collects nothing")
    func noTrackingNoCollection() throws {
        let manifest = try loadManifest()
        #expect(manifest.isTracking == false)
        #expect(manifest.trackingDomains.isEmpty)
        #expect(manifest.collectedDataTypes.isEmpty)
    }

    @Test("The manifest declares the user defaults of the app and of a group, and the free space the shutter reads")
    func accessedAPIs() throws {
        let userDefaults = PrivacyAccessedAPI(
            category: "NSPrivacyAccessedAPICategoryUserDefaults",
            reasons: ["CA92.1", "1C8F.1"]
        )
        let diskSpace = PrivacyAccessedAPI(category: "NSPrivacyAccessedAPICategoryDiskSpace", reasons: ["E174.1"])
        #expect(try loadManifest().accessedAPIs == [userDefaults, diskSpace])
    }

    #if os(macOS)
    /// Apple's list of the APIs that need a reason, the names the sources may use them by.
    private static let requiredReasonAPIs = apis(
        "NSPrivacyAccessedAPICategoryFileTimestamp",
        names: [
            "creationDate", "modificationDate", "fileCreationDate", "fileModificationDate", "contentModificationDate",
            "contentModificationDateKey", "creationDateKey", "attributesOfItem", "getattrlist", "getattrlistbulk",
            "fgetattrlist", "getattrlistat"
        ],
        calls: ["stat", "fstat", "fstatat", "lstat"]
    ) + apis(
        "NSPrivacyAccessedAPICategoryDiskSpace",
        names: [
            "volumeAvailableCapacity", "volumeAvailableCapacityKey", "volumeAvailableCapacityForImportantUsage",
            "volumeAvailableCapacityForImportantUsageKey", "volumeAvailableCapacityForOpportunisticUsage",
            "volumeAvailableCapacityForOpportunisticUsageKey", "volumeTotalCapacity", "volumeTotalCapacityKey",
            "systemFreeSize", "systemSize", "attributesOfFileSystem", "getattrlist", "fgetattrlist", "getattrlistat"
        ],
        calls: ["statfs", "fstatfs", "statvfs", "fstatvfs"]
    ) + apis(
        "NSPrivacyAccessedAPICategorySystemBootTime",
        names: ["systemUptime", "mach_absolute_time"]
    ) + apis(
        "NSPrivacyAccessedAPICategoryActiveKeyboards",
        names: ["activeInputModes"]
    ) + apis(
        "NSPrivacyAccessedAPICategoryUserDefaults",
        names: ["UserDefaults", "AppStorage"]
    )

    private static func apis(_ category: String, names: [String], calls: [String] = []) -> [RequiredReasonAPI] {
        names.map { RequiredReasonAPI(category: category, symbol: $0, use: .name) }
            + calls.map { RequiredReasonAPI(category: category, symbol: $0, use: .call) }
    }

    @Test("The manifest declares exactly the required-reason APIs the sources name")
    func declaredAsUsed() throws {
        // The code of each file outside its comments and the texts of its literals.
        let code = try SourceTree.checkout().files.map { $0.bareCode.joined(separator: "\n") }
        var used: Set<String> = []
        for api in Self.requiredReasonAPIs {
            let pattern = try api.pattern
            // The plain text of the name comes first: it is quick to find, and a file without it holds no use.
            if code.contains(where: { $0.contains(api.symbol) && $0.contains(pattern) }) {
                used.insert(api.category)
            }
        }
        let declared = try loadManifest().accessedAPIs.map(\.category)
        #expect(Set(declared) == used)
    }

    @Test("Each required-reason API is found where the code uses it", arguments: requiredReasonAPIs)
    func patternFindsItsAPI(api: RequiredReasonAPI) throws {
        #expect(api.sample.contains(try api.pattern))
    }

    @Test(
        "No required-reason API is found in a name that only starts or ends like one",
        arguments: [
            "let status = state(of: photo)",
            "statusBar.isHidden = true",
            "let formatter = creationDateFormatter",
            "let date = lastModificationDate",
            "let defaults = userDefaultsKey",
            "let estimate = estimateSystemSize(of: photo)"
        ]
    )
    func patternsSkipOtherNames(line: String) throws {
        for api in Self.requiredReasonAPIs {
            #expect(line.contains(try api.pattern) == false, "\(api.symbol) is found in \(line)")
        }
    }
    #endif
}
