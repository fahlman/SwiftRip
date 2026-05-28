//
//  RipViewModel.swift
//  SwiftRip
//

import Foundation
import Observation

@MainActor
@Observable
final class RipViewModel {
    static let initialStatusMessage = RipCoordinator.initialStatusMessage

    @ObservationIgnored
    private let coordinator: RipCoordinator

    private var state: RipLifecycleState

    init(environment: RipEnvironment = .production) {
        let coordinator = RipCoordinator(environment: environment)
        self.coordinator = coordinator
        self.state = coordinator.stateSnapshot
        coordinator.onStateChange = { [weak self] state in
            self?.state = state
        }
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
        selectedDVDName ?? AppStrings.noValidDVDTitle
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
        coordinator.suggestedOutputName
    }

    var defaultOutputDirectory: URL {
        coordinator.defaultOutputDirectory
    }

    var needsOutputDirectoryPermission: Bool {
        coordinator.needsOutputDirectoryPermission
    }

    var hasAcknowledgedCurrentUsageNotice: Bool {
        coordinator.hasAcknowledgedCurrentUsageNotice
    }

    var defaultLogDirectory: URL {
        coordinator.defaultLogDirectory
    }

    func refreshDVDs() {
        coordinator.refreshDVDs()
    }

    @discardableResult
    func chooseDVD(at url: URL) -> Bool {
        coordinator.chooseDVD(at: url)
    }

    func setOutputURL(_ url: URL) {
        coordinator.setOutputURL(url)
    }

    func setOutputDirectory(_ url: URL) throws {
        try coordinator.setOutputDirectory(url)
    }

    func acknowledgeCurrentUsageNotice() {
        coordinator.acknowledgeCurrentUsageNotice()
    }

    func selectDVD(_ dvd: DVDVolume, outputURL: URL? = nil, statusMessage: String? = nil) {
        coordinator.selectDVD(dvd, outputURL: outputURL, statusMessage: statusMessage)
    }

    func startRip(revealOutput: @escaping @MainActor @Sendable (URL) -> Void) async {
        await coordinator.startRip(revealOutput: revealOutput)
    }

    func cancelRip() {
        coordinator.cancelRip()
    }

    func cancelRipForWindowCloseOrAppQuit() {
        coordinator.cancelRipForWindowCloseOrAppQuit()
    }

    func ejectCompletedDVD() {
        coordinator.ejectCompletedDVD()
    }
}
