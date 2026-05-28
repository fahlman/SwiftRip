//
//  SwiftRipUITests.swift
//  SwiftRipUITests
//

import XCTest

final class SwiftRipUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAccessibilitySurfacesAndMenus() throws {
        let app = launchApp()

        XCTAssertTrue(element("primaryActionButton", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(element("dvdStatus", in: app).exists)
        XCTAssertTrue(element("dvdName", in: app).exists)

        app.typeKey(",", modifierFlags: .command)

        XCTAssertTrue(element("settingsWindow", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Output Location:"].exists)
        XCTAssertTrue(app.staticTexts["Filename Format:"].exists)
        XCTAssertTrue(app.staticTexts["Completion"].exists)
        XCTAssertTrue(app.staticTexts["Sound:"].exists)
        XCTAssertTrue(app.checkBoxes["Show notification when finished"].exists)
        XCTAssertTrue(app.checkBoxes["Reveal completed file in Finder"].exists)
        XCTAssertTrue(app.checkBoxes["Eject DVD after successful rip"].exists)
        XCTAssertTrue(app.buttons["Change…"].exists)
        XCTAssertTrue(app.buttons["OK"].exists)

        app.buttons["OK"].click()

        assertAppMenuExposesItem("About SwiftRip", in: app)
        app.typeKey(.escape, modifierFlags: [])

        openMenu("File", in: app)
        XCTAssertTrue(app.menuItems["Choose DVD…"].exists)
        app.typeKey(.escape, modifierFlags: [])

        openMenu("Rip", in: app)
        XCTAssertTrue(app.menuItems["Rip"].exists)
        XCTAssertTrue(app.menuItems["Stop"].exists)
        XCTAssertTrue(app.menuItems["Eject"].exists)
        XCTAssertTrue(app.menuItems["Reveal Output in Finder"].exists)
        XCTAssertTrue(app.menuItems["Reveal Log in Finder"].exists)
        app.typeKey(.escape, modifierFlags: [])
    }

    @MainActor
    func testFirstRunOutputPermissionPromptCanBeCanceled() throws {
        let app = launchApp(environment: [
            "SWIFTRIP_FORCE_FIRST_RUN_OUTPUT_PROMPT": "1"
        ])

        let openPanel = app.dialogs["open-panel"]
        XCTAssertTrue(openPanel.buttons["Cancel"].waitForExistence(timeout: 5))

        openPanel.buttons["Cancel"].click()
        XCTAssertTrue(element("primaryActionButton", in: app).waitForExistence(timeout: 5))
    }

    @MainActor
    func testInvalidDVDSelectionShowsWarning() throws {
        let invalidDVDURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftRipUITests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: invalidDVDURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: invalidDVDURL) }

        let app = launchApp(environment: [
            "SWIFTRIP_SUPPRESS_FIRST_RUN_OUTPUT_PROMPT": "1"
        ])

        cancelOutputPromptIfPresent(in: app)
        element("primaryActionButton", in: app).click()
        chooseFolder(invalidDVDURL, confirmationButtons: ["Choose DVD…", "Choose DVD", "Open"], in: app)

        XCTAssertTrue(app.staticTexts["Not a Video DVD"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Choose a folder that contains a VIDEO_TS directory."].exists)
        app.dialogs.firstMatch.buttons["OK"].click()
    }

    @MainActor
    private func launchApp(environment: [String: String] = [
        "SWIFTRIP_SUPPRESS_FIRST_RUN_OUTPUT_PROMPT": "1"
    ]) -> XCUIApplication {
        let app = XCUIApplication()
        var launchEnvironment = [
            "SWIFTRIP_APP_SETTINGS_SUITE": "SwiftRipUITests.\(UUID().uuidString)",
            "SWIFTRIP_SUPPRESS_USAGE_NOTICE": "1",
            "SWIFTRIP_SUPPRESS_FIRST_RUN_OUTPUT_PROMPT": "1"
        ]
        launchEnvironment.merge(environment) { _, newValue in newValue }

        for (key, value) in launchEnvironment {
            app.launchEnvironment[key] = value
            app.launchArguments.append("--\(key)=\(value)")
            app.launchArguments.append("--\(key)")
            app.launchArguments.append(value)
            app.launchArguments.append("-\(key)")
            app.launchArguments.append(value)
        }
        app.launch()
        return app
    }

    @MainActor
    private func chooseFolder(_ url: URL, confirmationButtons: [String], in app: XCUIApplication) {
        app.typeKey("g", modifierFlags: [.command, .shift])

        let goToFolderSheet = app.sheets.firstMatch
        XCTAssertTrue(goToFolderSheet.waitForExistence(timeout: 5))

        let destinationField = firstExistingTextInput(in: goToFolderSheet)
        XCTAssertTrue(destinationField.waitForExistence(timeout: 5))
        destinationField.typeText(url.path)
        app.typeKey(.return, modifierFlags: [])

        let openPanel = app.sheets["open-panel"]
        XCTAssertTrue(openPanel.waitForExistence(timeout: 5))

        let confirmationButton = firstExistingButton(named: confirmationButtons, in: openPanel)
        XCTAssertTrue(confirmationButton.waitForExistence(timeout: 5))
        confirmationButton.click()
    }

    @MainActor
    private func cancelOutputPromptIfPresent(in app: XCUIApplication) {
        let cancelButton = app.buttons["Cancel"]
        if cancelButton.waitForExistence(timeout: 1) {
            cancelButton.click()
        }
    }

    @MainActor
    private func firstExistingButton(named names: [String], in element: XCUIElement) -> XCUIElement {
        for name in names {
            let button = element.buttons[name]
            if button.exists || button.waitForExistence(timeout: 1) {
                return button
            }
        }

        return element.buttons[names[0]]
    }

    @MainActor
    private func firstExistingTextInput(in element: XCUIElement) -> XCUIElement {
        let textField = element.textFields.firstMatch
        if textField.exists || textField.waitForExistence(timeout: 1) {
            return textField
        }

        return element.comboBoxes.firstMatch
    }

    @MainActor
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    @MainActor
    private func assertAppMenuExposesItem(_ title: String, in app: XCUIApplication) {
        let menu = openMenu("SwiftRip", in: app)
        let menuItem = menu.menuItems[title]
        XCTAssertTrue(menuItem.waitForExistence(timeout: 5))
    }

    @MainActor
    @discardableResult
    private func openMenu(_ title: String, in app: XCUIApplication) -> XCUIElement {
        let menu = app.menuBars.menuBarItems[title]
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        menu.click()
        return menu
    }
}
