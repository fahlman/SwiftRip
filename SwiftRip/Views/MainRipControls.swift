//
//  MainRipControls.swift
//  SwiftRip
//

import Foundation
import SwiftUI

struct DVDStatusView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let hasSelectedDVD: Bool
    let isEncoding: Bool
    let displayName: String
    let accessibilityValue: String

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .bottomTrailing) {
                discImage
                discBadge
            }
            .frame(
                width: SwiftRipLayout.MainWindow.discIconFrameWidth,
                height: SwiftRipLayout.MainWindow.discIconFrameHeight
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel(AppStrings.dvdStatusAccessibilityLabel)
            .accessibilityValue(accessibilityValue)
            .accessibilityIdentifier("dvdStatus")

            Text(displayName)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("dvdName")
        }
    }

    private var discImage: some View {
        Image(systemName: hasSelectedDVD ? SwiftRipSymbols.selectedOpticalDisc : SwiftRipSymbols.opticalDisc)
            .font(.system(size: SwiftRipLayout.MainWindow.discIconSize, weight: .regular))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(SwiftRipColors.discIcon)
            .opacity(hasSelectedDVD ? 1 : 0.45)
            .symbolEffect(.rotate.byLayer, options: .repeat(.continuous), isActive: isEncoding && !reduceMotion)
    }

    private var discBadge: some View {
        Image(systemName: hasSelectedDVD ? SwiftRipSymbols.selectedBadge : SwiftRipSymbols.missingBadge)
            .font(.system(size: SwiftRipLayout.MainWindow.badgeIconSize, weight: .semibold))
            .symbolRenderingMode(.palette)
            .foregroundStyle(
                hasSelectedDVD ? SwiftRipColors.selectedBadgeForeground : SwiftRipColors.missingBadgeForeground,
                hasSelectedDVD ? SwiftRipColors.selectedBadgeBackground : SwiftRipColors.missingBadgeBackground
            )
            .offset(
                x: SwiftRipLayout.MainWindow.badgeOffsetX,
                y: SwiftRipLayout.MainWindow.badgeOffsetY
            )
    }
}

struct PrimaryRipButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .frame(width: SwiftRipLayout.Button.mainWidth)
        }
        .keyboardShortcut(.defaultAction)
        .buttonStyle(SwiftRipButtonStyle(prominence: .primary))
        .controlSize(.large)
        .accessibilityIdentifier("primaryActionButton")
    }
}

struct RipProgressSection: View {
    let progress: Double

    var body: some View {
        VStack(spacing: SwiftRipLayout.MainWindow.statusSpacing) {
            ProgressView(value: progress)
                .frame(width: SwiftRipLayout.MainWindow.progressWidth)
                .accessibilityLabel(AppStrings.progressAccessibilityLabel)
                .accessibilityValue(AppStrings.percentComplete(progressPercent))
                .accessibilityIdentifier("ripProgress")

            Text("\(progressPercent)%")
                .swiftRipProgressCaption()
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
        .frame(height: SwiftRipLayout.MainWindow.statusHeight)
    }

    private var progressPercent: Int {
        Int(progress * 100)
    }
}

enum FirstRunOutputPermissionPrompter {
    static func isForced(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> Bool {
        AppLaunchConfiguration.isEnabled(
            "SWIFTRIP_FORCE_FIRST_RUN_OUTPUT_PROMPT",
            environment: environment,
            arguments: arguments
        )
    }

    static func isSuppressed(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> Bool {
        if isForced(environment: environment, arguments: arguments) {
            return false
        }

        if AppLaunchConfiguration.isRunningUnderXCTest(environment: environment, arguments: arguments) {
            return true
        }

        return AppLaunchConfiguration.isEnabled(
            "SWIFTRIP_SUPPRESS_FIRST_RUN_OUTPUT_PROMPT",
            environment: environment,
            arguments: arguments
        )
    }
}
