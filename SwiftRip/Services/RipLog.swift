//
//  RipLog.swift
//  SwiftRip
//

import Foundation

struct RipLog: Sendable {
    private static let fallbackDVDName = "DVD"
    private static let timestampFormat = "yyyy-MM-dd-HHmmss"

    let url: URL
    let directoryURL: URL
    let startedAt: Date
    private(set) var text: String

    init(
        input: DVDVolume,
        outputURL: URL,
        arguments: [String],
        executablePath: String,
        libdvdcssPath: String,
        presetURL: URL,
        url: URL,
        directoryURL: URL,
        startedAt: Date = Date()
    ) {
        self.url = url
        self.directoryURL = directoryURL
        self.startedAt = startedAt
        self.text = Self.header(
            input: input,
            outputURL: outputURL,
            arguments: arguments,
            executablePath: executablePath,
            libdvdcssPath: libdvdcssPath,
            presetURL: presetURL,
            startedAt: startedAt
        )
    }

    static func makeFileURL(for dvd: DVDVolume, in directoryURL: URL) -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = timestampFormat

        let safeName = dvd.name
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")

        let fileName = "\(safeName.isEmpty ? fallbackDVDName : safeName)-\(formatter.string(from: Date())).log"
        return directoryURL.appendingPathComponent(fileName)
    }

    @discardableResult
    mutating func append(_ output: String) -> String {
        text += output
        return output
    }

    @discardableResult
    mutating func appendLine(_ line: String) -> String {
        append("\(line)\n")
    }

    @discardableResult
    mutating func appendBlankLine(_ line: String) -> String {
        append("\n\(line)\n")
    }

    @discardableResult
    mutating func appendExitCode(_ exitCode: Int32) -> String {
        appendBlankLine("Exit code: \(exitCode)")
    }

    @discardableResult
    mutating func appendOutcome(_ outcome: String, finishedAt: Date = Date()) -> String {
        let output = """
        Outcome: \(outcome)
        Finished: \(Self.displayFormatter.string(from: finishedAt))
        Elapsed: \(Self.elapsedText(from: startedAt, to: finishedAt))
        """
            + "\n"
        return append(output)
    }

    func save(using fileManager: FileManager) -> Error? {
        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            try text.write(to: url, atomically: true, encoding: .utf8)
            return nil
        } catch {
            return error
        }
    }

    private static var displayFormatter: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }

    private static func elapsedText(from startDate: Date, to endDate: Date) -> String {
        String(format: "%.2f seconds", max(endDate.timeIntervalSince(startDate), 0))
    }

    private static func header(
        input: DVDVolume,
        outputURL: URL,
        arguments: [String],
        executablePath: String,
        libdvdcssPath: String,
        presetURL: URL,
        startedAt: Date
    ) -> String {
        """
        \(RipConfiguration.appName) Log
        App: \(RipConfiguration.appName) \(appVersionText)
        Started: \(displayFormatter.string(from: startedAt))
        DVD: \(input.name)
        Input: \(input.path)
        Output: \(outputURL.path)
        HandBrakeCLI: \(executablePath)
        libdvdcss: \(libdvdcssPath)
        Preset: \(presetURL.path)
        Command: \(executablePath) \(arguments.joined(separator: " "))

        """
    }

    private static var appVersionText: String {
        let infoDictionary = Bundle.main.infoDictionary
        let version = infoDictionary?["CFBundleShortVersionString"] as? String
        let build = infoDictionary?["CFBundleVersion"] as? String

        switch (version, build) {
        case let (.some(version), .some(build)):
            return "\(version) (\(build))"
        case let (.some(version), .none):
            return version
        case let (.none, .some(build)):
            return "build \(build)"
        case (.none, .none):
            return "version unknown"
        }
    }
}
