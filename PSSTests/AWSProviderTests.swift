import Foundation
import XCTest
@testable import PSSCore

final class AWSProviderTests: XCTestCase {
    func testEmptyEventListIsOperational() async throws {
        let status = try await fetchFixture("aws-no-events")

        XCTAssertEqual(status.state, .operational)
    }

    func testInvestigationMapsToMinorDisruption() async throws {
        let status = try await fetchFixture("aws-current-events")

        XCTAssertEqual(status.state, .minorDisruption)
    }

    func testUTF8ResponseFallsBackWhenBigEndianDecodingIsNotJSON() async throws {
        let status = try await fetch(data: Data("[]".utf8))

        XCTAssertEqual(status.state, .operational)
    }

    func testMultipleServicesWithIncreasedErrorsMapsToMajorDisruption() async throws {
        let status = try await fetch(data: utf16BigEndianData(#"""
        [{
          "status": "investigating",
          "service_name": "Multiple services",
          "summary": "Increased error rates",
          "event_log": [{"summary": "Investigating", "message": "We are investigating increased errors across multiple services.", "status": 1}]
        }]
        """#))

        XCTAssertEqual(status.state, .majorDisruption)
    }

    func testExplicitServiceDisruptionMapsToOutage() async throws {
        let status = try await fetch(data: utf16BigEndianData(#"""
        [{
          "status": "service disruption",
          "service_name": "Amazon EC2",
          "summary": "Service disruption in US-EAST-1",
          "event_log": [{"summary": "Service disruption", "message": "A service disruption is affecting Amazon EC2.", "status": 1}]
        }]
        """#))

        XCTAssertEqual(status.state, .outage)
    }

    func testMalformedEncodingThrows() async {
        await XCTAssertThrowsErrorAsync {
            _ = try await self.fetch(data: Data([0xFF, 0xFE, 0x00]))
        }
    }

    func testMalformedJSONThrows() async {
        await XCTAssertThrowsErrorAsync {
            _ = try await self.fetch(data: utf16BigEndianData("not json"))
        }
    }

    func testTransportTimeoutPropagates() async {
        await XCTAssertThrowsErrorAsync {
            _ = try await AWSProvider().fetch(using: AWSFailingTransport(error: URLError(.timedOut)))
        }
    }

    private func fetchFixture(_ name: String) async throws -> ServiceStatus {
        let bundle = Bundle(for: Self.self)
        let url = try XCTUnwrap(bundle.url(forResource: name, withExtension: "json"))
        let text = try String(contentsOf: url, encoding: .utf8)
        return try await fetch(data: utf16BigEndianData(text))
    }

    private func fetch(data: Data) async throws -> ServiceStatus {
        try await AWSProvider().fetch(using: AWSStubTransport(data: data, statusCode: 200))
    }

    private func utf16BigEndianData(_ text: String) -> Data {
        text.data(using: .utf16BigEndian)!
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

private struct AWSStubTransport: HTTPTransport {
    let data: Data
    let statusCode: Int

    func data(from url: URL) async throws -> (Data, HTTPURLResponse) {
        (data, HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!)
    }
}

private struct AWSFailingTransport: HTTPTransport {
    let error: Error

    func data(from url: URL) async throws -> (Data, HTTPURLResponse) {
        throw error
    }
}
