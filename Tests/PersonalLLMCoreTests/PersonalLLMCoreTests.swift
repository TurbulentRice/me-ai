import XCTest
@testable import PersonalLLMCore

final class PersonalLLMCoreTests: XCTestCase {
    func testVersion() throws {
        XCTAssertEqual(PersonalLLMCore.version, "0.1.0")
    }

    func testInitialization() throws {
        let core = PersonalLLMCore()
        XCTAssertNotNil(core)
    }
}
