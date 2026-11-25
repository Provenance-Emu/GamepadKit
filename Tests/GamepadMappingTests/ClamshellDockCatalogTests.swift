import GamepadMapping
import XCTest

final class ClamshellDockCatalogTests: XCTestCase {
    func testAutomaticTurnsOnOnlyForAKnownPad() {
        let known = ClamshellDockCatalog.coverPoints(
            mode: .automatic, storedMillimetres: 0, controllerNames: [nil, "8BitDo FlipPad"]
        )
        XCTAssertEqual(known, (38 * ClamshellDockCatalog.pointsPerMillimetre).rounded())
        XCTAssertEqual(
            ClamshellDockCatalog.coverPoints(mode: .automatic, storedMillimetres: 0, controllerNames: ["Xbox"]), 0
        )
    }

    func testAlwaysUsesThePlayersFigureAndOffWins() {
        let always = ClamshellDockCatalog.coverPoints(mode: .always, storedMillimetres: 50, controllerNames: [])
        XCTAssertEqual(always, (50 * ClamshellDockCatalog.pointsPerMillimetre).rounded())
        XCTAssertEqual(
            ClamshellDockCatalog.coverPoints(mode: .off, storedMillimetres: 50, controllerNames: ["FlipPad"]), 0
        )
    }
}
