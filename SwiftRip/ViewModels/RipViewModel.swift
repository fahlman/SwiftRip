//
//  RipViewModel.swift
//  SwiftRip
//
//  Created by Ryan Fahlsing on 5/16/26.
//

import AppKit
import Combine
import Foundation

@MainActor
final class RipViewModel: ObservableObject {
    static let initialStatusMessage = AppStrings.initialStatusMessage
    private static let fallbackMovieName = AppStrings.fallbackMovieName
    private static let readyStatusPrefix = AppStrings.readyStatusPrefix
    private static let movieFileExtension = "m4v"

    @Published var dvdVolumes: [DVDVolume] = []
    @Published var selectedDVD: DVDVolume?
    @Published var outputURL: URL?
    @Published var statusMessage = RipViewModel.initialStatusMessage
    @Published private(set) var logFileURL: URL?
    @Published var isEncoding = false
    @Published private(set) var progress: Double = 0
    @Published private(set) var canEjectCompletedDVD = false

    private var ripTask: Task<Void, Never>?
    private var activeRip: RipSession?
    private let configuration: RipConfiguration
    private let fileManager: FileManager
    private let handBrakeRunner: HandBrakeRunning
    private let volumeFinder: DVDVolumeFinding
    private let appSettings: AppSettings
    private let completionNotifier: RipCompletionNotifying
    private let logDirectoryOverride: URL?

    convenience init() {
        self.init(
            configuration: .production,
            fileManager: .default,
            handBrakeRunner: ProcessHandBrakeRunner(),
            volumeFinder: FileSystemDVDVolumeFinder()
        )
    }

    convenience init(
        configuration: RipConfiguration,
        fileManager: FileManager,
        handBrakeRunner: HandBrakeRunning,
        volumeFinder: DVDVolumeFinding,
        logDirectoryOverride: URL? = nil
    ) {
        self.init(
            configuration: configuration,
            fileManager: fileManager,
            handBrakeRunner: handBrakeRunner,
            volumeFinder: volumeFinder,
            appSettings: .shared,
            completionNotifier: SystemRipCompletionNotifier(),
            logDirectoryOverride: logDirectoryOverride
        )
    }

    convenience init(
        configuration: RipConfiguration,
        fileManager: FileManager,
        handBrakeRunner: HandBrakeRunning,
        volumeFinder: DVDVolumeFinding,
        appSettings: AppSettings,
        logDirectoryOverride: URL? = nil
    ) {
        self.init(
            configuration: configuration,
            fileManager: fileManager,
            handBrakeRunner: handBrakeRunner,
            volumeFinder: volumeFinder,
            appSettings: appSettings,
            completionNotifier: SystemRipCompletionNotifier(),
            logDirectoryOverride: logDirectoryOverride
        )
    }

    init(
        configuration: RipConfiguration,
        fileManager: FileManager,
        handBrakeRunner: HandBrakeRunning,
        volumeFinder: DVDVolumeFinding,
        appSettings: AppSettings,
        completionNotifier: RipCompletionNotifying,
        logDirectoryOverride: URL? = nil
    ) {
        self.configuration = configuration
        self.fileManager = fileManager
        self.handBrakeRunner = handBrakeRunner
        self.volumeFinder = volumeFinder
        self.appSettings = appSettings
        self.completionNotifier = completionNotifier
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
        appSettings.outputDirectoryURL
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
        clearCompletedRipState()
        updateDefaultOutputURL()
    }

    func chooseDVD(at url: URL) {
        let dvdURL = normalizedDVDURL(from: url)

        guard isValidDVD(at: dvdURL) else {
            clearDVDSelection()
            statusMessage = AppStrings.chooseVideoTSFolder(directoryName: DVDVolume.videoTSDirectoryName)
            return
        }

        selectedDVD = DVDVolume(id: dvdURL.path, name: dvdURL.lastPathComponent, path: dvdURL.path)
        clearCompletedRipState()
        updateDefaultOutputURL()
        statusMessage = AppStrings.readyToRip(dvdURL.lastPathComponent)
    }

    func setOutputURL(_ url: URL) {
        outputURL = url.pathExtension.lowercased() == Self.movieFileExtension
            ? url
            : url.deletingPathExtension().appendingPathExtension(Self.movieFileExtension)
    }

    private func updateDefaultOutputURL() {
        guard selectedDVD != nil else {
            clearDVDSelection()
            return
        }

        outputURL = defaultOutputDirectory.appendingPathComponent(suggestedOutputName)
    }

    private func clearDVDSelection() {
        selectedDVD = nil
        outputURL = nil
        clearCompletedRipState()
    }

    private func clearCompletedRipState() {
        canEjectCompletedDVD = false
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
        clearCompletedRipState()
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
        statusMessage = AppStrings.ripStopped
    }

    func ejectCompletedDVD() {
        guard canEjectCompletedDVD, let selectedDVD else { return }

        let dvdURL = URL(fileURLWithPath: selectedDVD.path, isDirectory: true)
        do {
            try NSWorkspace.shared.unmountAndEjectDevice(at: dvdURL)
        } catch {
            statusMessage = error.localizedDescription
            return
        }

        clearDVDSelection()
        progress = 0
        statusMessage = Self.initialStatusMessage
    }

    private func performRip(revealOutput: @escaping @MainActor (URL) -> Void) async {
        guard let selectedDVD, let outputURL else { return }

        let arguments = beginRipSession(input: selectedDVD, outputURL: outputURL)

        if let preflightFailure = RipPreflightCheck(
            configuration: configuration,
            fileManager: fileManager
        ).failureMessage() {
            savePreflightFailure(preflightFailure)
            clearActiveRipFiles()
            return
        }

        beginEncoding(selectedDVD)

        let result = await handBrakeRunner.run(
            executablePath: configuration.handBrakeCLIPath,
            arguments: arguments,
            onOutput: { [weak self] line in
                self?.handleHandBrakeOutputLine(line)
            }
        )

        if Task.isCancelled {
            finishCancelledRip(exitCode: result.exitCode)
            return
        }

        if result.exitCode == 0 {
            finishSuccessfulRip(outputURL: outputURL, exitCode: result.exitCode, revealOutput: revealOutput)
        } else {
            finishFailedRip(outputURL: outputURL, exitCode: result.exitCode)
        }
    }

    private func beginRipSession(input: DVDVolume, outputURL: URL) -> [String] {
        let arguments = configuration.handBrakeArguments(input: input, outputURL: outputURL)
        activeRip = RipSession(
            input: input,
            outputURL: outputURL,
            arguments: arguments,
            logDirectoryURL: defaultLogDirectory,
            executablePath: configuration.handBrakeCLIPath,
            libdvdcssPath: configuration.libdvdcssPath,
            presetURL: configuration.presetURL
        )
        logFileURL = activeRip?.log.url
        return arguments
    }

    private func beginEncoding(_ selectedDVD: DVDVolume) {
        progress = 0
        isEncoding = true
        statusMessage = AppStrings.ripping(selectedDVD.name)
    }

    private func handleHandBrakeOutputLine(_ line: String) {
        activeRip?.log.append(line)

        if let parsedProgress = HandBrakeProgressParser.progressValue(from: line) {
            progress = parsedProgress
        }
    }

    private func finishCancelledRip(exitCode: Int32) {
        activeRip?.log.appendExitCode(exitCode)
        cleanupCancelledRip()
        isEncoding = false
        statusMessage = AppStrings.ripStopped
    }

    private func finishSuccessfulRip(
        outputURL: URL,
        exitCode: Int32,
        revealOutput: @escaping @MainActor (URL) -> Void
    ) {
        activeRip?.protectCompletedOutput()
        activeRip?.log.appendLine("Completed output protected from cancellation cleanup: \(outputURL.path)")
        progress = 1
        canEjectCompletedDVD = true
        notifyRipCompleted(outputURL: outputURL)
        let logWriteError = finishRipWithOutputPreserved(
            exitCode: exitCode,
            outcome: "Completed"
        )
        statusMessage = AppStrings.done(outputPath: outputURL.path, logPath: activeLogPath)
        appendLogWriteErrorIfNeeded(logWriteError)
        revealOutput(outputURL)
        clearActiveRipFiles()
    }

    private func finishFailedRip(outputURL: URL, exitCode: Int32) {
        activeRip?.log.appendLine("Output preserved for inspection: \(outputURL.path)")
        let logWriteError = finishRipWithOutputPreserved(
            exitCode: exitCode,
            outcome: "Failed"
        )
        statusMessage = AppStrings.handBrakeFailed(exitCode: exitCode, logPath: activeLogPath)
        appendLogWriteErrorIfNeeded(logWriteError)
        clearActiveRipFiles()
    }

    private func finishRipWithOutputPreserved(exitCode: Int32, outcome: String) -> Error? {
        isEncoding = false
        activeRip?.log.appendOutcome(outcome)
        return appendExitCodeAndSaveLog(exitCode)
    }

    private func notifyRipCompleted(outputURL: URL) {
        completionNotifier.notifyRipCompleted(outputURL: outputURL) { [weak self] message in
            self?.activeRip?.log.appendBlankLine(message)
        }
    }

    private func deleteIncompleteOutputFile(at url: URL) {
        guard fileManager.fileExists(atPath: url.path) else { return }

        do {
            try fileManager.removeItem(at: url)
            activeRip?.log.appendBlankLine("Deleted incomplete output file: \(url.path)")
        } catch {
            activeRip?.log.appendBlankLine("Could not delete incomplete output file: \(error.localizedDescription)")
        }
    }

    private func cleanupCancelledRip() {
        guard let activeRip else { return }

        if activeRip.shouldDeleteOutputOnCancel {
            deleteIncompleteOutputFile(at: activeRip.outputURL)
        }

        self.activeRip?.log.appendBlankLine("Rip stopped by user.")
        self.activeRip?.log.appendOutcome("Canceled")
        _ = saveActiveLog()
        clearActiveRipFiles()
    }

    private func clearActiveRipFiles() {
        activeRip = nil
    }

    private var activeLogPath: String {
        activeRip?.log.url.path ?? ""
    }

    private func appendExitCodeAndSaveLog(_ exitCode: Int32) -> Error? {
        activeRip?.log.appendExitCode(exitCode)
        return saveActiveLog()
    }

    private func appendLogWriteErrorIfNeeded(_ error: Error?) {
        guard let error else { return }
        statusMessage += " \(AppStrings.couldNotWriteLog(error.localizedDescription))"
    }

    private func savePreflightFailure(_ message: String) {
        activeRip?.log.appendLine(message)
        activeRip?.log.appendOutcome("Preflight failed")
        let logWriteError = saveActiveLog()
        statusMessage = "\(message) \(AppStrings.logSaved(to: activeLogPath))"
        appendLogWriteErrorIfNeeded(logWriteError)
    }

    private func saveActiveLog() -> Error? {
        activeRip?.log.save(using: fileManager)
    }
}
