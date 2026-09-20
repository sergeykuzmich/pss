import Foundation
import XCTest
@testable import PSSCore

final class WidgetSnapshotTests: XCTestCase {
    func testSnapshotReturnsCachedValueUnchanged() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = StatusCache(directory: directory)
        let expected = StatusSnapshot(
            updatedAt: Date(timeIntervalSinceReferenceDate: 42),
            statuses: [ServiceStatus(service: .github, state: .majorDisruption, detail: "Incident")]
        )
        try cache.save(expected)

        XCTAssertEqual(WidgetSnapshotLoader.snapshot(cache: cache, now: .distantFuture), expected)
    }

    func testSnapshotReturnsUnknownServicesAtNowWhenCacheIsMissing() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let now = Date(timeIntervalSinceReferenceDate: 123)

        let snapshot = WidgetSnapshotLoader.snapshot(cache: StatusCache(directory: directory), now: now)

        XCTAssertEqual(snapshot, .unknown(at: now))
    }

    func testSnapshotReturnsUnknownServicesAtNowWhenCacheIsCorrupt() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data("invalid cache".utf8).write(to: directory.appendingPathComponent("status-snapshot.json"))
        let now = Date(timeIntervalSinceReferenceDate: 456)

        let snapshot = WidgetSnapshotLoader.snapshot(cache: StatusCache(directory: directory), now: now)

        XCTAssertEqual(snapshot, .unknown(at: now))
    }

    private func makeDirectory() throws -> URL {
        let directory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent(".WidgetSnapshotTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
