import PSSCore
import SwiftUI

@main
struct PSSApp: App {
    @StateObject private var store: StatusStore

    init() {
        let store = StatusStore()
        _store = StateObject(wrappedValue: store)
        Task { await store.refresh() }
    }

    var body: some Scene {
        MenuBarExtra("Service Status", systemImage: worstState.symbolName) {
            MenuBarContentView(store: store)
        }
    }

    private var worstState: ServiceState {
        store.snapshot.statuses.max(by: { $0.state.severity < $1.state.severity })?.state ?? .unknown
    }
}
