//
//  RipViewModel.swift
//  SwiftRip
//
//  Created by Ryan Fahlsing on 5/16/26.
//

import Combine
import Foundation

@MainActor
final class RipViewModel: ObservableObject {
    static let initialStatusMessage = "Choose a DVD and output file to begin."

    @Published var dvdVolumes: [DVDVolume] = []
    @Published var selectedDVD: DVDVolume?
    @Published var outputURL: URL?
    @Published var statusMessage = RipViewModel.initialStatusMessage
    @Published private(set) var logFileURL: URL?
    @Published var isEncoding = false
    @Published private(set) var progress: Double = 0

    private var logText = ""
    private let configuration: RipConfiguration
    private let fileManager: FileManager
    private let handBrakeRunner: HandBrakeRunning
    private let volumeFinder: DVDVolumeFinding
    private let logDirectoryOverride: URL?

    convenience init() {
        self.init(
            configuration: .production,
            fileManager: .default,
            handBrakeRunner: ProcessHandBrakeRunner(),
            volumeFinder: FileSystemDVDVolumeFinder()
        )
    }

    init(
        configuration: RipConfiguration,
        fileManager: FileManager,
        handBrakeRunner: HandBrakeRunning,
        volumeFinder: DVDVolumeFinding,
        logDirectoryOverride: URL? = nil
    ) {
        self.configuration = configuration
        self.fileManager = fileManager
        self.handBrakeRunner = handBrakeRunner
        self.volumeFinder = volumeFinder
        self.logDirectoryOverride = logDirectoryOverride
    }

    var canRip: Bool {
        selectedDVD != nil && outputURL != nil && !isEncoding
    }

    var shouldShowStatusMessage: Bool {
        statusMessage != Self.initialStatusMessage && !statusMessage.hasPrefix("Ready to rip ")
    }

    var suggestedOutputName: String {
        let baseName = selectedDVD?.name
            .replacingOccurrences(of: "_", with: " ")
            .capitalized ?? "Movie"

        return "\(baseName).m4v"
    }

    var defaultOutputDirectory: URL {
        fileManager.urls(for: .moviesDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Movies", isDirectory: true)
    }

    var defaultLogDirectory: URL {
        if let logDirectoryOverride {
            return logDirectoryOverride
        }

        let libraryURL = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library", isDirectory: true)

        return libraryURL
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("SwiftRip", isDirectory: true)
    }

    func refreshDVDs() {
        dvdVolumes = volumeFinder.findMountedDVDs()

        if let selectedDVD, dvdVolumes.contains(selectedDVD) {
            return
        }

        selectedDVD = dvdVolumes.first
        updateDefaultOutputURL()
    }

    func chooseDVD(at url: URL) {
        let dvdURL = normalizedDVDURL(from: url)

        guard isValidDVD(at: dvdURL) else {
            selectedDVD = nil
            outputURL = nil
            statusMessage = "Choose a folder that contains a VIDEO_TS directory."
            return
        }

        selectedDVD = DVDVolume(id: dvdURL.path, name: dvdURL.lastPathComponent, path: dvdURL.path)
        updateDefaultOutputURL()
        statusMessage = "Ready to rip \(dvdURL.lastPathComponent)."
    }

    func setOutputURL(_ url: URL) {
        outputURL = url.pathExtension.lowercased() == "m4v"
            ? url
            : url.deletingPathExtension().appendingPathExtension("m4v")
    }

    private func updateDefaultOutputURL() {
        guard selectedDVD != nil else {
            outputURL = nil
            return
        }

        outputURL = defaultOutputDirectory.appendingPathComponent(suggestedOutputName)
    }

    private func normalizedDVDURL(from url: URL) -> URL {
        url.lastPathComponent == "VIDEO_TS" ? url.deletingLastPathComponent() : url
    }

    private func isValidDVD(at url: URL) -> Bool {
        let videoTSURL = url.appendingPathComponent("VIDEO_TS", isDirectory: true)
        var isDirectory: ObjCBool = false

        return fileManager.fileExists(atPath: videoTSURL.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    func startRip(revealOutput: @escaping @MainActor (URL) -> Void) async {
        guard let selectedDVD, let outputURL else { return }

        let arguments = configuration.handBrakeArguments(input: selectedDVD, outputURL: outputURL)
        let logURL = makeLogFileURL(for: selectedDVD)
        logFileURL = logURL
        logText = makeLogHeader(input: selectedDVD, outputURL: outputURL, arguments: arguments)

        guard fileManager.isExecutableFile(atPath: configuration.handBrakeCLIPath) else {
            savePreflightFailure("HandBrakeCLI was not found at \(configuration.handBrakeCLIPath).", logURL: logURL)
            return
        }

        guard fileManager.fileExists(atPath: configuration.libdvdcssPath) else {
            savePreflightFailure("libdvdcss was not found at \(configuration.libdvdcssPath).", logURL: logURL)
            return
        }

        progress = 0
        isEncoding = true
        statusMessage = "Ripping \(selectedDVD.name)..."

        let result = await handBrakeRunner.run(
            executablePath: configuration.handBrakeCLIPath,
            arguments: arguments,
            onOutput: { [weak self] line in
                guard let self else { return }

                self.logText += line

                if let parsedProgress = Self.progressValue(from: line) {
                    self.progress = parsedProgress
                }
            }
        )

        if result.exitCode == 0 {
            progress = 1
        }

        isEncoding = false

        logText += "\nExit code: \(result.exitCode)\n"
        let logWriteError = saveLog(to: logURL)

        if result.exitCode == 0 {
            statusMessage = "Done. Saved to \(outputURL.path). Log saved to \(logURL.path)."
            revealOutput(outputURL)
        } else {
            statusMessage = "HandBrakeCLI failed with exit code \(result.exitCode). Log saved to \(logURL.path)."
        }

        if let logWriteError {
            statusMessage += " Could not write log: \(logWriteError.localizedDescription)"
        }
    }

    private static func progressValue(from text: String) -> Double? {
        let pattern = #"Encoding:\s+task\s+\d+\s+of\s+\d+,\s+([0-9]+(?:\.[0-9]+)?)\s*%"#

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.matches(in: text, range: range).last,
              let percentRange = Range(match.range(at: 1), in: text),
              let percent = Double(text[percentRange]) else {
            return nil
        }

        return min(max(percent / 100, 0), 1)
    }

    private func savePreflightFailure(_ message: String, logURL: URL) {
        logText += "\(message)\n"
        let logWriteError = saveLog(to: logURL)
        statusMessage = "\(message) Log saved to \(logURL.path)."

        if let logWriteError {
            statusMessage += " Could not write log: \(logWriteError.localizedDescription)"
        }
    }

    private func makeLogFileURL(for dvd: DVDVolume) -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"

        let safeName = dvd.name
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")

        let fileName = "\(safeName.isEmpty ? "DVD" : safeName)-\(formatter.string(from: Date())).log"
        return defaultLogDirectory.appendingPathComponent(fileName)
    }

    private func makeLogHeader(input: DVDVolume, outputURL: URL, arguments: [String]) -> String {
        """
        SwiftRip Log
        DVD: \(input.name)
        Input: \(input.path)
        Output: \(outputURL.path)
        Command: \(configuration.handBrakeCLIPath) \(arguments.joined(separator: " "))

        """
    }

    private func saveLog(to url: URL) -> Error? {
        do {
            try fileManager.createDirectory(at: defaultLogDirectory, withIntermediateDirectories: true)
            try logText.write(to: url, atomically: true, encoding: .utf8)
            return nil
        } catch {
            return error
        }
    }
}
