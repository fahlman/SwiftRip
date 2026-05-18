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
    private static let fallbackMovieName = "Movie"
    private static let fallbackDVDName = "DVD"
    private static let readyStatusPrefix = "Ready to rip "
    private static let movieFileExtension = "m4v"

    @Published var dvdVolumes: [DVDVolume] = []
    @Published var selectedDVD: DVDVolume?
    @Published var outputURL: URL?
    @Published var statusMessage = RipViewModel.initialStatusMessage
    @Published private(set) var logFileURL: URL?
    @Published var isEncoding = false
    @Published private(set) var progress: Double = 0

    private var logText = ""
    private var ripTask: Task<Void, Never>?
    private var activeRip: RipSession?
    private let configuration: RipConfiguration
    private let fileManager: FileManager
    private let handBrakeRunner: HandBrakeRunning
    private let volumeFinder: DVDVolumeFinding
    private let logDirectoryOverride: URL?

    private struct RipSession {
        let outputURL: URL
        let logURL: URL
        private(set) var shouldDeleteOutputOnCancel = true

        mutating func protectCompletedOutput() {
            shouldDeleteOutputOnCancel = false
        }
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
        statusMessage != Self.initialStatusMessage && !statusMessage.hasPrefix(Self.readyStatusPrefix)
    }

    var suggestedOutputName: String {
        let baseName = selectedDVD?.name
            .replacingOccurrences(of: "_", with: " ")
            .capitalized ?? Self.fallbackMovieName

        return "\(baseName).\(Self.movieFileExtension)"
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
            statusMessage = "Choose a folder that contains a \(DVDVolume.videoTSDirectoryName) directory."
            return
        }

        selectedDVD = DVDVolume(id: dvdURL.path, name: dvdURL.lastPathComponent, path: dvdURL.path)
        updateDefaultOutputURL()
        statusMessage = "\(Self.readyStatusPrefix)\(dvdURL.lastPathComponent)."
    }

    func setOutputURL(_ url: URL) {
        outputURL = url.pathExtension.lowercased() == Self.movieFileExtension
            ? url
            : url.deletingPathExtension().appendingPathExtension(Self.movieFileExtension)
    }

    private func updateDefaultOutputURL() {
        guard selectedDVD != nil else {
            outputURL = nil
            return
        }

        outputURL = defaultOutputDirectory.appendingPathComponent(suggestedOutputName)
    }

    private func normalizedDVDURL(from url: URL) -> URL {
        url.lastPathComponent == DVDVolume.videoTSDirectoryName ? url.deletingLastPathComponent() : url
    }

    private func isValidDVD(at url: URL) -> Bool {
        let videoTSURL = url.appendingPathComponent(DVDVolume.videoTSDirectoryName, isDirectory: true)
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
        activeRip = RipSession(outputURL: outputURL, logURL: logURL)
        logFileURL = logURL
        logText = makeLogHeader(input: selectedDVD, outputURL: outputURL, arguments: arguments)

        if let preflightFailure = RipPreflightCheck(
            configuration: configuration,
            fileManager: fileManager
        ).failureMessage() {
            savePreflightFailure(preflightFailure, logURL: logURL)
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

                if let parsedProgress = HandBrakeProgressParser.progressValue(from: line) {
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
            activeRip?.protectCompletedOutput()
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

        let fileName = "\(safeName.isEmpty ? Self.fallbackDVDName : safeName)-\(formatter.string(from: Date())).log"
        return defaultLogDirectory.appendingPathComponent(fileName)
    }

    private func makeLogHeader(input: DVDVolume, outputURL: URL, arguments: [String]) -> String {
        """
        \(RipConfiguration.appName) Log
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
