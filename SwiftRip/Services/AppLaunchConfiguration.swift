//
//  AppLaunchConfiguration.swift
//  SwiftRip
//

import Foundation

enum AppLaunchConfiguration {
    nonisolated static func value(
        for key: String,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> String? {
        if let environmentValue = environment[key] {
            return environmentValue
        }

        for argumentPrefix in ["--\(key)=", "-\(key)=", "\(key)="] {
            if let argument = arguments.first(where: { $0.hasPrefix(argumentPrefix) }) {
                return String(argument.dropFirst(argumentPrefix.count))
            }
        }

        for argumentName in ["--\(key)", "-\(key)", key] {
            guard let argumentIndex = arguments.firstIndex(of: argumentName) else {
                continue
            }

            let valueIndex = arguments.index(after: argumentIndex)
            guard arguments.indices.contains(valueIndex) else {
                return "1"
            }

            return arguments[valueIndex]
        }

        return nil
    }

    nonisolated static func isEnabled(
        _ key: String,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> Bool {
        value(for: key, environment: environment, arguments: arguments) == "1"
    }

    nonisolated static func isRunningUnderXCTest(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        arguments: [String] = ProcessInfo.processInfo.arguments,
        bundlePaths: [String] = Bundle.allBundles.map(\.bundlePath)
    ) -> Bool {
        environment.keys.contains(where: isXCTestEnvironmentKey)
            || arguments.contains(where: isXCTestArgument)
            || bundlePaths.contains(where: isXCTestBundlePath)
    }

    private nonisolated static func isXCTestEnvironmentKey(_ key: String) -> Bool {
        ["XCTest", "XCInjectBundle"].contains { key.hasPrefix($0) }
    }

    private nonisolated static func isXCTestArgument(_ argument: String) -> Bool {
        argument.hasPrefix("-XCTest") || argument.contains(".xctest")
    }

    private nonisolated static func isXCTestBundlePath(_ path: String) -> Bool {
        path.hasSuffix(".xctest") || path.contains("/XCTest.framework")
    }
}
