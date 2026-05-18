//
//  RipCommandActions.swift
//  SwiftRip
//

import SwiftUI

struct RipCommandActions {
    let availability: RipCommandAvailability
    let chooseDVD: @MainActor () -> Void
    let rip: @MainActor () -> Void
    let stop: @MainActor () -> Void
    let eject: @MainActor () -> Void
    let revealOutput: @MainActor () -> Void
    let revealLog: @MainActor () -> Void

    init(
        availability: RipCommandAvailability,
        chooseDVD: @escaping @MainActor () -> Void,
        rip: @escaping @MainActor () -> Void,
        stop: @escaping @MainActor () -> Void,
        eject: @escaping @MainActor () -> Void,
        revealOutput: @escaping @MainActor () -> Void,
        revealLog: @escaping @MainActor () -> Void
    ) {
        self.availability = availability
        self.chooseDVD = chooseDVD
        self.rip = rip
        self.stop = stop
        self.eject = eject
        self.revealOutput = revealOutput
        self.revealLog = revealLog
    }

    var canChooseDVD: Bool {
        availability.canChooseDVD
    }

    var canRip: Bool {
        availability.canRip
    }

    var canStop: Bool {
        availability.canStop
    }

    var canEject: Bool {
        availability.canEject
    }

    var canRevealOutput: Bool {
        availability.canRevealOutput
    }

    var canRevealLog: Bool {
        availability.canRevealLog
    }

    @MainActor
    func perform(_ action: RipPrimaryAction) {
        switch action {
        case .chooseDVD:
            chooseDVD()
        case .rip:
            rip()
        case .stop:
            stop()
        case .eject:
            eject()
        }
    }
}

private struct RipCommandActionsKey: FocusedValueKey {
    typealias Value = RipCommandActions
}

extension FocusedValues {
    var ripCommandActions: RipCommandActions? {
        get { self[RipCommandActionsKey.self] }
        set { self[RipCommandActionsKey.self] = newValue }
    }
}
