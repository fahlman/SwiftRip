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
