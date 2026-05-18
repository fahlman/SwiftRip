//
//  HandBrakeRunner.swift
//  SwiftRip
//
//  Created by Ryan Fahlsing on 5/16/26.
//

import Foundation

struct HandBrakeResult: Sendable {
    let exitCode: Int32
}

protocol HandBrakeRunning: Sendable {
    func run(
        executablePath: String,
        arguments: [String],
        onOutput: @escaping @MainActor @Sendable (String) -> Void
    ) async -> HandBrakeResult
}

struct ProcessHandBrakeRunner: HandBrakeRunning {
    func run(
        executablePath: String,
        arguments: [String],
        onOutput: @escaping @MainActor @Sendable (String) -> Void
    ) async -> HandBrakeResult {
        let executableURL = URL(fileURLWithPath: executablePath)
        let macOSDirectoryURL = executableURL.deletingLastPathComponent()
        let frameworksDirectoryURL = frameworksDirectoryURL(for: macOSDirectoryURL)
        let process = makeProcess(
            executableURL: executableURL,
            arguments: arguments,
            currentDirectoryURL: macOSDirectoryURL,
            frameworksDirectoryURL: frameworksDirectoryURL
        )
        let pipe = makeOutputPipe(for: process, onOutput: onOutput)
        return await run(process, outputPipe: pipe, onOutput: onOutput)
    }

    private func frameworksDirectoryURL(for macOSDirectoryURL: URL) -> URL {
        macOSDirectoryURL
            .deletingLastPathComponent()
            .appendingPathComponent("Frameworks", isDirectory: true)
    }

    private func makeProcess(
        executableURL: URL,
        arguments: [String],
        currentDirectoryURL: URL,
        frameworksDirectoryURL: URL
    ) -> Process {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectoryURL
        process.environment = makeEnvironment(
            macOSDirectoryURL: currentDirectoryURL,
            frameworksDirectoryURL: frameworksDirectoryURL
        )
        return process
    }

    private func makeEnvironment(macOSDirectoryURL: URL, frameworksDirectoryURL: URL) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let bundledLibraryPaths = [
            macOSDirectoryURL.path,
            frameworksDirectoryURL.path
        ].joined(separator: ":")

        environment["DYLD_LIBRARY_PATH"] = bundledLibraryPaths
        environment["DYLD_FALLBACK_LIBRARY_PATH"] = bundledLibraryPaths
        environment["LD_LIBRARY_PATH"] = bundledLibraryPaths
        return environment
    }

    private func makeOutputPipe(
        for process: Process,
        onOutput: @escaping @MainActor @Sendable (String) -> Void
    ) -> Pipe {
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }

            Task { @MainActor in
                onOutput(text)
            }
        }

        return pipe
    }

    private func run(
        _ process: Process,
        outputPipe: Pipe,
        onOutput: @escaping @MainActor @Sendable (String) -> Void
    ) async -> HandBrakeResult {
        let outputHandle = outputPipe.fileHandleForReading

        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                process.terminationHandler = { terminatedProcess in
                    outputHandle.readabilityHandler = nil
                    continuation.resume(returning: HandBrakeResult(exitCode: terminatedProcess.terminationStatus))
                }

                do {
                    try process.run()
                } catch {
                    outputHandle.readabilityHandler = nil

                    Task { @MainActor in
                        onOutput("Failed to launch HandBrakeCLI: \(error.localizedDescription)\n")
                    }

                    continuation.resume(returning: HandBrakeResult(exitCode: -1))
                }
            }
        } onCancel: {
            if process.isRunning {
                process.terminate()
            }
        }
    }
}
