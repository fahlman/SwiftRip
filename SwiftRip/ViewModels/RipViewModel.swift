//
//  RipViewModel.swift
//  SwiftRip
//

import Foundation
import Observation

@MainActor
struct RipEnvironment {
    let configuration: RipConfiguration
    let fileManager: FileManager
    let handBrakeRunner: HandBrakeRunning
    let volumeFinder: DVDVolumeFinding
    let appSettings: AppSettings
    let ripNotifier: RipNotifying
    let dvdDeviceEjector: DVDDeviceEjecting
    let logDirectoryOverride: URL?

    static var production: RipEnvironment {
        RipEnvironment(
            configuration: .production,
            fileManager: .default,
            handBrakeRunner: ProcessHandBrakeRunner(),
            volumeFinder: FileSystemDVDVolumeFinder(),
            appSettings: .shared,
            ripNotifier: SystemRipNotifier(),
            dvdDeviceEjector: WorkspaceDVDDeviceEjector()
        )
    }

    init(
        configuration: RipConfiguration,
        fileManager: FileManager,
        handBrakeRunner: HandBrakeRunning,
        volumeFinder: DVDVolumeFinding,
        appSettings: AppSettings,
        ripNotifier: RipNotifying = SystemRipNotifier(),
        dvdDeviceEjector: DVDDeviceEjecting = WorkspaceDVDDeviceEjector(),
        logDirectoryOverride: URL? = nil
    ) {
        self.configuration = configuration
        self.fileManager = fileManager
        self.handBrakeRunner = handBrakeRunner
        self.volumeFinder = volumeFinder
        self.appSettings = appSettings
        self.ripNotifier = ripNotifier
        self.dvdDeviceEjector = dvdDeviceEjector
        self.logDirectoryOverride = logDirectoryOverride
    }
}

@MainActor
@Observable
final class RipViewModel {
    static let initialStatusMessage = AppStrings.initialStatusMessage
    private static let fallbackMovieName = AppStrings.fallbackMovieName
    private static let movieFileExtension = "m4v"

    private var state = RipLifecycleState()
    private let outputFilenameFormatter = OutputFilenameFormatter()

    @ObservationIgnored
    private var ripTask: Task<Void, Never>?
    @ObservationIgnored
    private let environment: RipEnvironment

    init(environment: RipEnvironment = .production) {
        self.environment = environment
    }

    var dvdVolumes: [DVDVolume] {
        state.dvdVolumes
    }

    var selectedDVD: DVDVolume? {
        state.selectedDVD
    }

    var hasSelectedDVD: Bool {
        state.hasSelectedDVD
    }

    var selectedDVDName: String? {
        state.selectedDVDName
    }

    var outputURL: URL? {
        state.outputURL
    }

    var statusMessage: String {
        state.statusMessage
    }

    var logFileURL: URL? {
        state.logFileURL
    }

    var isEncoding: Bool {
        state.isEncoding
    }

    var progress: Double {
        state.progress
    }

    var canEjectCompletedDVD: Bool {
        state.canEjectCompletedDVD
    }

    var primaryAction: RipPrimaryAction {
        state.primaryAction
    }

    var commandAvailability: RipCommandAvailability {
        state.commandAvailability
    }

    var suggestedOutputName: String {
        guard let selectedDVD else { return "\(Self.fallbackMovieName).\(Self.movieFileExtension)" }
        return suggestedOutputName(for: selectedDVD)
    }

    var defaultOutputDirectory: URL {
        environment.appSettings.outputDirectoryURL
    }

    var outputFileName: String? {
        outputURL?.lastPathComponent
    }

    var needsOutputDirectoryPermission: Bool {
        environment.appSettings.needsOutputDirectoryPermission
    }

    var defaultLogDirectory: URL {
        if let logDirectoryOverride = environment.logDirectoryOverride {
            return logDirectoryOverride
        }

        let libraryURL = environment.fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first
            ?? environment.fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library", isDirectory: true)

        return libraryURL
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("SwiftRip", isDirectory: true)
    }

    func refreshDVDs() {
        updateState { $0.replaceMountedDVDs(environment.volumeFinder.findMountedDVDs()) }

        if let selectedDVD, dvdVolumes.contains(selectedDVD) {
            return
        }

        guard let firstDVD = dvdVolumes.first else {
            clearDVDSelection()
            return
        }

        selectDVD(firstDVD, statusMessage: AppStrings.readyToRip(firstDVD.name))
    }

    func chooseDVD(at url: URL) {
        let dvdURL = normalizedDVDURL(from: url)

        guard isValidDVD(at: dvdURL) else {
            clearDVDSelection(statusMessage: AppStrings.chooseVideoTSFolder(directoryName: DVDVolume.videoTSDirectoryName))
            return
        }

        let dvd = DVDVolume(id: dvdURL.path, name: dvdURL.lastPathComponent, path: dvdURL.path)
        selectDVD(dvd, statusMessage: AppStrings.readyToRip(dvdURL.lastPathComponent))
    }

    func setOutputURL(_ url: URL) {
        let normalizedURL = url.pathExtension.lowercased() == Self.movieFileExtension
            ? url
            : url.deletingPathExtension().appendingPathExtension(Self.movieFileExtension)
        updateState { $0.setOutputURL(normalizedURL) }
    }

    func setOutputDirectory(_ url: URL) throws {
        try environment.appSettings.setOutputDirectory(url)

        if let selectedDVD {
            selectDVD(selectedDVD)
        }
    }

    func selectDVD(_ dvd: DVDVolume, outputURL: URL? = nil, statusMessage: String? = nil) {
        let resolvedOutputURL = outputURL ?? defaultOutputDirectory.appendingPathComponent(suggestedOutputName(for: dvd))
        let resolvedStatusMessage = statusMessage ?? AppStrings.readyToRip(dvd.name)
        updateState { $0.selectDVD(dvd, outputURL: resolvedOutputURL, statusMessage: resolvedStatusMessage) }
    }

    func startRip(revealOutput: @escaping @MainActor @Sendable (URL) -> Void) async {
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
    }

    func cancelRipForWindowCloseOrAppQuit() {
        cancelRip()
    }

    func ejectCompletedDVD() {
        guard canEjectCompletedDVD, let selectedDVD else { return }

        let dvdURL = URL(fileURLWithPath: selectedDVD.path, isDirectory: true)
        do {
            try environment.dvdDeviceEjector.ejectDVD(at: dvdURL)
        } catch {
            updateState { $0.setStatusMessage(error.localizedDescription) }
            return
        }

        updateState { $0.resetAfterEject() }
    }

    private func updateState(_ update: (inout RipLifecycleState) -> Void) {
        var updatedState = state
        update(&updatedState)
        state = updatedState
    }

    private func suggestedOutputName(for dvd: DVDVolume) -> String {
        outputFilenameFormatter.outputName(
            for: dvd.name,
            format: environment.appSettings.outputFilenameFormat
        )
    }

    private func clearDVDSelection() {
        clearDVDSelection(statusMessage: AppStrings.initialStatusMessage)
    }

    private func clearDVDSelection(statusMessage: String) {
        updateState { $0.clearDVDSelection(statusMessage: statusMessage) }
    }

    private func performRip(revealOutput: @escaping @MainActor @Sendable (URL) -> Void) async {
        guard let selectedDVD, let outputURL else { return }

        let arguments = beginRipSession(input: selectedDVD, outputURL: outputURL)

        if let preflightFailure = RipPreflightCheck(
            configuration: environment.configuration,
            fileManager: environment.fileManager
        ).failureMessage(outputURL: outputURL) {
            savePreflightFailure(preflightFailure)
            return
        }

        beginEncoding(selectedDVD)

        let result = await environment.handBrakeRunner.run(
            executablePath: environment.configuration.handBrakeCLIPath,
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
        let arguments = environment.configuration.handBrakeArguments(input: input, outputURL: outputURL)
        let session = RipSession(
            input: input,
            outputURL: outputURL,
            arguments: arguments,
            logDirectoryURL: defaultLogDirectory,
            executablePath: environment.configuration.handBrakeCLIPath,
            libdvdcssPath: environment.configuration.libdvdcssPath,
            presetURL: environment.configuration.presetURL
        )
        updateState { $0.prepareRipSession(session, statusMessage: AppStrings.readyToRip(input.name)) }
        appendActiveLogBlankLine("SwiftRip: Selected DVD: \(input.name)")
        appendActiveLogLine("SwiftRip: Output file: \(outputURL.path)")
        _ = saveActiveLog()
        return arguments
    }

    private func beginEncoding(_ selectedDVD: DVDVolume) {
        appendActiveLogBlankLine("SwiftRip: Started ripping \(selectedDVD.name)")
        _ = saveActiveLog()
        updateState { $0.beginEncoding(statusMessage: AppStrings.ripping(selectedDVD.name)) }
    }

    private func handleHandBrakeOutputLine(_ line: String) {
        updateState { $0.mutateActiveRip { $0.log.append(line) } }
        _ = saveActiveLog()

        if let parsedProgress = HandBrakeProgressParser.progressValue(from: line) {
            updateState { $0.updateProgress(parsedProgress) }
        }
    }

    private func finishCancelledRip(exitCode: Int32) {
        updateState { $0.mutateActiveRip { $0.log.appendExitCode(exitCode) } }
        _ = saveActiveLog()
        cleanupCancelledRip()
    }

    private func finishSuccessfulRip(
        outputURL: URL,
        exitCode: Int32,
        revealOutput: @escaping @MainActor @Sendable (URL) -> Void
    ) {
        updateState { $0.mutateActiveRip { $0.protectCompletedOutput() } }
        appendActiveLogBlankLine("SwiftRip: Rip completed successfully")
        appendActiveLogLine("Completed output protected from cancellation cleanup: \(outputURL.path)")
        _ = saveActiveLog()
        notifyRipCompleted(outputURL: outputURL)
        let logWriteError = finishRipWithOutputPreserved(
            exitCode: exitCode,
            outcome: "Completed"
        )
        let statusMessage = AppStrings.done(outputPath: outputURL.path, logPath: activeLogPath)
        updateState { $0.markCompleted(statusMessage: statusMessage) }
        appendLogWriteErrorIfNeeded(logWriteError)
        if environment.appSettings.shouldRevealCompletedFile {
            revealOutput(outputURL)
        }
        if environment.appSettings.shouldAutoEjectAfterSuccessfulRip {
            ejectCompletedDVD()
        }
    }

    private func finishFailedRip(outputURL: URL, exitCode: Int32) {
        appendActiveLogBlankLine("SwiftRip: Rip failed; output preserved for inspection")
        appendActiveLogLine("Output preserved for inspection: \(outputURL.path)")
        _ = saveActiveLog()
        let logWriteError = finishRipWithOutputPreserved(
            exitCode: exitCode,
            outcome: "Failed"
        )
        notifyRipFailed(outputURL: outputURL, exitCode: exitCode)
        let statusMessage = AppStrings.handBrakeFailed(exitCode: exitCode, logPath: activeLogPath)
        updateState { $0.markFailed(statusMessage: statusMessage) }
        appendLogWriteErrorIfNeeded(logWriteError)
    }

    private func finishRipWithOutputPreserved(exitCode: Int32, outcome: String) -> Error? {
        updateState { $0.mutateActiveRip { $0.log.appendOutcome(outcome) } }
        return appendExitCodeAndSaveLog(exitCode)
    }

    private func notifyRipCompleted(outputURL: URL) {
        environment.ripNotifier.notifyRipCompleted(
            outputURL: outputURL,
            sound: environment.appSettings.completionSound,
            isNotificationEnabled: environment.appSettings.isCompletionNotificationEnabled
        ) { [weak self] message in
            self?.appendActiveLogBlankLine(message)
            _ = self?.saveActiveLog()
        }
    }

    private func notifyRipFailed(outputURL: URL, exitCode: Int32) {
        environment.ripNotifier.notifyRipFailed(
            outputURL: outputURL,
            exitCode: exitCode,
            isNotificationEnabled: environment.appSettings.isCompletionNotificationEnabled
        ) { [weak self] message in
            self?.appendActiveLogBlankLine(message)
            _ = self?.saveActiveLog()
        }
    }

    private func normalizedDVDURL(from url: URL) -> URL {
        url.lastPathComponent == DVDVolume.videoTSDirectoryName ? url.deletingLastPathComponent() : url
    }

    private func isValidDVD(at url: URL) -> Bool {
        let videoTSURL = url.appendingPathComponent(DVDVolume.videoTSDirectoryName, isDirectory: true)
        var isDirectory: ObjCBool = false

        return environment.fileManager.fileExists(atPath: videoTSURL.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    private func deleteIncompleteOutputFile(at url: URL) {
        guard environment.fileManager.fileExists(atPath: url.path) else { return }

        do {
            try environment.fileManager.removeItem(at: url)
            appendActiveLogBlankLine("Deleted incomplete output file: \(url.path)")
        } catch {
            appendActiveLogBlankLine("Could not delete incomplete output file: \(error.localizedDescription)")
        }
    }

    private func cleanupCancelledRip() {
        guard let activeRip = state.activeRip else { return }

        appendActiveLogBlankLine("SwiftRip: User requested stop")
        _ = saveActiveLog()

        if activeRip.shouldDeleteOutputOnCancel {
            deleteIncompleteOutputFile(at: activeRip.outputURL)
        }

        appendActiveLogBlankLine("Rip stopped by user.")
        updateState { $0.mutateActiveRip { $0.log.appendOutcome("Canceled") } }
        _ = saveActiveLog()
        updateState { $0.markCanceled(statusMessage: AppStrings.ripStopped) }
    }

    private var activeLogPath: String {
        state.activeRip?.log.url.path ?? state.logFileURL?.path ?? ""
    }

    private func appendExitCodeAndSaveLog(_ exitCode: Int32) -> Error? {
        updateState { $0.mutateActiveRip { $0.log.appendExitCode(exitCode) } }
        return saveActiveLog()
    }

    private func appendLogWriteErrorIfNeeded(_ error: Error?) {
        guard let error else { return }
        updateState { $0.setStatusMessage("\(statusMessage) \(AppStrings.couldNotWriteLog(error.localizedDescription))") }
    }

    private func savePreflightFailure(_ message: String) {
        appendActiveLogLine(message)
        updateState { $0.mutateActiveRip { $0.log.appendOutcome("Preflight failed") } }
        let logWriteError = saveActiveLog()
        updateState { $0.markFailed(statusMessage: "\(message) \(AppStrings.logSaved(to: activeLogPath))") }
        appendLogWriteErrorIfNeeded(logWriteError)
    }

    private func saveActiveLog() -> Error? {
        state.activeRip?.log.save(using: environment.fileManager)
    }

    private func appendActiveLogLine(_ line: String) {
        updateState { $0.mutateActiveRip { $0.log.appendLine(line) } }
    }

    private func appendActiveLogBlankLine(_ line: String) {
        updateState { $0.mutateActiveRip { $0.log.appendBlankLine(line) } }
    }
}
