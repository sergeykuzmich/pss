import XCTest
@testable import PSSCore

final class ServiceStateTests: XCTestCase {
    func testEveryStateHasDistinctAccessiblePresentation() {
        XCTAssertEqual(Set(ServiceState.allCases.map(\.label)).count, ServiceState.allCases.count)
        XCTAssertEqual(Set(ServiceState.allCases.map(\.symbolName)).count, ServiceState.allCases.count)
    }

    func testProviderCatalogHasStableOrder() {
        XCTAssertEqual(Service.allCases, [.github, .openAI, .claude, .aws, .grok, .deepSeek, .cursor])
    }

    func testUnknownIsNotAnOutage() {
        XCTAssertNotEqual(ServiceState.unknown.severity, ServiceState.outage.severity)
    }
}
