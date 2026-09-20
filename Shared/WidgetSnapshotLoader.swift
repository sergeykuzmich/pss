import Foundation

public enum WidgetSnapshotLoader {
    public static func snapshot(cache: StatusCache, now: Date) -> StatusSnapshot {
        cache.load() ?? .unknown(at: now)
    }
}
