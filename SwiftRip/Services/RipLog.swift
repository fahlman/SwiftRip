//
//  RipLog.swift
//  SwiftRip
//
//  Created by Ryan Fahlsing on 5/16/26.
//

import Foundation

struct RipLog {
    private static let fallbackDVDName = "DVD"
    private static let timestampFormat = "yyyy-MM-dd-HHmmss"

    let url: URL
    let directoryURL: URL
    private(set) var text: String

    init(
        input: DVDVolume,
        outputURL: URL,
        arguments: [String],
        executablePath: String,
        url: URL,
        directoryURL: URL
    ) {
        self.url = url
        self.directoryURL = directoryURL
        self.text = Self.header(
            input: input,
            outputURL: outputURL,
            arguments: arguments,
            executablePath: executablePath
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

    mutating func append(_ output: String) {
        text += output
    }

    mutating func appendLine(_ line: String) {
        text += "\(line)\n"
    }

    mutating func appendBlankLine(_ line: String) {
        text += "\n\(line)\n"
    }

    mutating func appendExitCode(_ exitCode: Int32) {
        appendBlankLine("Exit code: \(exitCode)")
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

    private static func header(
        input: DVDVolume,
        outputURL: URL,
        arguments: [String],
        executablePath: String
    ) -> String {
        """
        \(RipConfiguration.appName) Log
        DVD: \(input.name)
        Input: \(input.path)
        Output: \(outputURL.path)
        Command: \(executablePath) \(arguments.joined(separator: " "))

        """
    }
}
