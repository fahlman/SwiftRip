//
//  HandBrakeRunnerFakes.swift
//  SwiftRipTests
//

import Foundation
@testable import SwiftRip

extension RipTestSupport {
    struct StubHandBrakeRunner: HandBrakeRunning {
        let exitCode: Int32
        let outputURLToCreate: URL?

        nonisolated func events(
            executablePath: String,
            arguments: [String]
        ) -> AsyncStream<HandBrakeEvent> {
            AsyncStream { continuation in
                continuation.yield(.output(HandBrakeOutput(channel: .standardOutput, text: "Encoding: task 1 of 1, 100.00 %\n")))

                if let outputURLToCreate {
                    try? "partial-or-complete output".write(to: outputURLToCreate, atomically: true, encoding: .utf8)
                }

                continuation.yield(.terminated(exitCode: exitCode))
                continuation.finish()
            }
        }
    }

    final class WaitingHandBrakeRunner: HandBrakeRunning {
        nonisolated func events(
            executablePath: String,
            arguments: [String]
        ) -> AsyncStream<HandBrakeEvent> {
            AsyncStream { continuation in
                let task = Task {
                    continuation.yield(.output(HandBrakeOutput(channel: .standardOutput, text: "Encoding: task 1 of 1, 1.00 %\n")))
                    if let outputURL = Self.outputURL(from: arguments) {
                        try? "incomplete output".write(to: outputURL, atomically: true, encoding: .utf8)
                    }

                    for _ in 0..<100 {
                        if Task.isCancelled { break }
                        try? await Task.sleep(for: .milliseconds(10))
                    }

                    continuation.yield(.output(HandBrakeOutput(channel: .standardError, text: "Canceled.\n")))
                    continuation.yield(.terminated(exitCode: -15))
                    continuation.finish()
                }

                continuation.onTermination = { _ in
                    task.cancel()
                }
            }
        }

        private nonisolated static func outputURL(from arguments: [String]) -> URL? {
            guard let outputFlagIndex = arguments.firstIndex(of: "-o") else { return nil }
            let outputPathIndex = arguments.index(after: outputFlagIndex)
            guard arguments.indices.contains(outputPathIndex) else { return nil }

            return URL(fileURLWithPath: arguments[outputPathIndex])
        }
    }

    @MainActor
    final class RecordingHandBrakeRunner: HandBrakeRunning {
        private(set) var runCount = 0

        nonisolated func events(
            executablePath: String,
            arguments: [String]
        ) -> AsyncStream<HandBrakeEvent> {
            AsyncStream { continuation in
                Task { @MainActor in
                    runCount += 1
                    continuation.yield(.terminated(exitCode: 0))
                    continuation.finish()
                }
            }
        }
    }

    @MainActor
    final class CountingWaitingHandBrakeRunner: HandBrakeRunning {
        private(set) var runCount = 0

        nonisolated func events(
            executablePath: String,
            arguments: [String]
        ) -> AsyncStream<HandBrakeEvent> {
            AsyncStream { continuation in
                let task = Task { @MainActor in
                    runCount += 1
                    continuation.yield(.output(HandBrakeOutput(channel: .standardOutput, text: "Encoding: task 1 of 1, 1.00 %\n")))
                    if let outputURL = outputURL(from: arguments) {
                        try? "incomplete output".write(to: outputURL, atomically: true, encoding: .utf8)
                    }

                    for _ in 0..<100 {
                        if Task.isCancelled { break }
                        try? await Task.sleep(for: .milliseconds(10))
                    }

                    continuation.yield(.terminated(exitCode: -15))
                    continuation.finish()
                }

                continuation.onTermination = { _ in
                    task.cancel()
                }
            }
        }

        private func outputURL(from arguments: [String]) -> URL? {
            guard let outputFlagIndex = arguments.firstIndex(of: "-o") else { return nil }
            let outputPathIndex = arguments.index(after: outputFlagIndex)
            guard arguments.indices.contains(outputPathIndex) else { return nil }

            return URL(fileURLWithPath: arguments[outputPathIndex])
        }
    }

    @MainActor
    final class ArgumentOutputCreatingHandBrakeRunner: HandBrakeRunning {
        private(set) var outputURLs: [URL] = []

        nonisolated func events(
            executablePath: String,
            arguments: [String]
        ) -> AsyncStream<HandBrakeEvent> {
            AsyncStream { continuation in
                Task { @MainActor in
                    continuation.yield(.output(HandBrakeOutput(channel: .standardOutput, text: "Encoding: task 1 of 1, 100.00 %\n")))

                    guard let outputURL = outputURL(from: arguments) else {
                        continuation.yield(.terminated(exitCode: 2))
                        continuation.finish()
                        return
                    }

                    outputURLs.append(outputURL)
                    try? "complete output".write(to: outputURL, atomically: true, encoding: .utf8)
                    continuation.yield(.terminated(exitCode: 0))
                    continuation.finish()
                }
            }
        }

        private func outputURL(from arguments: [String]) -> URL? {
            guard let outputFlagIndex = arguments.firstIndex(of: "-o") else { return nil }
            let outputPathIndex = arguments.index(after: outputFlagIndex)
            guard arguments.indices.contains(outputPathIndex) else { return nil }

            return URL(fileURLWithPath: arguments[outputPathIndex])
        }
    }
}
