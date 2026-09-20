import Foundation
import XCTest
@testable import PSSCore

final class StatusCacheTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent(".StatusCacheTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        defer { directory = nil }
        try? FileManager.default.removeItem(at: directory)
    }

    func testLoadReturnsSavedSnapshot() throws {
        let cache = StatusCache(directory: directory)
        let snapshot = StatusSnapshot(
            updatedAt: Date(timeIntervalSinceReferenceDate: 123),
            statuses: [ServiceStatus(service: .github, state: .operational, detail: "All systems operational")]
        )

        try cache.save(snapshot)

        XCTAssertEqual(cache.load(), snapshot)
    }

    func testLoadReturnsNilWhenCacheIsMissing() {
        XCTAssertNil(StatusCache(directory: directory).load())
    }

    func testLoadReturnsNilWhenCacheIsCorrupt() throws {
        try Data("not JSON".utf8).write(to: directory.appendingPathComponent("status-snapshot.json"))

        XCTAssertNil(StatusCache(directory: directory).load())
    }

    func testSaveAtomicallyReplacesPreviousSnapshot() throws {
        let cache = StatusCache(directory: directory)
        let first = StatusSnapshot(updatedAt: Date(timeIntervalSinceReferenceDate: 1), statuses: [])
        let second = StatusSnapshot(updatedAt: Date(timeIntervalSinceReferenceDate: 2), statuses: [
            ServiceStatus(service: .aws, state: .minorDisruption)
        ])

        try cache.save(first)
        try cache.save(second)

        XCTAssertEqual(cache.load(), second)
    }

    func testSaveThrowsWhenContainerIsUnavailable() {
        XCTAssertThrowsError(try StatusCache(directory: nil).save(.unknown(at: .now))) { error in
            XCTAssertEqual(error as? StatusCache.Error, .containerUnavailable)
        }
    }

    func testRoundTripPreservesFractionalSeconds() throws {
        let cache = StatusCache(directory: directory)
        let snapshot = StatusSnapshot(
            updatedAt: Date(timeIntervalSinceReferenceDate: 123.456_789),
            statuses: []
        )

        try cache.save(snapshot)

        let loaded = try XCTUnwrap(cache.load())
        XCTAssertEqual(loaded.updatedAt.timeIntervalSinceReferenceDate, snapshot.updatedAt.timeIntervalSinceReferenceDate, accuracy: 0.000_001)
        XCTAssertEqual(loaded.statuses, snapshot.statuses)
    }
}
