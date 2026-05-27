//
//  ProcessHandBrakeRunnerTests.swift
//  SwiftRipTests
//

import Testing
@testable import SwiftRip

@MainActor
struct ProcessHandBrakeRunnerTests {

    @Test func forwardsStandardOutputAndStandardError() async {
        let runner = ProcessHandBrakeRunner()

        let (result, outputs) = await collect(
            runner,
            executablePath: "/bin/sh",
            arguments: ["-c", "echo standard-output; echo standard-error >&2"]
        )

        #expect(result.exitCode == 0)
        #expect(outputs.contains { $0.channel == .standardOutput && $0.text.contains("standard-output") })
        #expect(outputs.contains { $0.channel == .standardError && $0.text.contains("standard-error") })
    }

    @Test func forwardsOutputWithoutTrailingNewline() async {
        let runner = ProcessHandBrakeRunner()

        let (result, outputs) = await collect(
            runner,
            executablePath: "/bin/sh",
            arguments: ["-c", "printf partial-output"]
        )

        #expect(result.exitCode == 0)
        #expect(outputs.map(\.text).joined().contains("partial-output"))
    }

    @Test func launchFailureReturnsFailureAndReportsOutput() async {
        let runner = ProcessHandBrakeRunner()

        let (result, outputs) = await collect(
            runner,
            executablePath: "/missing/HandBrakeCLI",
            arguments: []
        )

        #expect(result.exitCode == -1)
        #expect(outputs.contains { $0.channel == .standardError && $0.text.contains("Failed to launch HandBrakeCLI") })
    }

    @Test func cancellationTerminatesRunningProcess() async {
        let runner = ProcessHandBrakeRunner()
        let task = Task {
            await runner.run(
                executablePath: "/bin/sh",
                arguments: ["-c", "trap 'exit 42' TERM; while true; do sleep 1; done"]
            )
        }

        try? await Task.sleep(for: .milliseconds(100))
        task.cancel()

        let result = await task.value
        #expect(result.exitCode != 0)
    }

    private func collect(
        _ runner: ProcessHandBrakeRunner,
        executablePath: String,
        arguments: [String]
    ) async -> (HandBrakeResult, [HandBrakeOutput]) {
        var exitCode: Int32 = -1
        var outputs: [HandBrakeOutput] = []

        for await event in runner.events(executablePath: executablePath, arguments: arguments) {
            switch event {
            case .output(let output):
                outputs.append(output)
            case .terminated(let code):
                exitCode = code
            }
        }

        return (HandBrakeResult(exitCode: exitCode), outputs)
    }
}
