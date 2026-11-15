//
//  ArchitectureTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(macOS)
import Foundation
import Testing

/// The dependency rules between the folders of `Sources/CameraFlow`, checked on the source text. A rule over a
/// folder that holds no file yet has nothing to object to.
@Suite("Layers of the package")
struct ArchitectureTests {
    /// The folders of the module in the order of `AGENTS.md`: a folder depends only on the folders before it. A file
    /// lies in the deepest folder that holds it, so `State/Flow` comes after `State`.
    private static let layers = [
        "API/Values", "Domain", "DesignTokens", "Capture/Processing", "Capture/Device", "Capture/Simulated",
        "Haptics", "Motion", "Location", "Library", "PhotoLibrary", "Markup", "State", "State/Flow", "Presentation",
        "Views", "Composition", "API/Screens"
    ]

    /// The folders the camera came in, which a tree read from the wrong place would show empty.
    private static let carriedLayers = [
        "API/Values", "Domain", "DesignTokens", "Capture/Processing", "Capture/Device", "Capture/Simulated",
        "Haptics", "State", "Presentation", "Views", "Composition", "API/Screens"
    ]

    /// The frameworks of the interface and of the device, which the logic below the views stays free of.
    private static let deviceFrameworks: Set<String> = [
        "SwiftUI", "UIKit", "AVKit", "AVFoundation", "CoreHaptics", "PhotosUI", "Photos", "PencilKit", "PaperKit",
        "CoreMotion"
    ]

    /// A framework and the only folders that may import it.
    struct FrameworkHome: Sendable, CustomTestStringConvertible {
        let framework: String
        let folders: [String]

        var testDescription: String {
            "\(framework) under \(folders.joined(separator: ", "))"
        }
    }

    private static let frameworkHomes = [
        FrameworkHome(framework: "AVFoundation", folders: ["Capture/Device"]),
        FrameworkHome(framework: "AVKit", folders: ["Views/Screen"]),
        FrameworkHome(framework: "CoreHaptics", folders: ["Haptics"]),
        FrameworkHome(framework: "CoreMotion", folders: ["Motion"]),
        FrameworkHome(framework: "PhotosUI", folders: ["Library", "Views/Flow"]),
        FrameworkHome(framework: "Photos", folders: ["PhotoLibrary"]),
        FrameworkHome(framework: "PencilKit", folders: ["Markup"]),
        FrameworkHome(framework: "PaperKit", folders: ["Markup"])
    ]

    /// The folders of the adapters to the system and their stand-ins, whose concrete types no other folder names but
    /// the composition.
    private static let adapterFolders = [
        "Capture/Device", "Capture/Simulated", "Haptics", "Motion", "Location", "Library", "PhotoLibrary", "Markup"
    ]

    /// The concrete adapters further folders name, with those folders: the views show the canvas of the screen, and
    /// the public views run the flow over it.
    private static let sharedAdapters = ["EmbeddedMarkupCanvas": ["Views", "API/Screens"]]

    /// The settings the camera shares with the set. The settings hold them among the settings of the next photo, the
    /// introduction asks for the library through the saving, and the set brings its picks to the quality and saves
    /// through the saving.
    private static let sharedSettings: Set<String> = ["PhotoQualityModel", "PhotoLibrarySavingModel"]

    /// A declaration with the `public` or `open` modifier, whatever modifiers come between.
    private static var publicDeclaration: Regex<Substring> {
        #/
        (?:^|\s) (?:public|open) \s+ (?:[\w()]+ \s+)*?
        (?:func|var|let|init|struct|class|enum|protocol|actor|extension|typealias|subscript
            |operator|macro|precedencegroup) \b
        /#
    }

    /// The camera of a flow, reached through `CameraFlowModel.camera`.
    private static var flowCamera: Regex<Substring> {
        #/\.camera\./#
    }

    @Test("Every source file lies in a layer")
    func knownLayers() throws {
        let offenders = try SourceTree.checkout().files.filter { file in
            Self.layers.contains(where: file.isUnder) == false
        }
        #expect(offenders.isEmpty, "Files outside the layers: \(offenders.map(\.path))")
    }

    @Test("The carried layers are read from the checkout", arguments: carriedLayers)
    func carriedLayer(folder: String) throws {
        let files = try SourceTree.checkout().files.filter { $0.isUnder(folder) }
        #expect(files.isEmpty == false)
    }

    @Test("The source is read without its comments, and with the text of its string literals blanked")
    func sourceReading() {
        let text = """
            let url = "https://example.com/PhotoCameraModel" // Names PhotoCameraModel
            /* Names PhotoCameraModel
               over two lines */ let name = "PhotoCameraModel of \\(ZoomModel.self)"
            let raw = #"A "PhotoCameraModel" of \\(FocusModel.self)"#
            """
        let file = SourceTree.File(path: "State/Sample.swift", text: text)
        #expect(file.code.count == 4)
        #expect(file.code[0].contains("https://example.com/PhotoCameraModel"))
        #expect(file.code[0].contains("Names") == false)
        #expect(file.code[1].isEmpty)
        #expect(file.bareCode.contains { $0.contains("PhotoCameraModel") } == false)
        #expect(file.typeReferences == ["ZoomModel"])
    }

    @Test("A folder names no type declared only in a folder after it")
    func dependencyOrder() throws {
        let tree = try SourceTree.checkout()
        let homes = Self.typeHomes(in: tree)
        let state = try #require(Self.layers.firstIndex(of: "State"))
        #expect(homes["PhotoCameraModel"] == [state])
        let offenders = tree.files.compactMap { file -> String? in
            guard let layer = file.layer(in: Self.layers) else { return nil }
            let later = file.typeReferences.subtracting(file.declaredTypeNames).filter { name in
                guard let declaringLayers = homes[name] else { return false }
                return declaringLayers.allSatisfy { $0 > layer }
            }
            return later.isEmpty ? nil : "\(file.path) names \(later.sorted())"
        }
        #expect(offenders.isEmpty, "Types of later folders named in: \(offenders)")
    }

    /// The layers that declare each type at their top level.
    private static func typeHomes(in tree: SourceTree) -> [String: Set<Int>] {
        var homes: [String: Set<Int>] = [:]
        for file in tree.files {
            guard let layer = file.layer(in: layers) else { continue }
            for name in file.topLevelTypeNames {
                homes[name, default: []].insert(layer)
            }
        }
        return homes
    }

    @Test("Only PhotoCameraModel knows the models of the camera, besides the settings the set shares")
    func cameraModels() throws {
        let tree = try SourceTree.checkout()
        let state = try #require(Self.layers.firstIndex(of: "State"))
        let models = Set(tree.files.filter { $0.layer(in: Self.layers) == state }.flatMap { file in
            file.typeNames(declaredAs: ["class"], nested: false).filter { $0.hasSuffix("Model") }
        })
        #expect(models.isSuperset(of: ["PhotoCameraModel", "CameraSessionModel", "PhotoSettingsModel"]))
        let offenders = tree.files.filter { $0.isUnder("State") }.compactMap { file -> String? in
            let own = file.topLevelTypeNames.union(file.extendedTypeNames)
            guard own.contains("PhotoCameraModel") == false else { return nil }
            var allowed = own.union(Self.sharedSettings)
            if own.contains("CameraFlowModel") {
                allowed.insert("PhotoCameraModel")
            }
            let known = file.typeReferences.intersection(models).subtracting(allowed)
            return known.isEmpty ? nil : "\(file.path) names \(known.sorted())"
        }
        #expect(offenders.isEmpty, "Models that know another model of the camera: \(offenders)")
    }

    @Test("A device framework is imported in its own folders only", arguments: frameworkHomes)
    func frameworkHome(home: FrameworkHome) throws {
        let offenders = try SourceTree.checkout().files.filter { file in
            file.imports.contains(home.framework) && home.folders.contains(where: file.isUnder) == false
        }
        #expect(offenders.isEmpty, "\(home.framework) outside its folders: \(offenders.map(\.path))")
    }

    @Test("One view at most shows the system photo picker")
    func photoPickerView() throws {
        let pickers = try SourceTree.checkout().files.filter { $0.isUnder("Views") && $0.imports.contains("PhotosUI") }
        #expect(pickers.count <= 1, "PhotosUI in several views: \(pickers.map(\.path))")
    }

    private static let neutralLayers = [
        "API/Values", "Domain", "Capture/Processing", "Capture/Simulated", "State", "State/Flow", "Presentation"
    ]

    @Test("The layers below the views import no interface or device framework", arguments: neutralLayers)
    func neutralLayer(folder: String) throws {
        let offenders = try SourceTree.checkout().files.filter { file in
            file.isUnder(folder) && file.imports.isDisjoint(with: Self.deviceFrameworks) == false
        }
        #expect(offenders.isEmpty, "Interface or device frameworks in \(folder): \(offenders.map(\.path))")
    }

    @Test("The public values depend on nothing but the standard value frameworks")
    func publicValues() throws {
        let allowed: Set<String> = ["Foundation", "CoreGraphics", "UniformTypeIdentifiers"]
        let offenders = try SourceTree.checkout().files.filter { file in
            file.isUnder("API/Values") && file.imports.isSubset(of: allowed) == false
        }
        #expect(offenders.isEmpty, "Other imports in API/Values: \(offenders.map(\.path))")
    }

    @Test("The models and the presentation logic know no layer", arguments: ["API/Values", "State", "Presentation"])
    func layerFree(folder: String) throws {
        let files = try SourceTree.checkout().files
        let offenders = files.filter { $0.isUnder(folder) && $0.imports.contains("QuartzCore") }
        #expect(offenders.isEmpty, "QuartzCore in \(folder): \(offenders.map(\.path))")
    }

    @Test(
        "The public declaration finds every kind of declaration, whatever modifiers come between",
        arguments: [
            "public var name", "public private(set) var count", "public internal(set) var value", "public actor Store",
            "public prefix operator ~~", "open class Base", "public static func make()", "public init()"
        ]
    )
    func publicDeclarationPattern(line: String) {
        #expect(line.contains(Self.publicDeclaration))
    }

    @Test("Public declarations live under API")
    func publicDeclarations() throws {
        let pattern = Self.publicDeclaration
        let offenders = try SourceTree.checkout().files.filter { file in
            file.isUnder("API") == false && file.bareCode.contains { line in
                (line.contains("public") || line.contains("open")) && line.contains(pattern)
            }
        }
        #expect(offenders.isEmpty, "Public declarations outside API: \(offenders.map(\.path))")
    }

    @Test("Only the screen, the composition and the public views take the whole camera model")
    func wholeModel() throws {
        let allowed = ["State/", "Composition/", "API/Screens/", "Views/Flow/CameraFlowScreen.swift"]
        let pattern = Self.flowCamera
        let offenders = try SourceTree.checkout().files.filter { file in
            allowed.contains(where: file.path.hasPrefix) == false
                && file.bareCode.contains { $0.contains("PhotoCameraModel") || $0.contains(pattern) }
        }
        #expect(offenders.isEmpty, "PhotoCameraModel named or reached in: \(offenders.map(\.path))")
    }

    @Test(
        "A concrete type of an adapter folder is named in that folder and the composition only",
        arguments: adapterFolders
    )
    func concreteAdapters(folder: String) throws {
        let tree = try SourceTree.checkout()
        let concreteKinds: Set<String> = ["struct", "class", "enum", "actor"]
        let concrete = Set(tree.files.filter { $0.isUnder(folder) }.flatMap { file in
            file.typeNames(declaredAs: concreteKinds, nested: false)
        })
        let offenders = tree.files.compactMap { file -> String? in
            guard file.isUnder(folder) == false, file.isUnder("Composition") == false else { return nil }
            let named = file.typeReferences.intersection(concrete).filter { name in
                guard let folders = Self.sharedAdapters[name] else { return true }
                return folders.contains(where: file.isUnder) == false
            }
            return named.isEmpty ? nil : "\(file.path) names \(named.sorted())"
        }
        #expect(offenders.isEmpty, "Concrete types of \(folder) named in: \(offenders)")
    }

    @Test("Only the location folder talks to Core Location's manager")
    func locationManager() throws {
        let offenders = try SourceTree.checkout().files.filter { file in
            file.isUnder("Location") == false && file.bareCode.contains { $0.contains("CLLocationManager") }
        }
        #expect(offenders.isEmpty, "CLLocationManager named in: \(offenders.map(\.path))")
    }
}
#endif
