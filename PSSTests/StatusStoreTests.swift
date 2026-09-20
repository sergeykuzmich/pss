import Foundation
import XCTest
@testable import PSSCore

@MainActor
final class StatusStoreTests: XCTestCase {
    func testInitialSnapshotUsesCachedSnapshot() {
        let cached = snapshot(at: 10, github: .operational)

        let store = StatusStore(
            fetchSnapshot: { cached },
            loadCachedSnapshot: { cached },
            saveSnapshot: { _ in },
            reloadWidgets: {}
        )

        XCTAssertEqual(store.snapshot, cached)
        XCTAssertFalse(store.isRefreshing)
    }

    func testInitialSnapshotIsUnknownWhenCacheIsEmpty() {
        let refreshed = snapshot(at: 20, github: .operational)
        let store = StatusStore(
            fetchSnapshot: { refreshed },
            loadCachedSnapshot: { nil },
            saveSnapshot: { _ in },
            reloadWidgets: {},
            now: { Date(timeIntervalSinceReferenceDate: 1) }
        )

        XCTAssertEqual(store.snapshot, .unknown(at: Date(timeIntervalSinceReferenceDate: 1)))
    }

    func testRefreshUpdatesSnapshotAndSavesIt() async {
        let refreshed = snapshot(at: 30, github: .outage)
        let savedSnapshots = SnapshotRecorder()
        let store = StatusStore(
            fetchSnapshot: { refreshed },
            loadCachedSnapshot: { nil },
            saveSnapshot: { snapshot in await savedSnapshots.append(snapshot) },
            reloadWidgets: {}
        )

        await store.refresh()

        XCTAssertEqual(store.snapshot, refreshed)
        XCTAssertFalse(store.isRefreshing)
        let saved = await savedSnapshots.snapshots
        XCTAssertEqual(saved, [refreshed])
    }

    func testSimultaneousRefreshesShareOneFetch() async {
        let fetches = FetchCounter()
        let refreshed = snapshot(at: 40, github: .maintenance)
        let store = StatusStore(
            fetchSnapshot: {
                await fetches.increment()
                try? await Task.sleep(for: .milliseconds(50))
                return refreshed
            },
            loadCachedSnapshot: { nil },
            saveSnapshot: { _ in },
            reloadWidgets: {}
        )

        async let first: Void = store.refresh()
        async let second: Void = store.refresh()
        _ = await (first, second)

        let count = await fetches.count
        XCTAssertEqual(count, 1)
        XCTAssertEqual(store.snapshot, refreshed)
    }

    private func snapshot(at seconds: TimeInterval, github state: ServiceState) -> StatusSnapshot {
        StatusSnapshot(
            updatedAt: Date(timeIntervalSinceReferenceDate: seconds),
            statuses: [ServiceStatus(service: .github, state: state)]
        )
    }
}

private actor SnapshotRecorder {
    private(set) var snapshots: [StatusSnapshot] = []

    func append(_ snapshot: StatusSnapshot) {
        snapshots.append(snapshot)
    }
}

private actor FetchCounter {
    private(set) var count = 0

    func increment() {
        count += 1
    }
}
