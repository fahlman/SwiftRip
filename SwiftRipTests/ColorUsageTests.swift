//
//  ColorUsageTests.swift
//  SwiftRipTests
//

import Foundation
import Testing

struct ColorUsageTests {

    @Test func appSourceDoesNotUseLiteralColors() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceRootURL = rootURL.appendingPathComponent("SwiftRip")
        let swiftURLs = try swiftSourceURLs(in: sourceRootURL)
        let prohibitedPatterns = try Self.prohibitedColorPatterns()
        var violations: [String] = []

        for url in swiftURLs {
            let source = try String(contentsOf: url, encoding: .utf8)

            for prohibitedPattern in prohibitedPatterns {
                violations.append(
                    contentsOf: prohibitedPattern.violations(
                        in: source,
                        filePath: url.path.replacingOccurrences(of: rootURL.path + "/", with: "")
                    )
                )
            }
        }

        #expect(
            violations.isEmpty,
            """
            Use semantic macOS colors instead of literal colors:
            \(violations.joined(separator: "\n"))
            """
        )
    }

    private static func prohibitedColorPatterns() throws -> [ProhibitedColorPattern] {
        [
            try ProhibitedColorPattern(
                pattern: #"\bColor\.(white|black|red|green|gray|blue|clear|orange|yellow|purple|pink|brown|cyan|mint|teal|indigo)\b"#
            ),
            try ProhibitedColorPattern(
                pattern: #"\bNSColor\.(white|black|red|green|gray|blue|orange|yellow|purple|brown|cyan|magenta)\b"#
            ),
            try ProhibitedColorPattern(pattern: #"\bColor\s*\(\s*(red|hue|white)\s*:"#),
            try ProhibitedColorPattern(pattern: #"\bNSColor\s*\(\s*(red|hue|white)\s*:"#),
            try ProhibitedColorPattern(pattern: #"#[0-9A-Fa-f]{3,8}"#),
            try ProhibitedColorPattern(pattern: #"\b(sRGB|displayP3)\b"#)
        ]
    }

    private func swiftSourceURLs(in rootURL: URL) throws -> [URL] {
        guard
            let enumerator = FileManager.default.enumerator(
                at: rootURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
        else {
            return []
        }

        return try enumerator.compactMap { item in
            guard let url = item as? URL, url.pathExtension == "swift" else { return nil }
            let resourceValues = try url.resourceValues(forKeys: [.isRegularFileKey])
            return resourceValues.isRegularFile == true ? url : nil
        }
    }
}

private struct ProhibitedColorPattern {
    let regularExpression: NSRegularExpression

    init(pattern: String) throws {
        regularExpression = try NSRegularExpression(pattern: pattern)
    }

    func violations(in source: String, filePath: String) -> [String] {
        let nsSource = source as NSString
        let lineRanges = source.lineRanges
        let range = NSRange(location: 0, length: nsSource.length)

        return regularExpression.matches(in: source, range: range).map { match in
            let lineNumber = lineRanges.firstIndex { NSLocationInRange(match.range.location, $0) }.map { $0 + 1 } ?? 1
            let snippet = nsSource.substring(with: match.range)
            return "\(filePath):\(lineNumber): \(snippet)"
        }
    }
}

private extension String {
    var lineRanges: [NSRange] {
        var ranges: [NSRange] = []
        let nsString = self as NSString
        var location = 0

        while location < nsString.length {
            let range = nsString.lineRange(for: NSRange(location: location, length: 0))
            ranges.append(range)
            location = NSMaxRange(range)
        }

        return ranges
    }
}
