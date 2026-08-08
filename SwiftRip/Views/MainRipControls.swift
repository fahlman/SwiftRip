//
//  MainRipControls.swift
//  SwiftRip
//

import Foundation
import SwiftUI

struct DVDStatusView: View {
    let hasSelectedDVD: Bool
    let isEncoding: Bool
    let progress: Double
    let remainingTimeText: String?
    let displayName: String
    let accessibilityValue: String

    var body: some View {
        VStack {
            GeometryReader { proxy in
                let discLength = min(proxy.size.width, proxy.size.height)

                ZStack(alignment: .bottomTrailing) {
                    discImage
                        .frame(width: discLength, height: discLength)

                    if !isEncoding {
                        discBadge(discLength: discLength)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(AppStrings.dvdStatusAccessibilityLabel)
                .accessibilityValue(accessibilityValue)
                .accessibilityIdentifier("dvdStatus")
            }
            .layoutPriority(1)

            VStack {
                Text(displayName)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .minimumScaleFactor(0.5)
                    .allowsTightening(true)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("dvdName")

                if isEncoding {
                    RipProgressSection(
                        progress: clampedProgress,
                        remainingTimeText: remainingTimeText
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var discImage: some View {
        Image(systemName: hasSelectedDVD ? SwiftRipSymbols.selectedOpticalDisc : SwiftRipSymbols.opticalDisc)
            .resizable()
            .scaledToFit()
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(hasSelectedDVD ? SwiftRipColors.selectedDiscIcon : SwiftRipColors.discIcon)
    }

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    private func discBadge(discLength: CGFloat) -> some View {
        let badgeLength = discLength * SwiftRipLayout.MainWindow.badgeScale
        let badgeOffset = discLength * SwiftRipLayout.MainWindow.badgeOffsetScale

        return Image(systemName: hasSelectedDVD ? SwiftRipSymbols.selectedBadge : SwiftRipSymbols.missingBadge)
            .resizable()
            .scaledToFit()
            .symbolRenderingMode(.palette)
            .foregroundStyle(
                hasSelectedDVD ? SwiftRipColors.selectedBadgeForeground : SwiftRipColors.missingBadgeForeground,
                hasSelectedDVD ? SwiftRipColors.selectedBadgeBackground : SwiftRipColors.missingBadgeBackground
            )
            .frame(width: badgeLength, height: badgeLength)
            .offset(
                x: badgeOffset,
                y: badgeOffset
            )
    }
}

struct RipProgressSection: View {
    let progress: Double
    let remainingTimeText: String?

    var body: some View {
        VStack {
            ProgressView(value: progress)
                .accessibilityLabel(AppStrings.progressAccessibilityLabel)
                .accessibilityValue(AppStrings.percentComplete(progressPercent))
                .accessibilityIdentifier("ripProgress")

            if let remainingTimeText {
                Text(remainingTimeText)
                    .swiftRipProgressCaption()
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("ripRemainingTime")
            }
        }
    }

    private var progressPercent: Int {
        Int(progress * 100)
    }
}

struct RipToolbar: ToolbarContent {
    let actions: RipCommandActions

    var body: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            ControlGroup {
                toolbarButton(
                    title: AppStrings.chooseDVDTitle,
                    label: AppStrings.ripLogFallbackDVDName,
                    systemImage: SwiftRipSymbols.chooseDVD,
                    accessibilityIdentifier: "chooseDVDToolbarButton",
                    isEnabled: actions.canChooseDVD,
                    action: actions.chooseDVD
                )

                toolbarButton(
                    title: AppStrings.ejectTitle,
                    label: AppStrings.ejectTitle,
                    systemImage: SwiftRipSymbols.eject,
                    accessibilityIdentifier: "ejectToolbarButton",
                    isEnabled: actions.canEject,
                    action: actions.eject
                )
            }
        }

        ToolbarItem(placement: .primaryAction) {
            ControlGroup {
                toolbarButton(
                    title: AppStrings.ripTitle,
                    label: AppStrings.ripTitle,
                    systemImage: SwiftRipSymbols.rip,
                    accessibilityIdentifier: "ripToolbarButton",
                    isEnabled: actions.canRip,
                    action: actions.rip
                )

                toolbarButton(
                    title: AppStrings.stopTitle,
                    label: AppStrings.stopTitle,
                    systemImage: SwiftRipSymbols.stop,
                    accessibilityIdentifier: "stopToolbarButton",
                    isEnabled: actions.canStop,
                    action: actions.stop
                )
            }
        }
    }

    private func toolbarButton(
        title: String,
        label: String,
        systemImage: String,
        accessibilityIdentifier: String,
        isEnabled: Bool,
        action: @escaping @MainActor () -> Void
    ) -> some View {
        Button(action: action) {
            Label(label, systemImage: systemImage)
        }
        .disabled(!isEnabled)
        .help(title)
        .accessibilityLabel(title)
        .accessibilityIdentifier(accessibilityIdentifier)
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
