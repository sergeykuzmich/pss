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

    func testDecodingNormalizesMissingAndDuplicateServiceStatuses() throws {
        let payload = """
        {
          "updatedAt": 0,
          "statuses": [
            { "service": "github", "state": "operational" },
            { "service": "github", "state": "outage" }
          ]
        }
        """.data(using: .utf8)!

        let snapshot = try JSONDecoder().decode(StatusSnapshot.self, from: payload)

        XCTAssertEqual(snapshot.statuses.map(\.service), Service.allCases)
        XCTAssertEqual(snapshot.statuses.first?.state, .operational)
        XCTAssertTrue(snapshot.statuses.dropFirst().allSatisfy { $0.state == .unknown })
    }
}
