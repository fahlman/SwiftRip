//
//  DVDServiceFakes.swift
//  SwiftRipTests
//

import Foundation
@testable import SwiftRip

extension RipTestSupport {
    struct StubDVDVolumeFinder: DVDVolumeFinding {
        let volumes: [DVDVolume]

        func findMountedDVDs() -> [DVDVolume] {
            volumes
        }
    }

    @MainActor
    final class RecordingDVDInputAccessProvider: DVDInputAccessProviding {
        private(set) var startedURLs: [URL] = []
        private(set) var accesses: [RecordingDVDInputAccess] = []

        func startAccessingDVD(at url: URL) -> any DVDInputAccess {
            let access = RecordingDVDInputAccess(url: url)
            startedURLs.append(url)
            accesses.append(access)
            return access
        }
    }

    @MainActor
    final class RecordingDVDInputAccess: DVDInputAccess {
        let url: URL
        private(set) var isAccessing = true
        private(set) var stopCount = 0

        init(url: URL) {
            self.url = url
        }

        func stopAccessing() {
            stopCount += 1
            isAccessing = false
        }
    }

    @MainActor
    final class NoOpDVDInputAccessProvider: DVDInputAccessProviding {
        func startAccessingDVD(at url: URL) -> any DVDInputAccess {
            NoOpDVDInputAccess(url: url)
        }
    }

    @MainActor
    final class NoOpDVDInputAccess: DVDInputAccess {
        let url: URL
        private(set) var isAccessing = true

        init(url: URL) {
            self.url = url
        }

        func stopAccessing() {
            isAccessing = false
        }
    }

    struct NoOpDVDDeviceEjector: DVDDeviceEjecting {
        func ejectDVD(at url: URL) throws {}
    }

    struct ThrowingDVDDeviceEjector: DVDDeviceEjecting {
        let errorDescription: String

        func ejectDVD(at url: URL) throws {
            throw NSError(
                domain: "SwiftRipTests.ThrowingDVDDeviceEjector",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: errorDescription]
            )
        }
    }

    @MainActor
    final class RecordingDVDDeviceEjector: DVDDeviceEjecting {
        private(set) var ejectedURLs: [URL] = []

        func ejectDVD(at url: URL) throws {
            ejectedURLs.append(url)
        }
    }
}
