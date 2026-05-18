//
//  RipLifecycleState.swift
//  SwiftRip
//
//  Created by Ryan Fahlsing on 5/18/26.
//

import Foundation

enum RipPrimaryAction {
    case chooseDVD
    case rip
    case stop
    case eject

    var title: String {
        switch self {
        case .chooseDVD:
            return AppStrings.chooseDVDTitle
        case .rip:
            return AppStrings.ripTitle
        case .stop:
            return AppStrings.stopTitle
        case .eject:
            return AppStrings.ejectTitle
        }
    }
}

struct RipLifecycleState {
    enum Phase {
        case idle(statusMessage: String)
        case selected(dvd: DVDVolume, outputURL: URL, statusMessage: String)
        case ripping(dvd: DVDVolume, outputURL: URL, progress: Double, statusMessage: String)
        case completed(dvd: DVDVolume, outputURL: URL, statusMessage: String)
    }

    private(set) var dvdVolumes: [DVDVolume] = []
    private(set) var logFileURL: URL?
    private(set) var phase: Phase = .idle(statusMessage: AppStrings.initialStatusMessage)

    var selectedDVD: DVDVolume? {
        switch phase {
        case .idle:
            return nil
        case let .selected(dvd, _, _),
             let .ripping(dvd, _, _, _),
             let .completed(dvd, _, _):
            return dvd
        }
    }

    var outputURL: URL? {
        switch phase {
        case .idle:
            return nil
        case let .selected(_, outputURL, _),
             let .ripping(_, outputURL, _, _),
             let .completed(_, outputURL, _):
            return outputURL
        }
    }

    var statusMessage: String {
        switch phase {
        case let .idle(statusMessage),
             let .selected(_, _, statusMessage),
             let .ripping(_, _, _, statusMessage),
             let .completed(_, _, statusMessage):
            return statusMessage
        }
    }

    var isEncoding: Bool {
        if case .ripping = phase {
            return true
        }

        return false
    }

    var progress: Double {
        switch phase {
        case .idle, .selected:
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

    var isPrimaryActionAvailable: Bool {
        isEncoding || (selectedDVD != nil && outputURL != nil)
    }

    var primaryAction: RipPrimaryAction {
        switch phase {
        case .idle:
            return .chooseDVD
        case .selected:
            return .rip
        case .ripping:
            return .stop
        case .completed:
            return .eject
        }
    }

    var shouldShowStatusMessage: Bool {
        statusMessage != AppStrings.initialStatusMessage
            && !statusMessage.hasPrefix(AppStrings.readyStatusPrefix)
    }

    mutating func replaceMountedDVDs(_ volumes: [DVDVolume]) {
        dvdVolumes = volumes
    }

    mutating func selectDVD(_ dvd: DVDVolume, outputURL: URL, statusMessage: String) {
        phase = .selected(dvd: dvd, outputURL: outputURL, statusMessage: statusMessage)
    }

    mutating func setOutputURL(_ outputURL: URL) {
        switch phase {
        case .idle, .ripping:
            return
        case let .selected(dvd, _, statusMessage):
            phase = .selected(dvd: dvd, outputURL: outputURL, statusMessage: statusMessage)
        case let .completed(dvd, _, statusMessage):
            phase = .selected(dvd: dvd, outputURL: outputURL, statusMessage: statusMessage)
        }
    }

    mutating func clearDVDSelection(statusMessage: String = AppStrings.initialStatusMessage) {
        phase = .idle(statusMessage: statusMessage)
    }

    mutating func setStatusMessage(_ statusMessage: String) {
        switch phase {
        case .idle:
            phase = .idle(statusMessage: statusMessage)
        case let .selected(dvd, outputURL, _):
            phase = .selected(dvd: dvd, outputURL: outputURL, statusMessage: statusMessage)
        case let .ripping(dvd, outputURL, progress, _):
            phase = .ripping(dvd: dvd, outputURL: outputURL, progress: progress, statusMessage: statusMessage)
        case let .completed(dvd, outputURL, _):
            phase = .completed(dvd: dvd, outputURL: outputURL, statusMessage: statusMessage)
        }
    }

    mutating func setLogFileURL(_ url: URL?) {
        logFileURL = url
    }

    mutating func beginEncoding(statusMessage: String) {
        guard let selectedDVD, let outputURL else { return }
        phase = .ripping(dvd: selectedDVD, outputURL: outputURL, progress: 0, statusMessage: statusMessage)
    }

    mutating func updateProgress(_ value: Double) {
        guard case let .ripping(dvd, outputURL, _, statusMessage) = phase else { return }
        phase = .ripping(dvd: dvd, outputURL: outputURL, progress: value, statusMessage: statusMessage)
    }

    mutating func finishEncoding(statusMessage: String) {
        guard case let .ripping(dvd, outputURL, _, _) = phase else {
            setStatusMessage(statusMessage)
            return
        }

        phase = .selected(dvd: dvd, outputURL: outputURL, statusMessage: statusMessage)
    }

    mutating func completeRip(statusMessage: String) {
        guard let selectedDVD, let outputURL else { return }
        phase = .completed(dvd: selectedDVD, outputURL: outputURL, statusMessage: statusMessage)
    }

    mutating func resetAfterEject() {
        phase = .idle(statusMessage: AppStrings.initialStatusMessage)
    }
}
