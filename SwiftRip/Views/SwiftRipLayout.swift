//
//  SwiftRipLayout.swift
//  SwiftRip
//

import SwiftUI

enum SwiftRipLayout {
    enum Button {
        static let cornerRadius: CGFloat = 8
        static let horizontalPadding: CGFloat = 14
        static let verticalPadding: CGFloat = 6
        static let mainWidth: CGFloat = 96
        static let settingsWidth: CGFloat = 96
        static let dialogFooterWidth: CGFloat = 76
    }

    enum MainWindow {
        static let width: CGFloat = 272
        static let height: CGFloat = 262
        static let encodingHeight: CGFloat = height + contentSpacing + statusHeight
        static let contentSpacing: CGFloat = 16
        static let contentPadding: CGFloat = 18
        static let discIconSize: CGFloat = 124
        static let badgeIconSize: CGFloat = 34
        static let badgeOffsetX: CGFloat = 6
        static let badgeOffsetY: CGFloat = 4
        static let discIconFrameWidth: CGFloat = 142
        static let discIconFrameHeight: CGFloat = 134
        static let progressWidth: CGFloat = 180
        static let statusSpacing: CGFloat = 10
        static let statusHeight: CGFloat = 64
    }

    enum SettingsWindow {
        static let width: CGFloat = 640
        static let height: CGFloat = 462
        static let contentPadding: CGFloat = 22
        static let contentSpacing: CGFloat = 14
        static let rowSpacing: CGFloat = 12
        static let headerSpacing: CGFloat = 6
        static let controlSpacing: CGFloat = 12
        static let iconSize: CGFloat = 24
        static let labelWidth: CGFloat = 144
        static let controlIndent: CGFloat = labelWidth + 10
        static let footerVerticalPadding: CGFloat = 14
        static let footerHorizontalPadding: CGFloat = contentPadding
    }

    enum AboutWindow {
        static let width: CGFloat = 520
        static let height: CGFloat = 420
        static let contentSpacing: CGFloat = 18
        static let contentPadding: CGFloat = 24
        static let headerSpacing: CGFloat = 14
        static let titleSpacing: CGFloat = 4
        static let appIconSize: CGFloat = 44
        static let sectionSpacing: CGFloat = 8
        static let buttonTopPadding: CGFloat = 4
    }
}
