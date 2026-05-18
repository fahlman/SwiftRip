//
//  SwiftRipButtonStyle.swift
//  SwiftRip
//
//  Created by Ryan Fahlsing on 5/18/26.
//

import SwiftUI

struct SwiftRipButtonStyle: ButtonStyle {
    enum Prominence {
        case primary
        case secondary
    }

    let prominence: Prominence

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .padding(.horizontal, SwiftRipLayout.Button.horizontalPadding)
            .padding(.vertical, SwiftRipLayout.Button.verticalPadding)
            .foregroundStyle(foregroundStyle)
            .background(backgroundShape(isPressed: configuration.isPressed))
            .overlay(borderShape)
            .contentShape(RoundedRectangle(cornerRadius: SwiftRipLayout.Button.cornerRadius, style: .continuous))
            .opacity(isEnabled ? 1 : 0.45)
    }

    private var foregroundStyle: Color {
        switch prominence {
        case .primary:
            return SwiftRipColors.primaryButtonForeground
        case .secondary:
            return SwiftRipColors.secondaryButtonForeground
        }
    }

    private func backgroundShape(isPressed: Bool) -> some View {
        RoundedRectangle(cornerRadius: SwiftRipLayout.Button.cornerRadius, style: .continuous)
            .fill(backgroundColor(isPressed: isPressed))
    }

    private var borderShape: some View {
        RoundedRectangle(cornerRadius: SwiftRipLayout.Button.cornerRadius, style: .continuous)
            .strokeBorder(prominence == .secondary ? SwiftRipColors.secondaryButtonBorder : Color.clear)
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        switch prominence {
        case .primary:
            return SwiftRipColors.primaryButtonBackground(isPressed: isPressed)
        case .secondary:
            return SwiftRipColors.secondaryButtonBackground(isPressed: isPressed)
        }
    }
}
