//
//  OutputURLResolverTests.swift
//  SwiftRipTests
//

import Foundation
import Testing
@testable import SwiftRip

@MainActor
struct OutputURLResolverTests {

    @Test func normalizesExtensionToM4V() {
        let resolver = OutputURLResolver(fileManager: .default)

        #expect(resolver.normalizedMovieURL(for: URL(fileURLWithPath: "/tmp/Movie.mp4")).path == "/tmp/Movie.m4v")
        #expect(resolver.normalizedMovieURL(for: URL(fileURLWithPath: "/tmp/Movie.M4V")).path == "/tmp/Movie.M4V")
    }

    @Test func availableURLAvoidsExistingFiles() throws {
        let testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: testDirectory)
        }
        try FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: true)
        let existingOutputURL = testDirectory.appendingPathComponent("Movie.m4v")
        try "existing movie".write(to: existingOutputURL, atomically: true, encoding: .utf8)

        let resolver = OutputURLResolver(fileManager: .default)

        #expect(resolver.availableURL(for: existingOutputURL) == testDirectory.appendingPathComponent("Movie 2.m4v"))
    }
}
