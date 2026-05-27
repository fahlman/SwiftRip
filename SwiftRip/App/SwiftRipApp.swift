//
//  SwiftRipApp.swift
//  SwiftRip
//

import AppKit
import Sparkle
import SwiftUI

@main
struct SwiftRipApp: App {

    @NSApplicationDelegateAdaptor(SwiftRipAppDelegate.self) private var appDelegate
    @Environment(\.openWindow) private var openWindow
    private let updaterController: SPUStandardUpdaterController

    private static let aboutWindowID = "about-swiftrip"
    private static let aboutTitle = AppStrings.aboutTitle(appName: RipConfiguration.appName)

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(
            width: SwiftRipLayout.MainWindow.width,
            height: SwiftRipLayout.MainWindow.height
        )
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .commands {
            SwiftRipCommands(updaterController: updaterController) {
                openWindow(id: Self.aboutWindowID)
            }
        }

        Settings {
            SettingsView()
        }

        Window(Self.aboutTitle, id: Self.aboutWindowID) {
            AboutSwiftRipView()
        }
        .commandsRemoved()
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}

@MainActor
final class SwiftRipAppDelegate: NSObject, NSApplicationDelegate {

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let coordinator = RipInterruptionCoordinator.shared

        guard coordinator.shouldConfirmAppQuit else {
            return .terminateNow
        }

        coordinator.requestAppQuitConfirmation()
        return .terminateCancel
    }
}
