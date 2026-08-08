//
//  SwiftRipTextStyle.swift
//  SwiftRip
//

import SwiftUI

private struct SwiftRipProgressCaptionStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.caption.monospacedDigit())
            .foregroundStyle(SwiftRipColors.secondaryText)
    }
}

extension View {
    func swiftRipProgressCaption() -> some View {
        modifier(SwiftRipProgressCaptionStyle())
    }
}
