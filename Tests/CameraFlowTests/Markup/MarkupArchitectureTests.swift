//
//  MarkupArchitectureTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(macOS)
import Foundation
import Testing

/// The rules of the markup services, checked on the source text like the layers in `ArchitectureTests`, which also
/// keeps every concrete canvas, renderer and painter in the markup folder and the composition.
@Suite("Markup services in the layers")
struct MarkupArchitectureTests {

    @Test("The view controller of a canvas is known to the markup folder, the views and the composition only")
    func embeddableCanvas() throws {
        let allowed = ["Markup/", "Views/", "Composition/"]
        let offenders = try SourceTree.checkout().files.filter { file in
            allowed.contains(where: file.path.hasPrefix) == false
                && file.bareCode.contains { $0.contains("EmbeddableMarkupCanvas") }
        }
        #expect(offenders.isEmpty, "EmbeddableMarkupCanvas named in: \(offenders.map(\.path))")
    }

    @Test("The markup folder is read from the checkout")
    func markupFolder() throws {
        let files = try SourceTree.checkout().files.filter { $0.isUnder("Markup") }
        #expect(files.isEmpty == false)
    }
}
#endif
