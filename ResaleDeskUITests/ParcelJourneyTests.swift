import XCTest

final class ParcelJourneyTests: XCTestCase {
    func testInventoryToParcelPackingAndOutcome() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset"]
        app.launch()

        // 1. Add item
        app.buttons["inventory.add"].tap()
        let title = app.textFields["item.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        title.tap()
        title.typeText("Camera")
        app.buttons["item.save"].tap()
        XCTAssertTrue(app.staticTexts["Camera"].waitForExistence(timeout: 10))

        // 2. Open parcels, create parcel with item
        app.buttons["parcels.open"].tap()
        app.buttons["parcel.create"].tap()
        let toggleRow = app.switches.matching(NSPredicate(format: "label CONTAINS %@", "Camera")).firstMatch
        XCTAssertTrue(toggleRow.waitForExistence(timeout: 10))
        let nestedSwitch = toggleRow.switches.firstMatch.exists ? toggleRow.switches.firstMatch : toggleRow
        nestedSwitch.tap()
        for _ in 0..<30 {
            if String(describing: nestedSwitch.value).contains("1") { break }
            usleep(100_000)
        }
        XCTAssertTrue(String(describing: nestedSwitch.value).contains("1"))

        let saveParcel = app.buttons["parcel.compose.save"]
        XCTAssertTrue(saveParcel.isEnabled)
        saveParcel.tap()

        // 3. Step through packing checklist
        let parcelRow = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Parcel with 1 item(s)")).firstMatch
        XCTAssertTrue(parcelRow.waitForExistence(timeout: 10))
        parcelRow.tap()

        let step = app.buttons["parcel.step.condition-checked"]
        XCTAssertTrue(step.waitForExistence(timeout: 10))
        step.tap()
        XCTAssertTrue(app.staticTexts["parcel.notice"].waitForExistence(timeout: 10))

        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // 4. Record outcome
        app.buttons["outcomes.open"].tap()
        app.buttons["outcome.record"].tap()

        let itemPicker = app.buttons["outcome.item"]
        XCTAssertTrue(itemPicker.waitForExistence(timeout: 10))
        itemPicker.tap()
        let option = app.buttons["Camera"].firstMatch
        XCTAssertTrue(option.waitForExistence(timeout: 10))
        option.tap()

        let recordBtn = app.buttons["outcome.save"]
        XCTAssertTrue(recordBtn.waitForExistence(timeout: 10))
        recordBtn.tap()

        let outcomeRow = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Camera: Sold")).firstMatch
        XCTAssertTrue(outcomeRow.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["outcome.total"].label.contains("Unknown"))
    }
}
