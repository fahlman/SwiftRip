//
//  HandBrakeProgressParser.swift
//  SwiftRip
//

import Foundation

struct HandBrakeProgressParser {
    private nonisolated static let progressRegex = try? NSRegularExpression(
        pattern: #"Encoding:\s+task\s+\d+\s+of\s+\d+,\s+([0-9]+(?:\.[0-9]+)?)\s*%"#
    )

    nonisolated static func progressValue(from text: String) -> Double? {
        guard let progressRegex else { return nil }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = progressRegex.matches(in: text, range: range).last,
              let percentRange = Range(match.range(at: 1), in: text),
              let percent = Double(text[percentRange]) else {
            return nil
        }

        return min(max(percent / 100, 0), 1)
    }
}
