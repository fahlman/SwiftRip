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
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["SWIFTRIP_SUPPRESS_FIRST_RUN_OUTPUT_PROMPT"] = "1"
        app.launch()
        return app
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
