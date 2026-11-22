import XCTest
@testable import BeamCore

final class CoreTests: XCTestCase {
    func testFuzzy() {
        XCTAssertNil(fuzzyScore("xyz", "Safari"))
        XCTAssertNotNil(fuzzyScore("vsc", "Visual Studio Code"))
        XCTAssertGreaterThan(fuzzyScore("saf", "Safari")!, fuzzyScore("saf", "Mail Safety Filter")!)
        XCTAssertGreaterThan(fuzzyScore("ter", "Terminal")!, fuzzyScore("ter", "Contacts Helper")!)
    }

}
