//
//  RipCommandActions.swift
//  SwiftRip
//

import SwiftUI

struct RipCommandActions {
    let availability: RipCommandAvailability
    let canRip: Bool
    let canStop: Bool
    let canEject: Bool
    let canRevealOutput: Bool
    let canRevealLog: Bool
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
        self.canRip = availability.canRip
        self.canStop = availability.canStop
        self.canEject = availability.canEject
        self.canRevealOutput = availability.canRevealOutput
        self.canRevealLog = availability.canRevealLog
        self.chooseDVD = chooseDVD
        self.rip = rip
        self.stop = stop
        self.eject = eject
        self.revealOutput = revealOutput
        self.revealLog = revealLog
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
