//
//  SwiftRipCommands.swift
//  SwiftRip
//

import Sparkle
import SwiftUI

@MainActor
struct SwiftRipCommands: Commands {
    let updaterController: SPUStandardUpdaterController

    @Environment(\.openURL) private var openURL
    @FocusedValue(\.ripCommandActions) private var ripCommandActions

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button(AppStrings.checkForUpdatesTitle) {
                updaterController.checkForUpdates(nil)
            }
        }

        CommandGroup(after: .help) {
            Button(AppStrings.showLicensesTitle) {
                openLicensesFolder()
            }
            .disabled(licensesFolderURL == nil)
        }

        CommandGroup(after: .newItem) {
            Button(AppStrings.chooseDVDTitle) {
                ripCommandActions?.chooseDVD()
            }
            .keyboardShortcut("o", modifiers: .command)
            .disabled(ripCommandActions?.canChooseDVD != true)
        }

        CommandMenu(AppStrings.ripMenuTitle) {
            Button(AppStrings.ripTitle) {
                ripCommandActions?.rip()
            }
            .keyboardShortcut("r", modifiers: .command)
            .disabled(ripCommandActions?.canRip != true)

            Button(AppStrings.stopTitle) {
                ripCommandActions?.stop()
            }
            .keyboardShortcut(".", modifiers: .command)
            .disabled(ripCommandActions?.canStop != true)

            Button(AppStrings.ejectTitle) {
                ripCommandActions?.eject()
            }
            .keyboardShortcut("e", modifiers: .command)
            .disabled(ripCommandActions?.canEject != true)

            Divider()

            Button(AppStrings.revealOutputTitle) {
                ripCommandActions?.revealOutput()
            }
            .disabled(ripCommandActions?.canRevealOutput != true)

            Button(AppStrings.revealLogTitle) {
                ripCommandActions?.revealLog()
            }
            .disabled(ripCommandActions?.canRevealLog != true)
        }
    }

    private func openLicensesFolder() {
        guard let licensesFolderURL else { return }
        openURL(licensesFolderURL)
    }

    private var licensesFolderURL: URL? {
        guard
            let resourceURL = Bundle.main.resourceURL,
            let urls = try? FileManager.default.contentsOfDirectory(
                at: resourceURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ),
            urls.contains(where: { $0.lastPathComponent.hasSuffix("COPYING") })
        else {
            return nil
        }

        return resourceURL
    }
}
