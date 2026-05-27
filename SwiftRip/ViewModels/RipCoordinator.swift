//
//  RipCoordinator.swift
//  SwiftRip
//

import Foundation

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
final class RipCoordinator {
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

    var onStateChange: (@MainActor (RipLifecycleState) -> Void)?

    private var state = RipLifecycleState()
    private let outputFilenameFormatter = OutputFilenameFormatter()
    private let outputURLResolver: OutputURLResolver
    private let ripEngine: RipEngine
    private let environment: RipEnvironment

    private var ripTask: Task<Void, Never>?
    private var selectedDVDInputAccess: (any DVDInputAccess)?
    private var activeOutputDirectoryAccess: (any SecurityScopedResourceAccess)?
    private var activeLogWriter: (any RipLogWriting)?
    private var didFinalizeCancellation = false

    init(environment: RipEnvironment = .production) {
        self.environment = environment
        self.outputURLResolver = OutputURLResolver(fileManager: environment.fileManager)
        self.ripEngine = RipEngine(
            configuration: environment.configuration,
            fileManager: environment.fileManager,
            handBrakeRunner: environment.handBrakeRunner
        )
    }

    var stateSnapshot: RipLifecycleState {
        state
    }

    var suggestedOutputName: String {
        guard let selectedDVD = state.selectedDVD else {
            return "\(Self.fallbackMovieName).\(Self.movieFileExtension)"
        }
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
        updateState { $0.apply(.replaceMountedDVDs(mountedDVDs)) }

        guard let selectedDVD = state.selectedDVD else { return }
        guard !mountedDVDs.contains(selectedDVD) else { return }

        clearDVDSelection()
    }

    @discardableResult
    func chooseDVD(at url: URL) -> Bool {
        guard !state.isEncoding else { return false }

        let access = environment.dvdInputAccessProvider.startAccessingDVD(at: url)

        guard isValidDVD(at: url) else {
            access.stopAccessing()
            clearDVDSelection(statusMessage: AppStrings.chooseVideoTSFolder(directoryName: DVDVolume.videoTSDirectoryName))
            return false
        }

        replaceDVDInputAccess(with: access)
        let dvd = DVDVolume(url: url)
        selectDVD(dvd, statusMessage: AppStrings.readyToRip(url.lastPathComponent))
        return true
    }

    func setOutputURL(_ url: URL) {
        updateState { $0.apply(.setOutputURL(outputURLResolver.normalizedMovieURL(for: url))) }
    }

    func setOutputDirectory(_ url: URL) throws {
        try environment.appSettings.setOutputDirectory(url)

        if let selectedDVD = state.selectedDVD {
            selectDVD(selectedDVD)
        }
    }

    func selectDVD(_ dvd: DVDVolume, outputURL: URL? = nil, statusMessage: String? = nil) {
        let resolvedOutputURL = outputURLResolver.availableURL(
            for: outputURL ?? defaultOutputDirectory.appendingPathComponent(suggestedOutputName(for: dvd))
        )
        let resolvedStatusMessage = statusMessage ?? AppStrings.readyToRip(dvd.name)
        updateState {
            $0.apply(.selectDVD(dvd: dvd, outputURL: resolvedOutputURL, statusMessage: resolvedStatusMessage))
        }
    }

    func startRip(revealOutput: @escaping @MainActor @Sendable (URL) -> Void) async {
        guard !state.isEncoding, ripTask == nil else { return }

        let task = Task { [weak self] in
            guard let self else { return }
            await self.performRip(revealOutput: revealOutput)
        }

        ripTask = task
        await task.value
        ripTask = nil
    }

    func cancelRip() {
        guard state.isEncoding else { return }

        ripTask?.cancel()
        finalizeCancellationIfNeeded(exitCode: nil)
    }

    func cancelRipForWindowCloseOrAppQuit() {
        cancelRip()
        clearDVDInputAccess()
    }

    func ejectCompletedDVD() {
        guard state.canEjectCompletedDVD, let selectedDVD = state.selectedDVD else { return }

        do {
            try environment.dvdDeviceEjector.ejectDVD(at: selectedDVD.url)
        } catch {
            updateState { $0.apply(.setStatusMessage(error.localizedDescription)) }
            return
        }

        clearDVDInputAccess()
        updateState { $0.apply(.resetAfterEject) }
    }

    private func updateState(_ update: (inout RipLifecycleState) -> Void) {
        var updatedState = state
        update(&updatedState)
        state = updatedState
        onStateChange?(updatedState)
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
        updateState { $0.apply(.clearDVDSelection(statusMessage: statusMessage)) }
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
        guard let selectedDVD = state.selectedDVD, let outputURL = state.outputURL else { return }

        didFinalizeCancellation = false
        activeOutputDirectoryAccess = environment.appSettings.startAccessingOutputDirectory()
        defer {
            activeOutputDirectoryAccess?.stopAccessing()
            activeOutputDirectoryAccess = nil
            activeLogWriter = nil
        }

        let resolvedOutputURL = outputURLResolver.availableURL(for: outputURL)
        if resolvedOutputURL != outputURL {
            updateState { $0.apply(.setOutputURL(resolvedOutputURL)) }
        }

        let request = RipRequest(
            input: selectedDVD,
            outputURL: resolvedOutputURL,
            logDirectoryURL: defaultLogDirectory
        )

        for await event in ripEngine.events(for: request) {
            await handleRipEngineEvent(event, outputURL: resolvedOutputURL, revealOutput: revealOutput)
        }
    }

    private func handleRipEngineEvent(
        _ event: RipEngineEvent,
        outputURL: URL,
        revealOutput: @escaping @MainActor @Sendable (URL) -> Void
    ) async {
        switch event {
        case .sessionPrepared(let plan):
            await beginRipSession(plan)
        case .preflightFailed(let message):
            await savePreflightFailure(message)
        case .encodingStarted(let dvd):
            await beginEncoding(dvd)
        case .toolOutput(let output):
            await handleToolOutput(output)
        case .progressUpdated(let progress):
            updateState { $0.apply(.updateProgress(progress)) }
        case .finished(let result):
            await finishRip(result, outputURL: outputURL, revealOutput: revealOutput)
        }
    }

    private func beginRipSession(_ plan: RipPlan) async {
        let input = plan.request.input
        updateState { $0.apply(.prepareRipSession(plan.session, statusMessage: AppStrings.readyToRip(input.name))) }

        let logWriter = FileRipLogWriter()
        activeLogWriter = logWriter
        appendLogWriteErrorIfNeeded(await logWriter.start(log: plan.session.log))

        _ = await appendActiveLogBlankLine("SwiftRip: Selected DVD: \(input.name)")
        _ = await appendActiveLogLine("SwiftRip: Output file: \(plan.request.outputURL.path)")
    }

    private func beginEncoding(_ selectedDVD: DVDVolume) async {
        _ = await appendActiveLogBlankLine("SwiftRip: Started ripping \(selectedDVD.name)")
        updateState { $0.apply(.beginEncoding(statusMessage: AppStrings.ripping(selectedDVD.name))) }
    }

    private func handleToolOutput(_ output: RipToolOutput) async {
        _ = await appendActiveLog(output.text)
    }

    private func finishRip(
        _ result: RipResult,
        outputURL: URL,
        revealOutput: @escaping @MainActor @Sendable (URL) -> Void
    ) async {
        switch result {
        case .completed(let exitCode):
            await finishRipWithOutputPreserved(
                outputURL: outputURL,
                exitCode: exitCode,
                outcome: .completed(revealOutput: revealOutput)
            )
        case .failed(let exitCode):
            await finishRipWithOutputPreserved(outputURL: outputURL, exitCode: exitCode, outcome: .failed)
        case let .outputValidationFailed(exitCode, message):
            await finishRipWithOutputPreserved(
                outputURL: outputURL,
                exitCode: exitCode,
                outcome: .outputValidationFailed(message: message)
            )
        case .canceled(let exitCode):
            finalizeCancellationIfNeeded(exitCode: exitCode)
        case .preflightFailed:
            break
        }
    }

    private func finishRipWithOutputPreserved(
        outputURL: URL,
        exitCode: Int32,
        outcome: RipFinishOutcome
    ) async {
        await appendOutputPreservationLog(outputURL: outputURL, outcome: outcome)

        if case .completed = outcome {
            notifyRipCompleted(outputURL: outputURL)
        }

        let logWriteError = await appendRipOutcomeAndExitCode(
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

    private func appendOutputPreservationLog(outputURL: URL, outcome: RipFinishOutcome) async {
        switch outcome {
        case .completed:
            updateState { $0.mutateActiveRip { $0.protectCompletedOutput() } }
            _ = await appendActiveLogBlankLine("SwiftRip: Rip completed successfully")
            _ = await appendActiveLogLine("Completed output protected from cancellation cleanup: \(outputURL.path)")
        case .failed:
            _ = await appendActiveLogBlankLine("SwiftRip: Rip failed; output preserved for inspection")
            _ = await appendActiveLogLine("Output preserved for inspection: \(outputURL.path)")
        case .outputValidationFailed(let message):
            _ = await appendActiveLogBlankLine("SwiftRip: Output validation failed")
            _ = await appendActiveLogLine(message)
        }
    }

    private func appendRipOutcomeAndExitCode(exitCode: Int32, outcome: String) async -> Error? {
        let outcomeError = await appendActiveLogOutcome(outcome)
        let exitCodeError = await appendActiveLogExitCode(exitCode)
        return outcomeError ?? exitCodeError
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
            updateState { $0.apply(.markCompleted(statusMessage: statusMessage)) }
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
            updateState { $0.apply(.markFailed(statusMessage: statusMessage)) }
            appendLogWriteErrorIfNeeded(logWriteError)
        case .outputValidationFailed(let message):
            notifyRipFailed(outputURL: outputURL, message: message)
            updateState { $0.apply(.markFailed(statusMessage: "\(message) \(AppStrings.logSaved(to: activeLogPath))")) }
            appendLogWriteErrorIfNeeded(logWriteError)
        }
    }

    private func notifyRipCompleted(outputURL: URL) {
        environment.ripNotifier.notifyRipCompleted(
            outputURL: outputURL,
            sound: environment.appSettings.completionSound,
            isNotificationEnabled: environment.appSettings.isCompletionNotificationEnabled
        ) { [weak self] message in
            Task { @MainActor in
                _ = await self?.appendActiveLogBlankLine(message)
            }
        }
    }

    private func notifyRipFailed(outputURL: URL, exitCode: Int32) {
        environment.ripNotifier.notifyRipFailed(
            outputURL: outputURL,
            exitCode: exitCode,
            isNotificationEnabled: environment.appSettings.isCompletionNotificationEnabled
        ) { [weak self] message in
            Task { @MainActor in
                _ = await self?.appendActiveLogBlankLine(message)
            }
        }
    }

    private func notifyRipFailed(outputURL: URL, message: String) {
        environment.ripNotifier.notifyRipFailed(
            outputURL: outputURL,
            message: message,
            isNotificationEnabled: environment.appSettings.isCompletionNotificationEnabled
        ) { [weak self] message in
            Task { @MainActor in
                _ = await self?.appendActiveLogBlankLine(message)
            }
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
            appendActiveLogBlankLineSynchronously("Deleted incomplete output file: \(url.path)")
        } catch {
            appendActiveLogBlankLineSynchronously("Could not delete incomplete output file: \(error.localizedDescription)")
        }
    }

    private func finalizeCancellationIfNeeded(exitCode: Int32?) {
        guard !didFinalizeCancellation else { return }
        guard let activeRip = state.activeRip else { return }
        didFinalizeCancellation = true

        if let exitCode {
            appendActiveLogExitCodeSynchronously(exitCode)
        }

        appendActiveLogBlankLineSynchronously("SwiftRip: User requested stop")

        if activeRip.shouldDeleteOutputOnCancel {
            deleteIncompleteOutputFile(at: activeRip.outputURL)
        }

        appendActiveLogBlankLineSynchronously("Rip stopped by user.")
        appendActiveLogOutcomeSynchronously("Canceled")
        updateState { $0.apply(.markCanceled(statusMessage: AppStrings.ripStopped)) }
    }

    private var activeLogPath: String {
        state.activeRip?.log.url.path ?? state.logFileURL?.path ?? ""
    }

    private func appendLogWriteErrorIfNeeded(_ error: Error?) {
        guard let error else { return }
        updateState {
            $0.apply(.setStatusMessage("\(state.statusMessage) \(AppStrings.couldNotWriteLog(error.localizedDescription))"))
        }
    }

    private func savePreflightFailure(_ message: String) async {
        let lineError = await appendActiveLogLine(message)
        let outcomeError = await appendActiveLogOutcome("Preflight failed")
        updateState { $0.apply(.markFailed(statusMessage: "\(message) \(AppStrings.logSaved(to: activeLogPath))")) }
        appendLogWriteErrorIfNeeded(lineError ?? outcomeError)
    }

    private func appendActiveLog(_ output: String) async -> Error? {
        let appended = appendActiveLogSynchronously { $0.append(output) }
        guard let activeLogWriter else { return nil }
        return await activeLogWriter.append(appended)
    }

    private func appendActiveLogLine(_ line: String) async -> Error? {
        let appended = appendActiveLogSynchronously { $0.appendLine(line) }
        guard let activeLogWriter else { return nil }
        return await activeLogWriter.append(appended)
    }

    private func appendActiveLogBlankLine(_ line: String) async -> Error? {
        let appended = appendActiveLogSynchronously { $0.appendBlankLine(line) }
        guard let activeLogWriter else { return nil }
        return await activeLogWriter.append(appended)
    }

    private func appendActiveLogExitCode(_ exitCode: Int32) async -> Error? {
        let appended = appendActiveLogSynchronously { $0.appendExitCode(exitCode) }
        guard let activeLogWriter else { return nil }
        return await activeLogWriter.append(appended)
    }

    private func appendActiveLogOutcome(_ outcome: String) async -> Error? {
        let appended = appendActiveLogSynchronously { $0.appendOutcome(outcome) }
        guard let activeLogWriter else { return nil }
        return await activeLogWriter.append(appended)
    }

    private func appendActiveLogBlankLineSynchronously(_ line: String) {
        _ = appendActiveLogSynchronously { $0.appendBlankLine(line) }
        _ = saveActiveLogSnapshot()
    }

    private func appendActiveLogExitCodeSynchronously(_ exitCode: Int32) {
        _ = appendActiveLogSynchronously { $0.appendExitCode(exitCode) }
        _ = saveActiveLogSnapshot()
    }

    private func appendActiveLogOutcomeSynchronously(_ outcome: String) {
        _ = appendActiveLogSynchronously { $0.appendOutcome(outcome) }
        _ = saveActiveLogSnapshot()
    }

    private func appendActiveLogSynchronously(_ update: (inout RipLog) -> String) -> String {
        var appendedText = ""
        updateState {
            $0.mutateActiveRip { session in
                appendedText = update(&session.log)
            }
        }
        return appendedText
    }

    private func saveActiveLogSnapshot() -> Error? {
        state.activeRip?.log.save(using: environment.fileManager)
    }
}
