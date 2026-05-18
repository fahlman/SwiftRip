//
//  OutputFilenameFormatterTests.swift
//  SwiftRipTests
//

import Foundation
import Testing
@testable import SwiftRip

@MainActor
struct OutputFilenameFormatterTests {

    @Test func formatsSupportedNames() throws {
        let date = try #require(Calendar.current.date(from: DateComponents(
            calendar: .current,
            year: 2026,
            month: 5,
            day: 18,
            hour: 12
        )))
        let formatter = OutputFilenameFormatter(dateProvider: { date })

        #expect(formatter.outputName(for: "MY_MOVIE", format: .titleCase) == "My Movie.m4v")
        #expect(formatter.outputName(for: "MY_MOVIE", format: .originalName) == "MY_MOVIE.m4v")
        #expect(formatter.outputName(for: "MY_MOVIE", format: .datedTitleCase) == "My Movie - 2026-05-18.m4v")
    }
}
