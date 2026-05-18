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
    @StateObject private var viewModel = RipViewModel()
    @State private var isDVDPickerPresented = false

    private static let chooseDVDTitle = "Choose DVD…"
    private static let ripTitle = "Rip"
    private static let stopTitle = "Stop"
    private static let noValidDVDTitle = "No valid DVD"
    private static let opticalDiscIconName = "opticaldisc"
    private static let selectedOpticalDiscIconName = "opticaldisc.fill"
    private static let ripIconName = "arrow.trianglehead.2.clockwise"
    private static let stopIconName = "stop.fill"
    private static let selectedBadgeIconName = "checkmark.circle.fill"
    private static let missingBadgeIconName = "questionmark.circle.fill"

    private enum Layout {
        static let contentSpacing: CGFloat = 16
        static let contentPadding: CGFloat = 18
        static let windowWidth: CGFloat = 272
        static let windowHeight: CGFloat = 300
        static let discIconSize: CGFloat = 104
        static let badgeIconSize: CGFloat = 34
        static let badgeOffsetX: CGFloat = 6
        static let badgeOffsetY: CGFloat = 4
        static let discIconFrameWidth: CGFloat = 122
        static let discIconFrameHeight: CGFloat = 114
        static let primaryButtonWidth: CGFloat = 116
        static let progressWidth: CGFloat = 180
        static let statusSpacing: CGFloat = 10
        static let statusHeight: CGFloat = 38
    }

    private var hasSelectedDVD: Bool {
        viewModel.selectedDVD != nil
    }

    private enum PrimaryButtonState {
        case chooseDVD
        case rip
        case stop

        var title: String {
            switch self {
            case .chooseDVD:
                return ContentView.chooseDVDTitle
            case .rip:
                return ContentView.ripTitle
            case .stop:
                return ContentView.stopTitle
            }
        }

        var systemImage: String {
            switch self {
            case .chooseDVD:
                return ContentView.opticalDiscIconName
            case .rip:
                return ContentView.ripIconName
            case .stop:
                return ContentView.stopIconName
            }
        }
    }

    private var primaryButtonState: PrimaryButtonState {
        if viewModel.isEncoding {
            return .stop
        }

        if !hasSelectedDVD {
            return .chooseDVD
        }

        return .rip
    }

    var body: some View {
        VStack(spacing: Layout.contentSpacing) {
            dvdIcon
            dvdLabel
            primaryButton
            statusSection
        }
        .padding(Layout.contentPadding)
        .frame(width: Layout.windowWidth, height: Layout.windowHeight)
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
        .frame(width: Layout.discIconFrameWidth, height: Layout.discIconFrameHeight)
        .accessibilityElement(children: .combine)
    }

    private var discImage: some View {
        Image(systemName: hasSelectedDVD ? Self.selectedOpticalDiscIconName : Self.opticalDiscIconName)
            .font(.system(size: Layout.discIconSize, weight: .regular))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.secondary)
            .opacity(hasSelectedDVD ? 1 : 0.45)
            .symbolEffect(.rotate.byLayer, options: .repeat(.continuous), isActive: viewModel.isEncoding)
    }

    private var discBadge: some View {
        Image(systemName: hasSelectedDVD ? Self.selectedBadgeIconName : Self.missingBadgeIconName)
            .font(.system(size: Layout.badgeIconSize, weight: .semibold))
            .symbolRenderingMode(.palette)
            .foregroundStyle(hasSelectedDVD ? .white : .black, hasSelectedDVD ? .green : .gray)
            .offset(x: Layout.badgeOffsetX, y: Layout.badgeOffsetY)
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
            Label(primaryButtonState.title, systemImage: primaryButtonState.systemImage)
                .frame(width: Layout.primaryButtonWidth)
        }
        .keyboardShortcut(.defaultAction)
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    private func performPrimaryButtonAction() {
        switch primaryButtonState {
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
        }
    }

    private var statusSection: some View {
        VStack(spacing: Layout.statusSpacing) {
            ProgressView(value: viewModel.progress)
                .frame(width: Layout.progressWidth)

            Text("\(Int(viewModel.progress * 100))%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .opacity(viewModel.isEncoding ? 1 : 0)
        .frame(maxWidth: .infinity)
        .frame(height: Layout.statusHeight)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
