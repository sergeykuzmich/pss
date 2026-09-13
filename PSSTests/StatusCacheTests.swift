import Foundation
import XCTest
@testable import PSSCore

final class StatusCacheTests: XCTestCase {
    private let directory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("StatusCacheTests", isDirectory: true)

    override func setUpWithError() throws {
        try? FileManager.default.removeItem(at: directory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
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
}
