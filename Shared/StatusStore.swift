import Combine
import Foundation
import WidgetKit

@MainActor
public final class StatusStore: ObservableObject {
    @Published public private(set) var snapshot: StatusSnapshot
    @Published public private(set) var isRefreshing = false

    private let fetchSnapshot: @Sendable () async -> StatusSnapshot
    private let saveSnapshot: @Sendable (StatusSnapshot) async -> Void
    private let reloadWidgets: @Sendable () -> Void
    private var refreshTask: Task<Void, Never>?

    public convenience init(client: StatusClient = StatusClient(), cache: StatusCache = StatusCache()) {
        self.init(
            fetchSnapshot: { await client.fetchAll() },
            loadCachedSnapshot: { cache.load() },
            saveSnapshot: { snapshot in try? cache.save(snapshot) },
            reloadWidgets: { WidgetCenter.shared.reloadAllTimelines() }
        )
    }

    public init(
        fetchSnapshot: @escaping @Sendable () async -> StatusSnapshot,
        loadCachedSnapshot: @escaping @Sendable () -> StatusSnapshot?,
        saveSnapshot: @escaping @Sendable (StatusSnapshot) async -> Void,
        reloadWidgets: @escaping @Sendable () -> Void,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.fetchSnapshot = fetchSnapshot
        self.saveSnapshot = saveSnapshot
        self.reloadWidgets = reloadWidgets
        snapshot = loadCachedSnapshot() ?? .unknown(at: now())
    }

    public func refresh() async {
        if let refreshTask {
            await refreshTask.value
            return
        }

        isRefreshing = true
        let fetchSnapshot = fetchSnapshot
        let saveSnapshot = saveSnapshot
        let reloadWidgets = reloadWidgets
        refreshTask = Task { [weak self] in
            let snapshot = await fetchSnapshot()
            guard let self else { return }

            self.snapshot = snapshot
            await saveSnapshot(snapshot)
            reloadWidgets()
            self.isRefreshing = false
            self.refreshTask = nil
        }
        await refreshTask?.value
    }
}
