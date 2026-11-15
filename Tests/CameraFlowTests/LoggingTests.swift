//
//  LoggingTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(macOS)
import Foundation
import Testing

@Suite("Logging: what a release build shows")
struct LoggingTests {
    /// A call of a logger at a level, capturing the level.
    private static var callPattern: Regex<(Substring, Substring)> {
        #/[lL]ogger\s*\.(\w+)\(/#
    }

    /// An interpolation of a log message, capturing what is inside its parentheses.
    private static var interpolationPattern: Regex<(Substring, Substring)> {
        #/\\\(((?:[^()]|\([^()]*\))*)\)/#
    }

    /// The levels the package logs at. Anything else, `notice` and `fault` among them, needs a reason to come back.
    private static let allowedLevels: [String: Set<String>] = [
        "debug": [],
        "info": [],
        "error": [],
        "notice": ["State/PhotoCameraModel.swift"]
    ]

    /// One log call: its level and its message as the source has it.
    private struct Call {
        let path: String
        let line: Int
        let level: String
        let text: String
    }

    private let calls: [Call]

    init() throws {
        calls = try SourceTree.checkout().files.flatMap(Self.calls)
    }

    /// The log calls of a file, each with its text from the call to the parenthesis that closes it, over as many
    /// lines as it takes.
    private static func calls(in file: SourceTree.File) -> [Call] {
        let lines = file.code
        let pattern = callPattern
        return lines.indices.compactMap { index -> Call? in
            guard let match = lines[index].firstMatch(of: pattern), match.1 != "camera" else { return nil }
            let line = lines[index]
            let opening = line.unicodeScalars.distance(from: line.startIndex, to: match.range.upperBound)
            let lastLine = closingLine(of: file, from: index, after: opening)
            let text = lines[index...lastLine].joined(separator: "\n")
            return Call(path: file.path, line: index + 1, level: String(match.1), text: text)
        }
    }

    /// The index of the line with the parenthesis that closes the one opened before `offset` of the line at `index`,
    /// the last line for one never closed. The parentheses are counted in the code outside the texts of the
    /// literals, where an interpolation keeps its opening and loses its closing one, so its opening one is skipped.
    private static func closingLine(of file: SourceTree.File, from index: Int, after offset: Int) -> Int {
        var depth = 1
        var start = offset
        for lineIndex in index..<file.bareCode.endIndex {
            let scalars = Array(file.bareCode[lineIndex].unicodeScalars)
            for position in scalars.indices.dropFirst(start) {
                if scalars[position] == "(", isInterpolation(scalars, opening: position) == false {
                    depth += 1
                } else if scalars[position] == ")" {
                    depth -= 1
                }
                if depth == 0 {
                    return lineIndex
                }
            }
            start = 0
        }
        return file.bareCode.endIndex - 1
    }

    /// Whether the parenthesis opens an interpolation: a backslash before it, and the hashes of a raw string between.
    private static func isInterpolation(_ scalars: [Unicode.Scalar], opening position: Int) -> Bool {
        let before = scalars[..<position].reversed().drop { $0 == "#" }
        return before.first == "\\"
    }

    @Test("The sources log, so the rules below check something")
    func findsCalls() {
        #expect(calls.count > 20)
        #expect(calls.contains { $0.level == "error" })
    }

    /// The interpolations of a call that state no privacy.
    private static func valuesWithoutPrivacy(in call: Call) -> [String] {
        call.text.matches(of: interpolationPattern).map { String($0.1) }.filter { $0.contains("privacy:") == false }
    }

    @Test("A call over several lines is read to the parenthesis that closes it, every value of its message with it")
    func callOverSeveralLines() throws {
        let text = #"""
            func report(name: String, count: Int) {
                Self.logger.error(
                    """
                    The first value \(name, privacy: .public) and \(String(describing: name), privacy: .private), \
                    the second value \(count)
                    """
                )
                Self.logger.info("After it \(count, privacy: .public)")
            }
            """#
        let calls = Self.calls(in: SourceTree.File(path: "Sample.swift", text: text))
        try #require(calls.count == 2)
        #expect(calls[0].line == 2)
        #expect(calls[0].text.hasSuffix(")"))
        let values = calls[0].text.matches(of: Self.interpolationPattern).map { String($0.1) }
        #expect(values == ["name, privacy: .public", "String(describing: name), privacy: .private", "count"])
        #expect(Self.valuesWithoutPrivacy(in: calls[0]) == ["count"])
        let secondCall = calls[1].text.trimmingCharacters(in: .whitespaces)
        #expect(secondCall == #"Self.logger.info("After it \(count, privacy: .public)")"#)
        #expect(Self.valuesWithoutPrivacy(in: calls[1]).isEmpty)
    }

    @Test("Every value in a log message states its privacy, so an error is not hidden in a release build")
    func privacy() {
        let pattern = Self.interpolationPattern
        for call in calls {
            for interpolation in call.text.matches(of: pattern) {
                let isStated = interpolation.1.contains("privacy:")
                #expect(isStated, "\(call.path):\(call.line) logs \(interpolation.0) without its privacy")
            }
        }
    }

    @Test("The package logs errors as errors and the rest below `notice`, which is kept for a camera restart")
    func levels() {
        for call in calls {
            let files = Self.allowedLevels[call.level]
            let isAllowed = files.map { $0.isEmpty || $0.contains(call.path) } ?? false
            #expect(isAllowed, "\(call.path):\(call.line) logs at `\(call.level)`")
        }
    }
}
#endif
