import Foundation
import XCTest
@testable import PSSCore

final class FeedProviderTests: XCTestCase {
    func testXAIUsesOnlyActiveGrokItemsAndChoosesHighestSeverity() async throws {
        let status = try await fetchFixture("xai-active-major", kind: .xAI(productPath: "/grok-com/"), service: .grok)

        XCTAssertEqual(status, ServiceStatus(service: .grok, state: .majorDisruption, detail: "Grok Web major incident"))
    }

    func testXAIResolvedAndOtherProductItemsAreOperational() async throws {
        let status = try await fetchFixture("xai-resolved", kind: .xAI(productPath: "/grok-com/"), service: .grok)

        XCTAssertEqual(status, ServiceStatus(service: .grok, state: .operational))
    }

    func testDeepSeekUsesActiveDescriptionAndTitleKeywords() async throws {
        let status = try await fetchFixture("deepseek-active", kind: .flashDuty, service: .deepSeek)

        XCTAssertEqual(status, ServiceStatus(service: .deepSeek, state: .outage, detail: "API availability"))
    }

    func testDeepSeekResolvedItemsWithEscapedHTMLAreOperational() async throws {
        let status = try await fetchFixture("deepseek-resolved", kind: .flashDuty, service: .deepSeek)

        XCTAssertEqual(status, ServiceStatus(service: .deepSeek, state: .operational))
    }

    func testUnrecognizedActiveIncidentIsUnknown() async throws {
        let data = Data("""
        <rss><channel><item>
          <title>Service issue under investigation</title>
          <link>https://status.deepseek.com/incidents/1</link>
          <description>&lt;p&gt;&lt;strong&gt;Status:&lt;/strong&gt; investigating&lt;/p&gt;</description>
        </item></channel></rss>
        """.utf8)
        let provider = FeedProvider(service: .deepSeek, kind: .flashDuty, endpoint: URL(string: "https://example.com/feed.rss")!)

        let status = try await provider.fetch(using: FeedStubTransport(data: data, statusCode: 200))

        XCTAssertEqual(status, ServiceStatus(service: .deepSeek, state: .unknown))
    }

    func testMalformedXMLThrows() async {
        let provider = FeedProvider(service: .grok, kind: .xAI(productPath: "/grok-com/"), endpoint: URL(string: "https://example.com/feed.xml")!)

        await XCTAssertFeedThrowsErrorAsync {
            _ = try await provider.fetch(using: FeedStubTransport(data: Data("<rss><item>".utf8), statusCode: 200))
        }
    }

    func testTimeoutThrows() async {
        let provider = FeedProvider(service: .deepSeek, kind: .flashDuty, endpoint: URL(string: "https://example.com/feed.rss")!)

        await XCTAssertFeedThrowsErrorAsync {
            _ = try await provider.fetch(using: FeedFailingTransport(error: URLError(.timedOut)))
        }
    }

    func testConcreteProvidersUseGrokWebAndDeepSeekFeeds() {
        XCTAssertEqual(FeedProvider.grok.service, .grok)
        XCTAssertEqual(FeedProvider.grok.kind, .xAI(productPath: "/grok-com/"))
        XCTAssertEqual(FeedProvider.grok.endpoint.absoluteString, "https://status.x.ai/feed.xml")
        XCTAssertEqual(FeedProvider.deepSeek.service, .deepSeek)
        XCTAssertEqual(FeedProvider.deepSeek.kind, .flashDuty)
        XCTAssertEqual(FeedProvider.deepSeek.endpoint.absoluteString, "https://status.deepseek.com/feed.rss")
    }

    private func fetchFixture(_ name: String, kind: FeedKind, service: Service) async throws -> ServiceStatus {
        let url = Bundle(for: Self.self).url(forResource: name, withExtension: "xml")!
        let provider = FeedProvider(service: service, kind: kind, endpoint: URL(string: "https://example.com/feed.xml")!)
        return try await provider.fetch(using: FeedStubTransport(data: try Data(contentsOf: url), statusCode: 200))
    }
}

private func XCTAssertFeedThrowsErrorAsync(
    _ expression: () async throws -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        try await expression()
        XCTFail("Expected expression to throw", file: file, line: line)
    } catch {}
}

private struct FeedStubTransport: HTTPTransport {
    let data: Data
    let statusCode: Int

    func data(from url: URL) async throws -> (Data, HTTPURLResponse) {
        (data, HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!)
    }
}

private struct FeedFailingTransport: HTTPTransport {
    let error: Error

    func data(from url: URL) async throws -> (Data, HTTPURLResponse) {
        throw error
    }
}
