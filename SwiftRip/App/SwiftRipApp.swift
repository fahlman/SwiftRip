//
//  SwiftRipApp.swift
//  SwiftRip
//

import AppKit
import SwiftUI

@main
struct SwiftRipApp: App {

    @NSApplicationDelegateAdaptor(SwiftRipAppDelegate.self) private var appDelegate
    @Environment(\.openWindow) private var openWindow

    private let updateController = AppUpdateController.shared

    private static let aboutWindowID = "about-swiftrip"
    private static let aboutTitle = AppStrings.aboutTitle(appName: RipConfiguration.appName)

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            SwiftRipCommands(updateController: updateController) {
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
