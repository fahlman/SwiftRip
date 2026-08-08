//
//  SwiftRipLayout.swift
//  SwiftRip
//

import SwiftUI

enum SwiftRipLayout {
    enum MainWindow {
        static let defaultWidth: CGFloat = 520
        static let defaultHeight: CGFloat = 420
        static let badgeScale: CGFloat = 0.14
        static let badgeOffsetScale: CGFloat = 0.02
    }

    enum SettingsWindow {
        static let defaultWidth: CGFloat = 760
        static let defaultHeight: CGFloat = 440
        static let minWidth: CGFloat = 620
        static let minHeight: CGFloat = 360
        static let sidebarMinWidth: CGFloat = 160
        static let sidebarIdealWidth: CGFloat = 190
        static let sidebarMaxWidth: CGFloat = 220
    }
}
