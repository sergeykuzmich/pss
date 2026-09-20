import PSSCore
import SwiftUI
import WidgetKit

struct StatusTimelineEntry: TimelineEntry {
    let date: Date
    let snapshot: StatusSnapshot
}

struct StatusTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> StatusTimelineEntry {
        entry(now: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (StatusTimelineEntry) -> Void) {
        completion(entry(now: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StatusTimelineEntry>) -> Void) {
        let now = Date.now
        completion(Timeline(entries: [entry(now: now)], policy: .after(now.addingTimeInterval(15 * 60))))
    }

    private func entry(now: Date) -> StatusTimelineEntry {
        StatusTimelineEntry(date: now, snapshot: WidgetSnapshotLoader.snapshot(cache: StatusCache(), now: now))
    }
}

struct StatusWidget: Widget {
    let kind = "com.sergeykuzmich.pss.status"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StatusTimelineProvider()) { entry in
            StatusWidgetView(entry: entry)
        }
        .configurationDisplayName("Service Status")
        .description("Shows the latest service status.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

private struct StatusWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StatusTimelineEntry

    private var rowSpacing: CGFloat { family == .systemMedium ? 4 : 8 }

    var body: some View {
        VStack(alignment: .leading, spacing: rowSpacing) {
            ForEach(entry.snapshot.statuses) { status in
                StatusRowView(status: status)
                    .font(.caption)
            }
        }
        .containerBackground(.background, for: .widget)
    }
}

#Preview("Operational", as: .systemMedium) {
    StatusWidget()
} timeline: {
    StatusTimelineEntry(date: .now, snapshot: StatusSnapshot(updatedAt: .now, statuses: [
        ServiceStatus(service: .github, state: .operational),
        ServiceStatus(service: .openAI, state: .operational),
        ServiceStatus(service: .claude, state: .operational),
        ServiceStatus(service: .aws, state: .operational),
        ServiceStatus(service: .grok, state: .operational),
        ServiceStatus(service: .deepSeek, state: .operational),
        ServiceStatus(service: .cursor, state: .operational)
    ]))
}

#Preview("Operational", as: .systemLarge) {
    StatusWidget()
} timeline: {
    StatusTimelineEntry(date: .now, snapshot: StatusSnapshot(updatedAt: .now, statuses: [
        ServiceStatus(service: .github, state: .operational),
        ServiceStatus(service: .openAI, state: .operational),
        ServiceStatus(service: .claude, state: .operational),
        ServiceStatus(service: .aws, state: .operational),
        ServiceStatus(service: .grok, state: .operational),
        ServiceStatus(service: .deepSeek, state: .operational),
        ServiceStatus(service: .cursor, state: .operational)
    ]))
}

#Preview("Mixed disruptions", as: .systemMedium) {
    StatusWidget()
} timeline: {
    StatusTimelineEntry(date: .now, snapshot: StatusSnapshot(updatedAt: .now, statuses: [
        ServiceStatus(service: .github, state: .maintenance),
        ServiceStatus(service: .openAI, state: .minorDisruption),
        ServiceStatus(service: .claude, state: .majorDisruption)
    ]))
}

#Preview("Mixed disruptions", as: .systemLarge) {
    StatusWidget()
} timeline: {
    StatusTimelineEntry(date: .now, snapshot: StatusSnapshot(updatedAt: .now, statuses: [
        ServiceStatus(service: .github, state: .maintenance),
        ServiceStatus(service: .openAI, state: .minorDisruption),
        ServiceStatus(service: .claude, state: .majorDisruption)
    ]))
}

#Preview("Outage", as: .systemMedium) {
    StatusWidget()
} timeline: {
    StatusTimelineEntry(date: .now, snapshot: StatusSnapshot(updatedAt: .now, statuses: [
        ServiceStatus(service: .github, state: .outage),
        ServiceStatus(service: .openAI, state: .outage),
        ServiceStatus(service: .claude, state: .outage),
        ServiceStatus(service: .aws, state: .outage),
        ServiceStatus(service: .grok, state: .outage),
        ServiceStatus(service: .deepSeek, state: .outage),
        ServiceStatus(service: .cursor, state: .outage)
    ]))
}

#Preview("Outage", as: .systemLarge) {
    StatusWidget()
} timeline: {
    StatusTimelineEntry(date: .now, snapshot: StatusSnapshot(updatedAt: .now, statuses: [
        ServiceStatus(service: .github, state: .outage),
        ServiceStatus(service: .openAI, state: .outage),
        ServiceStatus(service: .claude, state: .outage),
        ServiceStatus(service: .aws, state: .outage),
        ServiceStatus(service: .grok, state: .outage),
        ServiceStatus(service: .deepSeek, state: .outage),
        ServiceStatus(service: .cursor, state: .outage)
    ]))
}

#Preview("Unknown", as: .systemMedium) {
    StatusWidget()
} timeline: {
    StatusTimelineEntry(date: .now, snapshot: .unknown(at: .now))
}

#Preview("Unknown", as: .systemLarge) {
    StatusWidget()
} timeline: {
    StatusTimelineEntry(date: .now, snapshot: .unknown(at: .now))
}
