//
//  SwiftRipColors.swift
//  SwiftRip
//

import SwiftUI

enum SwiftRipColors {
    static let primaryButtonForeground = Color.white
    static let secondaryButtonForeground = Color.primary
    static let secondaryButtonBorder = Color.secondary.opacity(0.22)

    static let secondaryText = Color.secondary
    static let discIcon = Color.secondary
    static let selectedBadgeForeground = Color.white
    static let selectedBadgeBackground = Color.green
    static let missingBadgeForeground = Color.black
    static let missingBadgeBackground = Color.gray
    static let folderIcon = Color.blue
    static let errorText = Color.red

    static func primaryButtonBackground(isPressed: Bool) -> Color {
        isPressed ? Color.accentColor.opacity(0.82) : Color.accentColor
    }

    static func secondaryButtonBackground(isPressed: Bool) -> Color {
        isPressed ? Color.secondary.opacity(0.24) : Color.secondary.opacity(0.14)
    }
}
