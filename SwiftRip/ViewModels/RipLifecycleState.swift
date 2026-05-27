//
//  RipLifecycleState.swift
//  SwiftRip
//

import Foundation

struct RipCommandAvailability: Equatable, Sendable {
    let canChooseDVD: Bool
    let canRip: Bool
    let canStop: Bool
    let canEject: Bool
    let canRevealOutput: Bool
    let canRevealLog: Bool
}

struct RipLifecycleState: Sendable {
    enum Phase: Sendable {
        case idle(statusMessage: String)
        case ready(dvd: DVDVolume, outputURL: URL, statusMessage: String)
        case preflighting(dvd: DVDVolume, outputURL: URL, statusMessage: String)
        case ripping(dvd: DVDVolume, outputURL: URL, progress: Double, statusMessage: String)
        case completed(dvd: DVDVolume, outputURL: URL, logFileURL: URL?, statusMessage: String)
        case failed(dvd: DVDVolume, outputURL: URL, logFileURL: URL?, statusMessage: String)
        case canceled(dvd: DVDVolume, outputURL: URL, logFileURL: URL?, statusMessage: String)
    }

    private(set) var dvdVolumes: [DVDVolume] = []
    private(set) var logFileURL: URL?
    private(set) var activeRip: RipSession?
    private(set) var phase: Phase = .idle(statusMessage: AppStrings.initialStatusMessage)

    var selectedDVD: DVDVolume? {
        switch phase {
        case .idle:
            return nil
        case let .ready(dvd, _, _),
             let .preflighting(dvd, _, _),
             let .ripping(dvd, _, _, _),
             let .completed(dvd, _, _, _),
             let .failed(dvd, _, _, _),
             let .canceled(dvd, _, _, _):
            return dvd
        }
    }

    var hasSelectedDVD: Bool {
        selectedDVD != nil
    }

    var selectedDVDName: String? {
        selectedDVD?.name
    }

    var outputURL: URL? {
        switch phase {
        case .idle:
            return nil
        case let .ready(_, outputURL, _),
             let .preflighting(_, outputURL, _),
             let .ripping(_, outputURL, _, _),
             let .completed(_, outputURL, _, _),
             let .failed(_, outputURL, _, _),
             let .canceled(_, outputURL, _, _):
            return outputURL
        }
    }

    var statusMessage: String {
        switch phase {
        case let .idle(statusMessage),
             let .ready(_, _, statusMessage),
             let .preflighting(_, _, statusMessage),
             let .ripping(_, _, _, statusMessage),
             let .completed(_, _, _, statusMessage),
             let .failed(_, _, _, statusMessage),
             let .canceled(_, _, _, statusMessage):
            return statusMessage
        }
    }

    var isEncoding: Bool {
        if case .preflighting = phase {
            return true
        }

        if case .ripping = phase {
            return true
        }

        return false
    }

    var progress: Double {
        switch phase {
        case .idle, .ready, .preflighting, .failed, .canceled:
            return 0
        case let .ripping(_, _, progress, _):
            return progress
        case .completed:
            return 1
        }
    }

    var canEjectCompletedDVD: Bool {
        if case .completed = phase {
            return true
        }

        return false
    }

    var primaryAction: RipPrimaryAction {
        switch phase {
        case .idle:
            return .chooseDVD
        case .ready, .failed, .canceled:
            return .rip
        case .preflighting, .ripping:
            return .stop
        case .completed:
            return .eject
        }
    }

    var commandAvailability: RipCommandAvailability {
        RipCommandAvailability(
            canChooseDVD: !isEncoding,
            canRip: primaryAction == .rip,
            canStop: primaryAction == .stop,
            canEject: primaryAction == .eject,
            canRevealOutput: outputURL != nil,
            canRevealLog: logFileURL != nil
        )
    }

    mutating func replaceMountedDVDs(_ volumes: [DVDVolume]) {
        dvdVolumes = volumes
    }

    mutating func selectDVD(_ dvd: DVDVolume, outputURL: URL, statusMessage: String) {
        phase = .ready(dvd: dvd, outputURL: outputURL, statusMessage: statusMessage)
    }

    mutating func setOutputURL(_ outputURL: URL) {
        switch phase {
        case .idle, .preflighting, .ripping:
            return
        case let .ready(dvd, _, statusMessage),
             let .completed(dvd, _, _, statusMessage),
             let .failed(dvd, _, _, statusMessage),
             let .canceled(dvd, _, _, statusMessage):
            phase = .ready(dvd: dvd, outputURL: outputURL, statusMessage: statusMessage)
        }
    }

    mutating func clearDVDSelection(statusMessage: String = AppStrings.initialStatusMessage) {
        activeRip = nil
        logFileURL = nil
        phase = .idle(statusMessage: statusMessage)
    }

    mutating func setStatusMessage(_ statusMessage: String) {
        switch phase {
        case .idle:
            phase = .idle(statusMessage: statusMessage)
        case let .ready(dvd, outputURL, _):
            phase = .ready(dvd: dvd, outputURL: outputURL, statusMessage: statusMessage)
        case let .preflighting(dvd, outputURL, _):
            phase = .preflighting(dvd: dvd, outputURL: outputURL, statusMessage: statusMessage)
        case let .ripping(dvd, outputURL, progress, _):
            phase = .ripping(dvd: dvd, outputURL: outputURL, progress: progress, statusMessage: statusMessage)
        case let .completed(dvd, outputURL, logFileURL, _):
            phase = .completed(dvd: dvd, outputURL: outputURL, logFileURL: logFileURL, statusMessage: statusMessage)
        case let .failed(dvd, outputURL, logFileURL, _):
            phase = .failed(dvd: dvd, outputURL: outputURL, logFileURL: logFileURL, statusMessage: statusMessage)
        case let .canceled(dvd, outputURL, logFileURL, _):
            phase = .canceled(dvd: dvd, outputURL: outputURL, logFileURL: logFileURL, statusMessage: statusMessage)
        }
    }

    mutating func prepareRipSession(_ session: RipSession, statusMessage: String) {
        activeRip = session
        logFileURL = session.log.url
        phase = .preflighting(dvd: session.input, outputURL: session.outputURL, statusMessage: statusMessage)
    }

    mutating func beginEncoding(statusMessage: String) {
        guard let activeRip else { return }
        phase = .ripping(dvd: activeRip.input, outputURL: activeRip.outputURL, progress: 0, statusMessage: statusMessage)
    }

    mutating func updateProgress(_ value: Double) {
        guard case let .ripping(dvd, outputURL, _, statusMessage) = phase else { return }
        phase = .ripping(dvd: dvd, outputURL: outputURL, progress: value, statusMessage: statusMessage)
    }

    mutating func markCompleted(statusMessage: String) {
        guard let activeRip else { return }
        phase = .completed(
            dvd: activeRip.input,
            outputURL: activeRip.outputURL,
            logFileURL: activeRip.log.url,
            statusMessage: statusMessage
        )
        self.activeRip = nil
    }

    mutating func markFailed(statusMessage: String) {
        guard let activeRip else { return }
        phase = .failed(
            dvd: activeRip.input,
            outputURL: activeRip.outputURL,
            logFileURL: activeRip.log.url,
            statusMessage: statusMessage
        )
        self.activeRip = nil
    }

    mutating func markCanceled(statusMessage: String) {
        guard let activeRip else { return }
        phase = .canceled(
            dvd: activeRip.input,
            outputURL: activeRip.outputURL,
            logFileURL: activeRip.log.url,
            statusMessage: statusMessage
        )
        self.activeRip = nil
    }

    mutating func returnToReady(statusMessage: String) {
        guard let selectedDVD, let outputURL else {
            setStatusMessage(statusMessage)
            return
        }

        activeRip = nil
        phase = .ready(dvd: selectedDVD, outputURL: outputURL, statusMessage: statusMessage)
    }

    mutating func resetAfterEject() {
        activeRip = nil
        logFileURL = nil
        phase = .idle(statusMessage: AppStrings.initialStatusMessage)
    }

    mutating func mutateActiveRip(_ update: (inout RipSession) -> Void) {
        guard var session = activeRip else { return }
        update(&session)
        activeRip = session
        logFileURL = session.log.url
    }
}
