//
//  SwiftRipTextStyle.swift
//  SwiftRip
//

import SwiftUI

private struct SwiftRipSectionTitleStyle: ViewModifier {
    func body(content: Content) -> some View {
        content.font(.headline)
    }
}

private struct SwiftRipSecondaryTextStyle: ViewModifier {
    func body(content: Content) -> some View {
        content.foregroundStyle(SwiftRipColors.secondaryText)
    }
}

private struct SwiftRipSettingsLabelStyle: ViewModifier {
    func body(content: Content) -> some View {
        content.font(.body.weight(.semibold))
    }
}

private struct SwiftRipProgressCaptionStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.caption.monospacedDigit())
            .foregroundStyle(SwiftRipColors.secondaryText)
    }
}

extension View {
    func swiftRipSectionTitle() -> some View {
        modifier(SwiftRipSectionTitleStyle())
    }

    func swiftRipSecondaryText() -> some View {
        modifier(SwiftRipSecondaryTextStyle())
    }

    func swiftRipSettingsLabel() -> some View {
        modifier(SwiftRipSettingsLabelStyle())
    }

    func swiftRipProgressCaption() -> some View {
        modifier(SwiftRipProgressCaptionStyle())
    }
}
