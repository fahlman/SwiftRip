//
//  SwiftRipViewModifiers.swift
//  SwiftRip
//

import SwiftUI

private struct SwiftRipWindowFrameModifier: ViewModifier {
    let width: CGFloat
    let height: CGFloat

    func body(content: Content) -> some View {
        content.frame(width: width, height: height)
    }
}

private struct SwiftRipDialogFooterPaddingModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, SwiftRipLayout.SettingsWindow.footerHorizontalPadding)
            .padding(.vertical, SwiftRipLayout.SettingsWindow.footerVerticalPadding)
    }
}

extension View {
    func swiftRipWindowFrame(width: CGFloat, height: CGFloat) -> some View {
        modifier(SwiftRipWindowFrameModifier(width: width, height: height))
    }

    func swiftRipDialogFooterPadding() -> some View {
        modifier(SwiftRipDialogFooterPaddingModifier())
    }
}
