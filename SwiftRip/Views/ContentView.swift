//
//  ContentView.swift
//  SwiftRip
//
//  Created by Ryan Fahlsing on 5/16/26.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var viewModel = RipViewModel()
    @State private var isDVDPickerPresented = false

    private static let chooseDVDTitle = AppStrings.chooseDVDTitle
    private static let noValidDVDTitle = AppStrings.noValidDVDTitle

    private var hasSelectedDVD: Bool {
        viewModel.selectedDVD != nil
    }

    var body: some View {
        VStack(spacing: SwiftRipLayout.MainWindow.contentSpacing) {
            dvdIcon
            dvdLabel
            primaryButton
            statusSection
        }
        .padding(SwiftRipLayout.MainWindow.contentPadding)
        .swiftRipWindowFrame(width: SwiftRipLayout.MainWindow.width, height: SwiftRipLayout.MainWindow.height)
        .fixedSize()
        .fileImporter(
            isPresented: $isDVDPickerPresented,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                viewModel.chooseDVD(at: url)
            }
        }
        .fileDialogDefaultDirectory(URL(fileURLWithPath: "/Volumes", isDirectory: true))
        .fileDialogConfirmationLabel(Self.chooseDVDTitle)
        .onDisappear {
            viewModel.cancelRip()
        }
    }

    private var dvdIcon: some View {
        ZStack(alignment: .bottomTrailing) {
            discImage
            discBadge
        }
        .frame(
            width: SwiftRipLayout.MainWindow.discIconFrameWidth,
            height: SwiftRipLayout.MainWindow.discIconFrameHeight
        )
        .accessibilityElement(children: .combine)
    }

    private var discImage: some View {
        Image(systemName: hasSelectedDVD ? SwiftRipSymbols.selectedOpticalDisc : SwiftRipSymbols.opticalDisc)
            .font(.system(size: SwiftRipLayout.MainWindow.discIconSize, weight: .regular))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(SwiftRipColors.discIcon)
            .opacity(hasSelectedDVD ? 1 : 0.45)
            .symbolEffect(.rotate.byLayer, options: .repeat(.continuous), isActive: viewModel.isEncoding)
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

    private var dvdLabel: some View {
        VStack(spacing: 4) {
            Text(viewModel.selectedDVD?.name ?? Self.noValidDVDTitle)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity)
        }
    }

    private var primaryButton: some View {
        Button {
            performPrimaryButtonAction()
        } label: {
            Text(viewModel.primaryAction.title)
                .frame(width: SwiftRipLayout.Button.mainWidth)
        }
        .keyboardShortcut(.defaultAction)
        .buttonStyle(SwiftRipButtonStyle(prominence: .primary))
        .controlSize(.large)
    }

    private func performPrimaryButtonAction() {
        switch viewModel.primaryAction {
        case .chooseDVD:
            isDVDPickerPresented = true
        case .rip:
            Task {
                await viewModel.startRip { outputURL in
                    NSWorkspace.shared.activateFileViewerSelecting([outputURL])
                }
            }
        case .stop:
            viewModel.cancelRip()
        case .eject:
            viewModel.ejectCompletedDVD()
        }
    }

    private var statusSection: some View {
        VStack(spacing: SwiftRipLayout.MainWindow.statusSpacing) {
            ProgressView(value: viewModel.progress)
                .frame(width: SwiftRipLayout.MainWindow.progressWidth)

            Text("\(Int(viewModel.progress * 100))%")
                .swiftRipProgressCaption()
        }
        .opacity(viewModel.isEncoding ? 1 : 0)
        .frame(maxWidth: .infinity)
        .frame(height: SwiftRipLayout.MainWindow.statusHeight)
    }
}

#Preview {
    ContentView()
}
