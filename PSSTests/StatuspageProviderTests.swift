import Foundation
import XCTest
@testable import PSSCore

final class StatuspageProviderTests: XCTestCase {
    func testNoneMapsToOperational() async throws {
        let status = try await fetchFixture("statuspage-none")
        XCTAssertEqual(status.state, .operational)
    }

    func testMaintenanceMapsToMaintenance() async throws {
        let status = try await fetch(data: Data(#"{"status":{"indicator":"maintenance","description":"Scheduled maintenance"}}"#.utf8))
        XCTAssertEqual(status.state, ServiceState.maintenance)
    }

    func testMinorMapsToMinorDisruption() async throws {
        let status = try await fetchFixture("statuspage-minor")
        XCTAssertEqual(status.state, .minorDisruption)
    }

    func testMajorMapsToMajorDisruption() async throws {
        let status = try await fetchFixture("statuspage-major")
        XCTAssertEqual(status.state, .majorDisruption)
    }

    func testCriticalMapsToOutage() async throws {
        let status = try await fetchFixture("statuspage-critical")
        XCTAssertEqual(status.state, .outage)
    }

    func testUnknownIndicatorMapsToUnknown() async throws {
        let status = try await fetch(data: Data(#"{"status":{"indicator":"unrecognized","description":"New status"}}"#.utf8))
        XCTAssertEqual(status.state, ServiceState.unknown)
    }

    func testNonSuccessResponseThrows() async {
        let provider = StatuspageProvider(service: .github, endpoint: URL(string: "https://example.com/status")!)

        await XCTAssertThrowsErrorAsync {
            _ = try await provider.fetch(using: StubTransport(data: Data(), statusCode: 503))
        }
    }

    func testMalformedJSONThrows() async {
        let provider = StatuspageProvider(service: .github, endpoint: URL(string: "https://example.com/status")!)

        await XCTAssertThrowsErrorAsync {
            _ = try await provider.fetch(using: StubTransport(data: Data("not json".utf8), statusCode: 200))
        }
    }

    func testTransportTimeoutThrows() async {
        let provider = StatuspageProvider(service: .github, endpoint: URL(string: "https://example.com/status")!)

        await XCTAssertThrowsErrorAsync {
            _ = try await provider.fetch(using: FailingTransport(error: URLError(.timedOut)))
        }
    }

    func testConcreteProvidersHaveExpectedServicesAndEndpoints() {
        let providers = [
            StatuspageProvider.github,
            StatuspageProvider.openAI,
            StatuspageProvider.claude,
            StatuspageProvider.cursor
        ]

        XCTAssertEqual(providers.map(\.service), [.github, .openAI, .claude, .cursor])
        XCTAssertEqual(providers.map(\.endpoint.absoluteString), [
            "https://www.githubstatus.com/api/v2/status.json",
            "https://status.openai.com/api/v2/status.json",
            "https://status.claude.com/api/v2/status.json",
            "https://status.cursor.com/api/v2/status.json"
        ])
    }

    private func fetchFixture(_ name: String) async throws -> ServiceStatus {
        try await fetch(data: fixture(name))
    }

    private func fetch(data: Data) async throws -> ServiceStatus {
        let provider = StatuspageProvider(service: .claude, endpoint: URL(string: "https://example.com/status")!)
        return try await provider.fetch(using: StubTransport(data: data, statusCode: 200))
    }

    private func fixture(_ name: String) -> Data {
        let bundle = Bundle(for: Self.self)
        let url = bundle.url(forResource: name, withExtension: "json")!
        return try! Data(contentsOf: url)
    }
}

private struct StubTransport: HTTPTransport {
    let data: Data
    let statusCode: Int

    func data(from url: URL) async throws -> (Data, HTTPURLResponse) {
        (data, HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!)
    }
}

private struct FailingTransport: HTTPTransport {
    let error: Error

    func data(from url: URL) async throws -> (Data, HTTPURLResponse) {
        throw error
    }
}

private func XCTAssertThrowsErrorAsync(
    _ expression: () async throws -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        try await expression()
        XCTFail("Expected expression to throw", file: file, line: line)
    } catch {}
}
