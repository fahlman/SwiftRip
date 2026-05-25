//
//  SwiftRipCommands.swift
//  SwiftRip
//

import SwiftUI

struct SwiftRipCommands: Commands {
    let showAbout: @MainActor () -> Void

    @FocusedValue(\.ripCommandActions) private var ripCommandActions

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button(AppStrings.aboutTitle(appName: RipConfiguration.appName)) {
                showAbout()
            }
        }

        CommandGroup(replacing: .newItem) {
            Button(AppStrings.chooseDVDTitle) {
                ripCommandActions?.chooseDVD()
            }
            .keyboardShortcut("o", modifiers: .command)
            .disabled(ripCommandActions?.canChooseDVD != true)
        }

        CommandGroup(replacing: .undoRedo) {}
        CommandGroup(replacing: .pasteboard) {}
        CommandGroup(replacing: .toolbar) {}
        CommandGroup(replacing: .sidebar) {}

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
}
