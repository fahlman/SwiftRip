//
//  ProcessHandBrakeRunnerTests.swift
//  SwiftRipTests
//
//  Created by Ryan Fahlsing on 5/16/26.
//

import Testing
@testable import SwiftRip

@MainActor
struct ProcessHandBrakeRunnerTests {

    @Test func forwardsStandardOutputAndStandardError() async {
        let runner = ProcessHandBrakeRunner()
        var output = ""

        let result = await runner.run(
            executablePath: "/bin/sh",
            arguments: ["-c", "echo standard-output; echo standard-error >&2"],
            onOutput: { text in
                output += text
            }
        )
        await RipTestSupport.waitUntil {
            output.contains("standard-output") && output.contains("standard-error")
        }

        #expect(result.exitCode == 0)
        #expect(output.contains("standard-output"))
        #expect(output.contains("standard-error"))
    }

    @Test func forwardsOutputWithoutTrailingNewline() async {
        let runner = ProcessHandBrakeRunner()
        var output = ""

        let result = await runner.run(
            executablePath: "/bin/sh",
            arguments: ["-c", "printf partial-output"],
            onOutput: { text in
                output += text
            }
        )

        #expect(result.exitCode == 0)
        #expect(output.contains("partial-output"))
    }

    @Test func launchFailureReturnsFailureAndReportsOutput() async {
        let runner = ProcessHandBrakeRunner()
        var output = ""

        let result = await runner.run(
            executablePath: "/missing/HandBrakeCLI",
            arguments: [],
            onOutput: { text in
                output += text
            }
        )

        #expect(result.exitCode == -1)
        #expect(output.contains("Failed to launch HandBrakeCLI"))
    }

    @Test func cancellationTerminatesRunningProcess() async {
        let runner = ProcessHandBrakeRunner()
        let task = Task {
            await runner.run(
                executablePath: "/bin/sh",
                arguments: ["-c", "trap 'exit 42' TERM; while true; do sleep 1; done"],
                onOutput: { _ in }
            )
        }

        try? await Task.sleep(for: .milliseconds(100))
        task.cancel()

        let result = await task.value
        #expect(result.exitCode != 0)
    }
}
