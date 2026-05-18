//
//  RipPrimaryAction.swift
//  SwiftRip
//
//  Created by Ryan Fahlsing on 5/18/26.
//

import Foundation

enum RipPrimaryAction: Sendable {
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
