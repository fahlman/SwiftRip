//
//  RipEngine.swift
//  SwiftRip
//

import Foundation

struct RipRequest: Sendable {
    let input: DVDVolume
    let outputURL: URL
    let logDirectoryURL: URL
}

struct RipPlan: Sendable {
    let request: RipRequest
    let session: RipSession
    let arguments: [String]
}

enum RipResult: Sendable {
    case completed(exitCode: Int32)
    case failed(exitCode: Int32)
    case outputValidationFailed(exitCode: Int32, message: String)
    case canceled(exitCode: Int32)
    case preflightFailed(message: String)
}

enum RipToolOutputChannel: Equatable, Sendable {
    case standardOutput
    case standardError
}

struct RipToolOutput: Sendable {
    let channel: RipToolOutputChannel
    let text: String
}

enum RipEngineEvent: Sendable {
    case sessionPrepared(RipPlan)
    case preflightFailed(message: String)
    case encodingStarted(DVDVolume)
    case toolOutput(RipToolOutput)
    case progressUpdated(Double)
    case finished(RipResult)
}

struct RipEngine: Sendable {
    let configuration: RipConfiguration
    let fileManager: FileManager
    let handBrakeRunner: HandBrakeRunning

    func events(for request: RipRequest) -> AsyncStream<RipEngineEvent> {
        AsyncStream { continuation in
            let task = Task {
                let plan = makePlan(for: request)
                continuation.yield(.sessionPrepared(plan))

                if let preflightFailure = RipPreflightCheck(
                    configuration: configuration,
                    fileManager: fileManager
                ).failureMessage(outputURL: request.outputURL) {
                    continuation.yield(.preflightFailed(message: preflightFailure))
                    continuation.yield(.finished(.preflightFailed(message: preflightFailure)))
                    continuation.finish()
                    return
                }

                continuation.yield(.encodingStarted(request.input))

                var exitCode: Int32 = -1
                for await event in handBrakeRunner.events(
                    executablePath: configuration.handBrakeCLIPath,
                    arguments: plan.arguments
                ) {
                    if Task.isCancelled {
                        break
                    }

                    switch event {
                    case .output(let output):
                        let toolOutput = RipToolOutput(handBrakeOutput: output)
                        continuation.yield(.toolOutput(toolOutput))
                        if let progress = HandBrakeProgressParser.progressValue(from: output.text) {
                            continuation.yield(.progressUpdated(progress))
                        }
                    case .terminated(let terminatedExitCode):
                        exitCode = terminatedExitCode
                    }
                }

                if Task.isCancelled {
                    continuation.yield(.finished(.canceled(exitCode: exitCode)))
                    continuation.finish()
                    return
                }

                continuation.yield(.finished(result(for: exitCode, outputURL: request.outputURL)))
                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func makePlan(for request: RipRequest) -> RipPlan {
        let arguments = configuration.handBrakeArguments(input: request.input, outputURL: request.outputURL)
        let session = RipSession(
            input: request.input,
            outputURL: request.outputURL,
            arguments: arguments,
            logDirectoryURL: request.logDirectoryURL,
            executablePath: configuration.handBrakeCLIPath,
            libdvdcssPath: configuration.libdvdcssPath,
            presetURL: configuration.presetURL
        )

        return RipPlan(request: request, session: session, arguments: arguments)
    }

    private func result(for exitCode: Int32, outputURL: URL) -> RipResult {
        guard exitCode == 0 else {
            return .failed(exitCode: exitCode)
        }

        if let postflightFailure = RipPostflightCheck(fileManager: fileManager)
            .failureMessage(outputURL: outputURL) {
            return .outputValidationFailed(exitCode: exitCode, message: postflightFailure)
        }

        return .completed(exitCode: exitCode)
    }
}

private extension RipToolOutput {
    init(handBrakeOutput: HandBrakeOutput) {
        self.channel = RipToolOutputChannel(handBrakeOutput.channel)
        self.text = handBrakeOutput.text
    }
}

private extension RipToolOutputChannel {
    init(_ handBrakeOutputChannel: HandBrakeOutputChannel) {
        switch handBrakeOutputChannel {
        case .standardOutput:
            self = .standardOutput
        case .standardError:
            self = .standardError
        }
    }
}
