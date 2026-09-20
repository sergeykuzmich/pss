import Foundation
import XCTest
@testable import PSSCore

final class StatusClientTests: XCTestCase {
    func testFetchAllRunsProvidersConcurrently() async {
        let tracker = ConcurrencyTracker()
        let providers: [any StatusProvider] = [
            DelayedProvider(service: .github, tracker: tracker),
            DelayedProvider(service: .openAI, tracker: tracker)
        ]

        _ = await StatusClient(providers: providers).fetchAll()

        let maximum = await tracker.maximumConcurrentFetches
        XCTAssertEqual(maximum, 2)
    }

    func testFetchAllReturnsStatusesInCatalogOrder() async {
        let client = StatusClient(providers: [
            ImmediateProvider(service: .cursor, state: .maintenance),
            ImmediateProvider(service: .github, state: .operational)
        ])

        let snapshot = await client.fetchAll(at: Date(timeIntervalSinceReferenceDate: 100))

        XCTAssertEqual(snapshot.updatedAt, Date(timeIntervalSinceReferenceDate: 100))
        XCTAssertEqual(snapshot.statuses.map(\.service), Service.allCases)
        XCTAssertEqual(snapshot.statuses.first?.state, .operational)
        XCTAssertEqual(snapshot.statuses.last?.state, .maintenance)
    }

    func testFetchAllConvertsProviderFailuresToUnknown() async {
        let snapshot = await StatusClient(providers: [
            ImmediateProvider(service: .github, state: .operational),
            FailingProvider(service: .openAI)
        ]).fetchAll()

        XCTAssertEqual(snapshot.statuses.first(where: { $0.service == .github })?.state, .operational)
        XCTAssertEqual(snapshot.statuses.first(where: { $0.service == .openAI })?.state, .unknown)
    }

    func testFetchAllIncludesEveryServiceExactlyOnce() async {
        let snapshot = await StatusClient(providers: [
            ImmediateProvider(service: .github, state: .operational),
            ImmediateProvider(service: .github, state: .outage)
        ]).fetchAll()

        XCTAssertEqual(snapshot.statuses.map(\.service), Service.allCases)
        XCTAssertEqual(Set(snapshot.statuses.map(\.service)).count, Service.allCases.count)
    }

    func testFetchAllUsesFirstConfiguredProviderForDelayedDuplicate() async {
        let snapshot = await StatusClient(providers: [
            DelayedStateProvider(service: .github, state: .operational, delay: .milliseconds(100)),
            DelayedStateProvider(service: .github, state: .outage, delay: .zero)
        ]).fetchAll()

        XCTAssertEqual(snapshot.statuses.first?.state, .operational)
    }

    func testLiveFactoryHasCanonicalSevenProviders() {
        let providers = ProviderFactory.live

        XCTAssertEqual(providers.map(\.service), [.github, .openAI, .claude, .aws, .grok, .deepSeek, .cursor])
        XCTAssertEqual(Set(providers.map(\.service)).count, 7)
        XCTAssertEqual((providers[0] as? StatuspageProvider)?.endpoint.absoluteString, "https://www.githubstatus.com/api/v2/status.json")
        XCTAssertEqual((providers[1] as? StatuspageProvider)?.endpoint.absoluteString, "https://status.openai.com/api/v2/status.json")
        XCTAssertEqual((providers[2] as? StatuspageProvider)?.endpoint.absoluteString, "https://status.claude.com/api/v2/status.json")
        XCTAssertEqual((providers[3] as? AWSProvider)?.endpoint.absoluteString, "https://health.aws.amazon.com/public/currentevents")
        XCTAssertEqual((providers[4] as? FeedProvider)?.endpoint.absoluteString, "https://status.x.ai/feed.xml")
        XCTAssertEqual((providers[5] as? FeedProvider)?.endpoint.absoluteString, "https://status.deepseek.com/feed.rss")
        XCTAssertEqual((providers[6] as? StatuspageProvider)?.endpoint.absoluteString, "https://status.cursor.com/api/v2/status.json")
    }
}

private struct ImmediateProvider: StatusProvider {
    let service: Service
    let state: ServiceState

    func fetch(using transport: any HTTPTransport) async throws -> ServiceStatus {
        ServiceStatus(service: service, state: state)
    }
}

private struct FailingProvider: StatusProvider {
    let service: Service

    func fetch(using transport: any HTTPTransport) async throws -> ServiceStatus {
        throw URLError(.cannotConnectToHost)
    }
}

private struct DelayedProvider: StatusProvider {
    let service: Service
    let tracker: ConcurrencyTracker

    func fetch(using transport: any HTTPTransport) async throws -> ServiceStatus {
        await tracker.enter()
        try await Task.sleep(for: .milliseconds(100))
        await tracker.leave()
        return ServiceStatus(service: service, state: .operational)
    }
}

private actor ConcurrencyTracker {
    private var activeFetches = 0
    private(set) var maximumConcurrentFetches = 0

    func enter() {
        activeFetches += 1
        maximumConcurrentFetches = max(maximumConcurrentFetches, activeFetches)
    }

    func leave() {
        activeFetches -= 1
    }
}

private struct DelayedStateProvider: StatusProvider {
    let service: Service
    let state: ServiceState
    let delay: Duration

    func fetch(using transport: any HTTPTransport) async throws -> ServiceStatus {
        try await Task.sleep(for: delay)
        return ServiceStatus(service: service, state: state)
    }
}
