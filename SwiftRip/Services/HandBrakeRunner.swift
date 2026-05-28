//
//  HandBrakeRunner.swift
//  SwiftRip
//

import Foundation

struct HandBrakeResult: Sendable {
    let exitCode: Int32
}

enum HandBrakeOutputChannel: Equatable, Sendable {
    case standardOutput
    case standardError
}

struct HandBrakeOutput: Sendable {
    let channel: HandBrakeOutputChannel
    let text: String
}

enum HandBrakeEvent: Sendable {
    case output(HandBrakeOutput)
    case terminated(exitCode: Int32)
}

protocol HandBrakeRunning: Sendable {
    nonisolated func events(
        executablePath: String,
        arguments: [String]
    ) -> AsyncStream<HandBrakeEvent>
}

extension HandBrakeRunning {
    nonisolated func run(executablePath: String, arguments: [String]) async -> HandBrakeResult {
        var exitCode: Int32 = -1

        for await event in events(executablePath: executablePath, arguments: arguments) {
            if case let .terminated(code) = event {
                exitCode = code
            }
        }

        return HandBrakeResult(exitCode: exitCode)
    }
}

struct ProcessHandBrakeRunner: HandBrakeRunning {
    private nonisolated static let lineFeed: UInt8 = 10
    private nonisolated static let carriageReturn: UInt8 = 13
    private nonisolated static let outputBufferLimit = 4_096

    private struct OutputPipes {
        let standardOutput: Pipe
        let standardError: Pipe
    }

    nonisolated func events(
        executablePath: String,
        arguments: [String]
    ) -> AsyncStream<HandBrakeEvent> {
        let executableURL = URL(fileURLWithPath: executablePath)
        let macOSDirectoryURL = executableURL.deletingLastPathComponent()
        let process = makeProcess(
            executableURL: executableURL,
            arguments: arguments,
            currentDirectoryURL: macOSDirectoryURL
        )
        let outputPipes = makeOutputPipes(for: process)

        return run(process, outputPipes: outputPipes)
    }

    private nonisolated func makeProcess(
        executableURL: URL,
        arguments: [String],
        currentDirectoryURL: URL
    ) -> Process {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectoryURL
        return process
    }

    private nonisolated func makeOutputPipes(for process: Process) -> OutputPipes {
        let standardOutput = Pipe()
        let standardError = Pipe()
        process.standardOutput = standardOutput
        process.standardError = standardError
        return OutputPipes(standardOutput: standardOutput, standardError: standardError)
    }

    private nonisolated func run(
        _ process: Process,
        outputPipes: OutputPipes
    ) -> AsyncStream<HandBrakeEvent> {
        AsyncStream { continuation in
            let task = Task {
                await withTaskCancellationHandler {
                    var outputTasks: [Task<Void, Never>] = []
                    let result = await launchAndWaitForTermination(
                        process,
                        outputPipes: outputPipes,
                        outputTasks: &outputTasks,
                        eventContinuation: continuation
                    )
                    for outputTask in outputTasks {
                        await outputTask.value
                    }
                    continuation.yield(.terminated(exitCode: result.exitCode))
                    continuation.finish()
                } onCancel: {
                    if process.isRunning {
                        process.terminate()
                    }
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private nonisolated func launchAndWaitForTermination(
        _ process: Process,
        outputPipes: OutputPipes,
        outputTasks: inout [Task<Void, Never>],
        eventContinuation: AsyncStream<HandBrakeEvent>.Continuation
    ) async -> HandBrakeResult {
        await withCheckedContinuation { processContinuation in
            process.terminationHandler = { terminatedProcess in
                processContinuation.resume(returning: HandBrakeResult(exitCode: terminatedProcess.terminationStatus))
            }

            do {
                try process.run()
                outputTasks = [
                    Task {
                        await Self.forwardOutput(
                            from: outputPipes.standardOutput.fileHandleForReading,
                            channel: .standardOutput,
                            continuation: eventContinuation
                        )
                    },
                    Task {
                        await Self.forwardOutput(
                            from: outputPipes.standardError.fileHandleForReading,
                            channel: .standardError,
                            continuation: eventContinuation
                        )
                    }
                ]
            } catch {
                process.terminationHandler = nil
                eventContinuation.yield(.output(HandBrakeOutput(
                    channel: .standardError,
                    text: "\(AppStrings.handBrakeLaunchFailed(error.localizedDescription))\n"
                )))
                processContinuation.resume(returning: HandBrakeResult(exitCode: -1))
            }
        }
    }

    private nonisolated static func forwardOutput(
        from outputHandle: FileHandle,
        channel: HandBrakeOutputChannel,
        continuation: AsyncStream<HandBrakeEvent>.Continuation
    ) async {
        var buffer = Data()

        do {
            for try await byte in outputHandle.bytes {
                buffer.append(byte)

                if byte == Self.lineFeed || byte == Self.carriageReturn || buffer.count >= Self.outputBufferLimit {
                    flushOutputBuffer(&buffer, channel: channel, continuation: continuation)
                }
            }
        } catch {
            continuation.yield(.output(HandBrakeOutput(
                channel: .standardError,
                text: "\(AppStrings.handBrakeOutputReadFailed(error.localizedDescription))\n"
            )))
        }

        flushOutputBuffer(&buffer, channel: channel, continuation: continuation)
    }

    private nonisolated static func flushOutputBuffer(
        _ buffer: inout Data,
        channel: HandBrakeOutputChannel,
        continuation: AsyncStream<HandBrakeEvent>.Continuation
    ) {
        guard !buffer.isEmpty else { return }

        let text = String(decoding: buffer, as: UTF8.self)
        continuation.yield(.output(HandBrakeOutput(channel: channel, text: text)))
        buffer.removeAll(keepingCapacity: true)
    }
}
