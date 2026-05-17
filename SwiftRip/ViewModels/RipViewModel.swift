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
    private static let progressRegex = try? NSRegularExpression(
        pattern: #"Encoding:\s+task\s+\d+\s+of\s+\d+,\s+([0-9]+(?:\.[0-9]+)?)\s*%"#
    )
    static let initialStatusMessage = "Choose a DVD and output file to begin."

    @Published var dvdVolumes: [DVDVolume] = []
    @Published var selectedDVD: DVDVolume?
    @Published var outputURL: URL?
    @Published var statusMessage = RipViewModel.initialStatusMessage
    @Published private(set) var logFileURL: URL?
    @Published var isEncoding = false
    @Published private(set) var progress: Double = 0

    private var logText = ""
    private var ripTask: Task<Void, Never>?
    private var activeRip: ActiveRip?
    private let configuration: RipConfiguration
    private let fileManager: FileManager
    private let handBrakeRunner: HandBrakeRunning
    private let volumeFinder: DVDVolumeFinding
    private let logDirectoryOverride: URL?

    private struct ActiveRip {
        let outputURL: URL
        let logURL: URL
        var shouldDeleteOutputOnCancel = true
    }

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

    var isPrimaryActionAvailable: Bool {
        isEncoding || (selectedDVD != nil && outputURL != nil)
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
        guard !isEncoding else { return }
        ripTask = Task { [weak self] in
            guard let self else { return }
            await self.performRip(revealOutput: revealOutput)
        }

        await ripTask?.value
        ripTask = nil
    }

    func cancelRip() {
        guard isEncoding else { return }
        ripTask?.cancel()

        cleanupCancelledRip()

        isEncoding = false
        statusMessage = "Rip stopped."
    }

    private func performRip(revealOutput: @escaping @MainActor (URL) -> Void) async {
        guard let selectedDVD, let outputURL else { return }

        let arguments = configuration.handBrakeArguments(input: selectedDVD, outputURL: outputURL)
        let logURL = makeLogFileURL(for: selectedDVD)
        activeRip = ActiveRip(outputURL: outputURL, logURL: logURL)
        logFileURL = logURL
        logText = makeLogHeader(input: selectedDVD, outputURL: outputURL, arguments: arguments)

        guard fileManager.isExecutableFile(atPath: configuration.handBrakeCLIPath) else {
            savePreflightFailure("HandBrakeCLI was not found at \(configuration.handBrakeCLIPath).", logURL: logURL)
            clearActiveRipFiles()
            return
        }

        guard fileManager.fileExists(atPath: configuration.libdvdcssPath) else {
            savePreflightFailure("libdvdcss was not found at \(configuration.libdvdcssPath).", logURL: logURL)
            clearActiveRipFiles()
            return
        }

        guard fileManager.fileExists(atPath: configuration.presetURL.path) else {
            savePreflightFailure("SwiftRip preset was not found at \(configuration.presetURL.path).", logURL: logURL)
            clearActiveRipFiles()
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

        if Task.isCancelled {
            logText += "\nExit code: \(result.exitCode)\n"
            cleanupCancelledRip()
            isEncoding = false
            statusMessage = "Rip stopped."
            return
        }

        if result.exitCode == 0 {
            activeRip?.shouldDeleteOutputOnCancel = false
            progress = 1
        }

        isEncoding = false

        let logWriteError = appendExitCodeAndSaveLog(result.exitCode, to: logURL)

        if result.exitCode == 0 {
            statusMessage = "Done. Saved to \(outputURL.path). Log saved to \(logURL.path)."
            revealOutput(outputURL)
        } else {
            statusMessage = "HandBrakeCLI failed with exit code \(result.exitCode). Log saved to \(logURL.path)."
        }

        appendLogWriteErrorIfNeeded(logWriteError)
        clearActiveRipFiles()
    }

    private func deleteIncompleteOutputFile(at url: URL) {
        guard fileManager.fileExists(atPath: url.path) else { return }

        do {
            try fileManager.removeItem(at: url)
            logText += "\nDeleted incomplete output file: \(url.path)\n"
        } catch {
            logText += "\nCould not delete incomplete output file: \(error.localizedDescription)\n"
        }
    }

    private func cleanupCancelledRip() {
        guard let activeRip else { return }

        if activeRip.shouldDeleteOutputOnCancel {
            deleteIncompleteOutputFile(at: activeRip.outputURL)
        }

        logText += "\nRip stopped by user.\n"
        _ = saveLog(to: activeRip.logURL)
        clearActiveRipFiles()
    }

    private func clearActiveRipFiles() {
        activeRip = nil
    }

    private static func progressValue(from text: String) -> Double? {
        guard let progressRegex else { return nil }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = progressRegex.matches(in: text, range: range).last,
              let percentRange = Range(match.range(at: 1), in: text),
              let percent = Double(text[percentRange]) else {
            return nil
        }

        return min(max(percent / 100, 0), 1)
    }

    private func appendExitCodeAndSaveLog(_ exitCode: Int32, to logURL: URL) -> Error? {
        logText += "\nExit code: \(exitCode)\n"
        return saveLog(to: logURL)
    }

    private func appendLogWriteErrorIfNeeded(_ error: Error?) {
        guard let error else { return }
        statusMessage += " Could not write log: \(error.localizedDescription)"
    }

    private func savePreflightFailure(_ message: String, logURL: URL) {
        logText += "\(message)\n"
        let logWriteError = saveLog(to: logURL)
        statusMessage = "\(message) Log saved to \(logURL.path)."
        appendLogWriteErrorIfNeeded(logWriteError)
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
