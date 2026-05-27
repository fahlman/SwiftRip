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
    let dvdInputAccessProvider: any DVDInputAccessProviding
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
            dvdInputAccessProvider: SecurityScopedDVDInputAccessProvider(),
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
        dvdInputAccessProvider: any DVDInputAccessProviding = SecurityScopedDVDInputAccessProvider(),
        appSettings: AppSettings,
        ripNotifier: RipNotifying = SystemRipNotifier(),
        dvdDeviceEjector: DVDDeviceEjecting = WorkspaceDVDDeviceEjector(),
        logDirectoryOverride: URL? = nil
    ) {
        self.configuration = configuration
        self.fileManager = fileManager
        self.handBrakeRunner = handBrakeRunner
        self.volumeFinder = volumeFinder
        self.dvdInputAccessProvider = dvdInputAccessProvider
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

    private enum RipFinishOutcome {
        case completed(revealOutput: @MainActor @Sendable (URL) -> Void)
        case failed
        case outputValidationFailed(message: String)

        var logOutcome: String {
            switch self {
            case .completed:
                return "Completed"
            case .failed, .outputValidationFailed:
                return "Failed"
            }
        }
    }

    private var state = RipLifecycleState()
    private let outputFilenameFormatter = OutputFilenameFormatter()
    private let outputURLResolver: OutputURLResolver

    @ObservationIgnored
    private var ripTask: Task<Void, Never>?
    @ObservationIgnored
    private var selectedDVDInputAccess: (any DVDInputAccess)?
    @ObservationIgnored
    private let environment: RipEnvironment

    init(environment: RipEnvironment = .production) {
        self.environment = environment
        self.outputURLResolver = OutputURLResolver(fileManager: environment.fileManager)
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

    var dvdDisplayName: String {
        if let selectedDVDName {
            return selectedDVDName
        }

        return AppStrings.noValidDVDTitle
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
        let mountedDVDs = environment.volumeFinder.findMountedDVDs()
        updateState { $0.replaceMountedDVDs(mountedDVDs) }

        guard let selectedDVD else {
            return
        }

        if mountedDVDs.contains(selectedDVD) {
            return
        }

        clearDVDSelection()
    }

    @discardableResult
    func chooseDVD(at url: URL) -> Bool {
        guard !isEncoding else { return false }

        let access = environment.dvdInputAccessProvider.startAccessingDVD(at: url)

        guard isValidDVD(at: url) else {
            access.stopAccessing()
            clearDVDSelection(statusMessage: AppStrings.chooseVideoTSFolder(directoryName: DVDVolume.videoTSDirectoryName))
            return false
        }

        replaceDVDInputAccess(with: access)
        let dvd = DVDVolume(id: url.path, name: url.lastPathComponent, path: url.path)
        selectDVD(dvd, statusMessage: AppStrings.readyToRip(url.lastPathComponent))
        return true
    }

    func setOutputURL(_ url: URL) {
        updateState { $0.setOutputURL(outputURLResolver.normalizedMovieURL(for: url)) }
    }

    func setOutputDirectory(_ url: URL) throws {
        try environment.appSettings.setOutputDirectory(url)

        if let selectedDVD {
            selectDVD(selectedDVD)
        }
    }

    func selectDVD(_ dvd: DVDVolume, outputURL: URL? = nil, statusMessage: String? = nil) {
        let resolvedOutputURL = outputURLResolver.availableURL(
            for: outputURL ?? defaultOutputDirectory.appendingPathComponent(suggestedOutputName(for: dvd))
        )
        let resolvedStatusMessage = statusMessage ?? AppStrings.readyToRip(dvd.name)
        updateState { $0.selectDVD(dvd, outputURL: resolvedOutputURL, statusMessage: resolvedStatusMessage) }
    }

    func startRip(revealOutput: @escaping @MainActor @Sendable (URL) -> Void) async {
        guard !isEncoding, ripTask == nil else { return }

        let task = Task { [weak self] in
            guard let self else { return }
            await self.performRip(revealOutput: revealOutput)
        }

        ripTask = task
        await task.value
        ripTask = nil
    }

    func cancelRip() {
        guard isEncoding else { return }
        ripTask?.cancel()

        cleanupCancelledRip()
    }

    func cancelRipForWindowCloseOrAppQuit() {
        cancelRip()
        clearDVDInputAccess()
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

        clearDVDInputAccess()
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
        clearDVDInputAccess()
        updateState { $0.clearDVDSelection(statusMessage: statusMessage) }
    }

    private func replaceDVDInputAccess(with access: any DVDInputAccess) {
        clearDVDInputAccess()
        selectedDVDInputAccess = access
    }

    private func clearDVDInputAccess() {
        selectedDVDInputAccess?.stopAccessing()
        selectedDVDInputAccess = nil
    }

    private func performRip(revealOutput: @escaping @MainActor @Sendable (URL) -> Void) async {
        guard let selectedDVD, let outputURL else { return }

        let resolvedOutputURL = outputURLResolver.availableURL(for: outputURL)
        if resolvedOutputURL != outputURL {
            updateState { $0.setOutputURL(resolvedOutputURL) }
        }

        let arguments = beginRipSession(input: selectedDVD, outputURL: resolvedOutputURL)

        if let preflightFailure = RipPreflightCheck(
            configuration: environment.configuration,
            fileManager: environment.fileManager
        ).failureMessage(outputURL: resolvedOutputURL) {
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
            if let postflightFailure = RipPostflightCheck(fileManager: environment.fileManager)
                .failureMessage(outputURL: resolvedOutputURL) {
                finishRipWithOutputPreserved(
                    outputURL: resolvedOutputURL,
                    exitCode: result.exitCode,
                    outcome: .outputValidationFailed(message: postflightFailure)
                )
            } else {
                finishRipWithOutputPreserved(
                    outputURL: resolvedOutputURL,
                    exitCode: result.exitCode,
                    outcome: .completed(revealOutput: revealOutput)
                )
            }
        } else {
            finishRipWithOutputPreserved(outputURL: resolvedOutputURL, exitCode: result.exitCode, outcome: .failed)
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

    private func finishRipWithOutputPreserved(
        outputURL: URL,
        exitCode: Int32,
        outcome: RipFinishOutcome
    ) {
        appendOutputPreservationLog(outputURL: outputURL, outcome: outcome)
        _ = saveActiveLog()

        if case .completed = outcome {
            notifyRipCompleted(outputURL: outputURL)
        }

        let logWriteError = appendRipOutcomeAndExitCode(
            exitCode: exitCode,
            outcome: outcome.logOutcome
        )

        finishRipState(
            outputURL: outputURL,
            exitCode: exitCode,
            outcome: outcome,
            logWriteError: logWriteError
        )
    }

    private func appendOutputPreservationLog(outputURL: URL, outcome: RipFinishOutcome) {
        switch outcome {
        case .completed:
            updateState { $0.mutateActiveRip { $0.protectCompletedOutput() } }
            appendActiveLogBlankLine("SwiftRip: Rip completed successfully")
            appendActiveLogLine("Completed output protected from cancellation cleanup: \(outputURL.path)")
        case .failed:
            appendActiveLogBlankLine("SwiftRip: Rip failed; output preserved for inspection")
            appendActiveLogLine("Output preserved for inspection: \(outputURL.path)")
        case .outputValidationFailed(let message):
            appendActiveLogBlankLine("SwiftRip: Output validation failed")
            appendActiveLogLine(message)
        }
    }

    private func appendRipOutcomeAndExitCode(exitCode: Int32, outcome: String) -> Error? {
        updateState { $0.mutateActiveRip { $0.log.appendOutcome(outcome) } }
        return appendExitCodeAndSaveLog(exitCode)
    }

    private func finishRipState(
        outputURL: URL,
        exitCode: Int32,
        outcome: RipFinishOutcome,
        logWriteError: Error?
    ) {
        switch outcome {
        case .completed(let revealOutput):
            let statusMessage = AppStrings.done(outputPath: outputURL.path, logPath: activeLogPath)
            updateState { $0.markCompleted(statusMessage: statusMessage) }
            clearDVDInputAccess()
            appendLogWriteErrorIfNeeded(logWriteError)
            if environment.appSettings.shouldRevealCompletedFile {
                revealOutput(outputURL)
            }
            if environment.appSettings.shouldAutoEjectAfterSuccessfulRip {
                ejectCompletedDVD()
            }
        case .failed:
            notifyRipFailed(outputURL: outputURL, exitCode: exitCode)
            let statusMessage = AppStrings.handBrakeFailed(exitCode: exitCode, logPath: activeLogPath)
            updateState { $0.markFailed(statusMessage: statusMessage) }
            appendLogWriteErrorIfNeeded(logWriteError)
        case .outputValidationFailed(let message):
            notifyRipFailed(outputURL: outputURL, message: message)
            updateState { $0.markFailed(statusMessage: "\(message) \(AppStrings.logSaved(to: activeLogPath))") }
            appendLogWriteErrorIfNeeded(logWriteError)
        }
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

    private func notifyRipFailed(outputURL: URL, message: String) {
        environment.ripNotifier.notifyRipFailed(
            outputURL: outputURL,
            message: message,
            isNotificationEnabled: environment.appSettings.isCompletionNotificationEnabled
        ) { [weak self] message in
            self?.appendActiveLogBlankLine(message)
            _ = self?.saveActiveLog()
        }
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
