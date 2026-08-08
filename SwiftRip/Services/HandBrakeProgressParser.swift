//
//  HandBrakeProgressParser.swift
//  SwiftRip
//

import Foundation

nonisolated struct HandBrakeProgressUpdate: Equatable, Sendable {
    let value: Double
    let remainingTime: TimeInterval?
}

struct HandBrakeProgressParser {
    private nonisolated static let progressRegex = try? NSRegularExpression(
        pattern: #"Encoding:\s+task\s+\d+\s+of\s+\d+,\s+([0-9]+(?:\.[0-9]+)?)\s*%(?:[^\n\r]*?ETA\s+(\d+)h(\d+)m(\d+)s)?"#
    )

    nonisolated static func progressValue(from text: String) -> Double? {
        progressUpdate(from: text)?.value
    }

    nonisolated static func progressUpdate(from text: String) -> HandBrakeProgressUpdate? {
        guard let progressRegex else { return nil }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = progressRegex.matches(in: text, range: range).last,
              let percentRange = Range(match.range(at: 1), in: text),
              let percent = Double(text[percentRange]) else {
            return nil
        }

        return HandBrakeProgressUpdate(
            value: min(max(percent / 100, 0), 1),
            remainingTime: remainingTime(from: match, in: text)
        )
    }

    private nonisolated static func remainingTime(from match: NSTextCheckingResult, in text: String) -> TimeInterval? {
        guard let hours = matchedInteger(at: 2, in: text, match: match),
              let minutes = matchedInteger(at: 3, in: text, match: match),
              let seconds = matchedInteger(at: 4, in: text, match: match) else {
            return nil
        }

        return TimeInterval((hours * 60 * 60) + (minutes * 60) + seconds)
    }

    private nonisolated static func matchedInteger(
        at index: Int,
        in text: String,
        match: NSTextCheckingResult
    ) -> Int? {
        let range = match.range(at: index)
        guard range.location != NSNotFound, let stringRange = Range(range, in: text) else { return nil }

        return Int(text[stringRange])
    }
}
