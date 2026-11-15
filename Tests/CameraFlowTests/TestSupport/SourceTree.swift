//
//  SourceTree.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(macOS)
import Foundation

/// The Swift files of the package sources, read from the checkout the tests were built from.
struct SourceTree {
    /// The patterns a file is read with, made once for every file of the tree.
    struct Patterns {
        /// An import line with its attributes and its kind, capturing the module name.
        let importLine = #/
            ^\s* (?:@\w+ (?:\([^)]*\))? \s+)* import \s+
            (?:(?:struct|class|enum|protocol|func) \s+)? (\w+)
            /#
        /// The start of a declaration of a type or an extension, its attributes and modifiers, up to its name:
        /// captures its kind.
        let declaration = #/
            ^\s* (?:@\w+ (?:\([^)]*\))? \s+)*
            (?:(?:public|open|internal|fileprivate|private|final|indirect|nonisolated) (?:\(\w+\))? \s+)*
            (struct|class|enum|protocol|actor|typealias|extension) \s+
            /#
    }

    /// A type or an extension the file declares: its kind, such as `class`, and its name.
    struct Declaration {
        let kind: String
        let name: String
        /// Whether it starts a line, outside any other declaration.
        let isTopLevel: Bool
    }

    struct File {
        /// Path below `Sources/CameraFlow`, such as `Capture/Device/CaptureSessionCore.swift`.
        let path: String
        let text: String
        let lines: [String]
        /// The code of every line, without its comments. A `//` inside a string literal is code.
        let code: [String]
        /// The code of every line, without its comments and with the text of its string literals blanked out: what
        /// names types and values. The code of an interpolation stays.
        let bareCode: [String]
        /// The modules the file imports.
        let imports: Set<String>
        /// The types and extensions the file declares, nested ones too, in the order of the source.
        let declarations: [Declaration]
        /// The capitalized names the code uses on their own, not after a dot: the types it names, besides the
        /// constants and the cases written so.
        let typeReferences: Set<String>

        init(path: String, text: String) {
            self.init(path: path, text: text, patterns: Patterns())
        }

        init(path: String, text: String, patterns: Patterns) {
            self.path = path
            self.text = text
            lines = text.components(separatedBy: "\n")
            var scanner = SourceScanner(text)
            scanner.scanCode()
            code = String(scanner.code).components(separatedBy: "\n")
            bareCode = String(scanner.bareCode).components(separatedBy: "\n")
            imports = Set(lines.compactMap { line in
                guard line.contains("import") else { return nil }
                return line.firstMatch(of: patterns.importLine).map { String($0.1) }
            })
            declarations = bareCode.compactMap { line in
                Self.declaration(on: line, pattern: patterns.declaration)
            }
            typeReferences = Self.typeReferences(in: bareCode)
        }

        func isUnder(_ folder: String) -> Bool {
            path.hasPrefix(folder + "/")
        }

        /// The index of the deepest of the folders that holds the file, such as `State/Flow` before `State`, nil when
        /// none does.
        func layer(in folders: [String]) -> Int? {
            let holding = folders.indices.filter { isUnder(folders[$0]) }
            return holding.max { folders[$0].count < folders[$1].count }
        }

        /// The types the file declares at its top level, the extensions left out.
        var topLevelTypeNames: Set<String> {
            typeNames(declaredAs: SourceTree.typeKinds, nested: false)
        }

        /// The types the file declares, nested ones too, the extensions left out.
        var declaredTypeNames: Set<String> {
            typeNames(declaredAs: SourceTree.typeKinds, nested: true)
        }

        /// The types the file extends at its top level.
        var extendedTypeNames: Set<String> {
            typeNames(declaredAs: ["extension"], nested: false)
        }

        /// The names of the declarations of these kinds, such as `class` or `extension`: at the top level, or nested
        /// ones too.
        func typeNames(declaredAs kinds: Set<String>, nested: Bool) -> Set<String> {
            Set(declarations.filter { kinds.contains($0.kind) && (nested || $0.isTopLevel) }.map(\.name))
        }

        /// The declaration of a type or an extension that starts on the line, nil when none does or its name is not
        /// capitalized.
        private static func declaration(on line: String, pattern: Regex<(Substring, Substring)>) -> Declaration? {
            guard SourceTree.declarationKinds.contains(where: line.contains),
                  let match = line.firstMatch(of: pattern) else { return nil }
            let name = line[match.range.upperBound...].prefix { $0.isLetter || $0.isNumber || $0 == "_" }
            guard name.first?.isUppercase == true else { return nil }
            return Declaration(kind: String(match.1), name: String(name), isTopLevel: line.first?.isWhitespace == false)
        }

        private static func typeReferences(in bareCode: [String]) -> Set<String> {
            var names: Set<String> = []
            var name = String.UnicodeScalarView()
            var previous: Unicode.Scalar = " "
            for scalar in bareCode.joined(separator: "\n").unicodeScalars {
                if SourceTree.isNamePart(scalar) {
                    if name.isEmpty == false || SourceTree.startsName(scalar, after: previous) {
                        name.append(scalar)
                    }
                } else if name.isEmpty == false {
                    names.insert(String(name))
                    name = String.UnicodeScalarView()
                }
                previous = scalar
            }
            if name.isEmpty == false {
                names.insert(String(name))
            }
            return names
        }
    }

    enum Failure: Error {
        case packageRootNotFound(String)
    }

    /// `Sources/CameraFlow` of the checkout.
    let directory: URL
    let files: [File]

    /// The declarations that make a type.
    private static let typeKinds: Set<String> = ["struct", "class", "enum", "protocol", "actor", "typealias"]

    /// The declarations that make a type or extend one.
    private static let declarationKinds = typeKinds.union(["extension"])

    private static let loaded = Result { try Self() }

    /// The sources of the checkout, read once for all the tests.
    static func checkout() throws -> Self {
        try loaded.get()
    }

    /// Whether a character belongs to a name: a letter, a digit or an underscore.
    private static func isNamePart(_ scalar: Unicode.Scalar) -> Bool {
        scalar.properties.isAlphabetic || scalar.properties.numericType != nil || scalar == "_"
    }

    /// Whether a name starts here: a capital that follows no other part of a name, no dot and no `$`.
    private static func startsName(_ scalar: Unicode.Scalar, after previous: Unicode.Scalar) -> Bool {
        scalar.properties.isUppercase && isNamePart(previous) == false && previous != "." && previous != "$"
    }

    private init(testFilePath: String = #filePath) throws {
        let sources = try Self.packageRoot(above: testFilePath).appendingPathComponent("Sources/CameraFlow")
        let paths = try FileManager.default.subpathsOfDirectory(atPath: sources.path)
        let patterns = Patterns()
        directory = sources
        files = try paths.filter { $0.hasSuffix(".swift") }.sorted().map { path in
            let text = try String(contentsOf: sources.appendingPathComponent(path), encoding: .utf8)
            return File(path: path, text: text, patterns: patterns)
        }
    }

    private static func packageRoot(above path: String) throws -> URL {
        var directory = URL(fileURLWithPath: path).deletingLastPathComponent()
        while directory.path != "/" {
            if FileManager.default.fileExists(atPath: directory.appendingPathComponent("Package.swift").path) {
                return directory
            }
            directory = directory.deletingLastPathComponent()
        }
        throw Failure.packageRootNotFound(path)
    }
}

/// Reads Swift source as the compiler splits it: comments, string and regex literals with the interpolations of the
/// strings, and the code around them. Line breaks stay where they are, so a line of the result is the line of the
/// source.
struct SourceScanner {
    /// The source without its comments.
    private(set) var code = String.UnicodeScalarView()
    /// The source without its comments, the text of every literal replaced by spaces.
    private(set) var bareCode = String.UnicodeScalarView()
    private let scalars: [Unicode.Scalar]
    private var index = 0

    private static let lineCommentStart = Array("//".unicodeScalars)
    private static let blockCommentStart = Array("/*".unicodeScalars)
    private static let blockCommentEnd = Array("*/".unicodeScalars)

    /// How a literal ends and where its text gives way to code.
    private struct Literal {
        let opening: [Unicode.Scalar]
        let closing: [Unicode.Scalar]
        /// What starts an escape, none for a regex literal, whose text has no escape of the string kind.
        let escape: [Unicode.Scalar]
    }

    init(_ text: String) {
        scalars = Array(text.unicodeScalars)
    }

    /// Reads code to the end of the source.
    mutating func scanCode() {
        scanCode(inInterpolation: false)
    }

    /// Reads code, or the code of an interpolation up to its closing parenthesis, which is left to the string.
    private mutating func scanCode(inInterpolation: Bool) {
        var depth = 0
        while index < scalars.count {
            let scalar = scalars[index]
            if scalar == "/", isAt(Self.lineCommentStart) {
                skipLineComment()
            } else if scalar == "/", isAt(Self.blockCommentStart) {
                skipBlockComment()
            } else if scalar == "#" || scalar == "\"", let literal = literalStart() {
                scanLiteral(literal)
            } else {
                if inInterpolation, scalar == ")" {
                    guard depth > 0 else { return }
                    depth -= 1
                } else if inInterpolation, scalar == "(" {
                    depth += 1
                }
                emit(scalar, bare: scalar)
                index += 1
            }
        }
    }

    private mutating func skipLineComment() {
        while index < scalars.count, scalars[index] != "\n" {
            index += 1
        }
    }

    /// Skips a block comment, nested ones in it too, and keeps its line breaks.
    private mutating func skipBlockComment() {
        var depth = 0
        while index < scalars.count {
            if isAt(Self.blockCommentStart) {
                depth += 1
                index += 2
            } else if isAt(Self.blockCommentEnd) {
                depth -= 1
                index += 2
                if depth == 0 { return }
            } else {
                if scalars[index] == "\n" {
                    emit("\n", bare: "\n")
                }
                index += 1
            }
        }
    }

    /// The literal that starts here: a string, single or multi-line and raw or not, or a regex between `#/` and
    /// `/#`. Nil when none does.
    private func literalStart() -> Literal? {
        var end = index
        while end < scalars.count, scalars[end] == "#" {
            end += 1
        }
        guard end < scalars.count else { return nil }
        let hashes = Array(scalars[index..<end])
        let backslash: [Unicode.Scalar] = ["\\"]
        switch scalars[end] {
        case "\"":
            let tripleQuote: [Unicode.Scalar] = ["\"", "\"", "\""]
            let quotes = isAt(hashes + tripleQuote) ? tripleQuote : ["\""]
            return Literal(opening: hashes + quotes, closing: quotes + hashes, escape: backslash + hashes)
        case "/" where !hashes.isEmpty:
            return Literal(opening: hashes + ["/"], closing: ["/"] + hashes, escape: [])
        default:
            return nil
        }
    }

    /// Reads a literal, its text blanked in `bareCode`. The code of the interpolations of a string is read as code.
    private mutating func scanLiteral(_ literal: Literal) {
        take(literal.opening)
        while index < scalars.count {
            if isAt(literal.closing) {
                take(literal.closing)
                return
            }
            var length = 1
            let escape = literal.escape
            if escape.isEmpty == false, isAt(escape) {
                guard !isAt(escape + ["("]) else {
                    take(escape + ["("])
                    scanCode(inInterpolation: true)
                    continue
                }
                length += escape.count
            }
            for _ in 0..<length where index < scalars.count {
                let scalar = scalars[index]
                emit(scalar, bare: scalar == "\n" ? "\n" : " ")
                index += 1
            }
        }
    }

    private func isAt(_ pattern: [Unicode.Scalar]) -> Bool {
        guard index + pattern.count <= scalars.count else { return false }
        return pattern.indices.allSatisfy { scalars[index + $0] == pattern[$0] }
    }

    /// Takes a delimiter as code and as bare code alike, and moves past it.
    private mutating func take(_ delimiter: [Unicode.Scalar]) {
        code.append(contentsOf: delimiter)
        bareCode.append(contentsOf: delimiter)
        index += delimiter.count
    }

    private mutating func emit(_ scalar: Unicode.Scalar, bare: Unicode.Scalar) {
        code.append(scalar)
        bareCode.append(bare)
    }
}
#endif
