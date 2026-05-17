//
//  HandBrakeRunner.swift
//  SwiftRip
//
//  Created by Ryan Fahlsing on 5/16/26.
//

import Foundation

struct HandBrakeResult {
    let exitCode: Int32
}

protocol HandBrakeRunning {
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
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        let executableURL = URL(fileURLWithPath: executablePath)
        let macOSDirectoryURL = executableURL.deletingLastPathComponent()
        let frameworksDirectoryURL = macOSDirectoryURL
            .deletingLastPathComponent()
            .appendingPathComponent("Frameworks", isDirectory: true)

        process.currentDirectoryURL = macOSDirectoryURL

        var environment = ProcessInfo.processInfo.environment
        let bundledLibraryPaths = [
            macOSDirectoryURL.path,
            frameworksDirectoryURL.path
        ].joined(separator: ":")

        environment["DYLD_LIBRARY_PATH"] = bundledLibraryPaths
        environment["DYLD_FALLBACK_LIBRARY_PATH"] = bundledLibraryPaths
        environment["LD_LIBRARY_PATH"] = bundledLibraryPaths
        process.environment = environment

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        let outputHandle = pipe.fileHandleForReading
        outputHandle.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }

            Task { @MainActor in
                onOutput(text)
            }
        }

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

extension ProcessHandBrakeRunner {
    func run(dvd: DVDVolume, outputURL: URL, presetURL: URL, onOutput: @escaping @MainActor @Sendable (String) -> Void) async -> HandBrakeResult {
        let args = [
            "--preset-import-file", presetURL.path,
            "-Z", "SwiftRip",
            "-i", dvd.path,
            "-t", "1",
            "-o", outputURL.path
        ]
        guard let executablePath = Bundle.main.url(forAuxiliaryExecutable: "HandBrakeCLI")?.path else {
            await MainActor.run {
                onOutput("HandBrakeCLI was not found in the app bundle.\n")
            }
            return HandBrakeResult(exitCode: -1)
        }

        return await run(executablePath: executablePath, arguments: args, onOutput: onOutput)
    }
}
