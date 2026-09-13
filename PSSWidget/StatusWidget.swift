import PSSCore
import SwiftUI
import WidgetKit

struct StatusWidget: Widget {
    let kind = "com.sergeykuzmich.pss.status"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PlaceholderProvider()) { entry in
            Text(entry.snapshot.updatedAt, style: .time)
        }
        .configurationDisplayName("Service Status")
        .description("Shows the latest service status.")
    }
}

private struct PlaceholderEntry: TimelineEntry {
    let date: Date
    let snapshot: StatusSnapshot
}

private struct PlaceholderProvider: TimelineProvider {
    func placeholder(in context: Context) -> PlaceholderEntry {
        placeholderEntry()
    }

    func getSnapshot(in context: Context, completion: @escaping (PlaceholderEntry) -> Void) {
        completion(placeholderEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PlaceholderEntry>) -> Void) {
        let entry = placeholderEntry()
        completion(Timeline(entries: [entry], policy: .never))
    }

    private func placeholderEntry() -> PlaceholderEntry {
        let date = Date()
        return PlaceholderEntry(date: date, snapshot: .unknown(at: date))
    }
}
