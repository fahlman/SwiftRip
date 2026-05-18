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
    private static let lineFeed: UInt8 = 10
    private static let carriageReturn: UInt8 = 13
    private static let outputBufferLimit = 4_096

    private final class ProcessOutput {
        var task: Task<Void, Never> = Task {}

        func startReading(
            from outputHandle: FileHandle,
            onOutput: @escaping @MainActor @Sendable (String) -> Void
        ) {
            task = Task {
                await ProcessHandBrakeRunner.forwardOutput(from: outputHandle, onOutput: onOutput)
            }
        }
    }

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
        let pipe = makeOutputPipe(for: process)
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

    private func makeOutputPipe(for process: Process) -> Pipe {
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        return pipe
    }

    private func run(
        _ process: Process,
        outputPipe: Pipe,
        onOutput: @escaping @MainActor @Sendable (String) -> Void
    ) async -> HandBrakeResult {
        return await withTaskCancellationHandler {
            let output = ProcessOutput()
            let result = await launchAndWaitForTermination(
                process,
                outputPipe: outputPipe,
                output: output,
                onOutput: onOutput
            )
            let outputTask = output.task
            await outputTask.value
            return result
        } onCancel: {
            if process.isRunning {
                process.terminate()
            }
        }
    }

    private func launchAndWaitForTermination(
        _ process: Process,
        outputPipe: Pipe,
        output: ProcessOutput,
        onOutput: @escaping @MainActor @Sendable (String) -> Void
    ) async -> HandBrakeResult {
        await withCheckedContinuation { continuation in
            process.terminationHandler = { terminatedProcess in
                continuation.resume(returning: HandBrakeResult(exitCode: terminatedProcess.terminationStatus))
            }

            do {
                try process.run()
                output.startReading(from: outputPipe.fileHandleForReading, onOutput: onOutput)
            } catch {
                process.terminationHandler = nil
                onOutput("Failed to launch HandBrakeCLI: \(error.localizedDescription)\n")
                continuation.resume(returning: HandBrakeResult(exitCode: -1))
            }
        }
    }

    private static func forwardOutput(
        from outputHandle: FileHandle,
        onOutput: @escaping @MainActor @Sendable (String) -> Void
    ) async {
        var buffer = Data()

        do {
            for try await byte in outputHandle.bytes {
                buffer.append(byte)

                if byte == Self.lineFeed || byte == Self.carriageReturn || buffer.count >= Self.outputBufferLimit {
                    await flushOutputBuffer(&buffer, onOutput: onOutput)
                }
            }
        } catch {
            onOutput("Could not read HandBrakeCLI output: \(error.localizedDescription)\n")
        }

        await flushOutputBuffer(&buffer, onOutput: onOutput)
    }

    private static func flushOutputBuffer(
        _ buffer: inout Data,
        onOutput: @escaping @MainActor @Sendable (String) -> Void
    ) async {
        guard !buffer.isEmpty else { return }

        if let text = String(data: buffer, encoding: .utf8) {
            onOutput(text)
        }

        buffer.removeAll(keepingCapacity: true)
    }
}
