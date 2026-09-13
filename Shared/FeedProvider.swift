import Foundation

public enum FeedKind: Equatable, Sendable {
    case xAI(productPath: String)
    case flashDuty
}

public struct FeedProvider: StatusProvider {
    public let service: Service
    public let kind: FeedKind
    public let endpoint: URL

    public init(service: Service, kind: FeedKind, endpoint: URL) {
        self.service = service
        self.kind = kind
        self.endpoint = endpoint
    }

    public func fetch(using transport: any HTTPTransport) async throws -> ServiceStatus {
        let (data, response) = try await transport.data(from: endpoint)
        guard (200...299).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let items = try FeedParser.parse(data)
        let activeItems = items.filter { item in
            switch kind {
            case let .xAI(productPath):
                item.link.contains(productPath) && !item.containsResolvedStatus
            case .flashDuty:
                !item.description.lowercased().contains("status: resolved")
            }
        }
        let statuses = activeItems.compactMap { item -> (ServiceState, String)? in
            let text: String
            switch kind {
            case .xAI:
                text = [item.title, item.description, item.categories.joined(separator: " ")].joined(separator: " ")
            case .flashDuty:
                text = [item.title, item.description].joined(separator: " ")
            }
            guard let state = Self.state(for: text) else { return nil }
            return (state, item.title)
        }
        guard let highestSeverity = statuses.map(\.0.severity).max() else {
            return ServiceStatus(service: service, state: .operational)
        }
        let match = statuses.first { $0.0.severity == highestSeverity }!
        return ServiceStatus(service: service, state: match.0, detail: match.1)
    }

    public static let grok = FeedProvider(
        service: .grok,
        kind: .xAI(productPath: "/grok-com/"),
        endpoint: URL(string: "https://status.x.ai/feed.xml")!
    )

    public static let deepSeek = FeedProvider(
        service: .deepSeek,
        kind: .flashDuty,
        endpoint: URL(string: "https://status.deepseek.com/feed.rss")!
    )

    private static func state(for text: String) -> ServiceState? {
        let text = text.lowercased()
        if text.contains("outage") || text.contains("critical") || text.contains("unavailable") {
            return .outage
        }
        if text.contains("major") { return .majorDisruption }
        if text.contains("degraded") || text.contains("partial") || text.contains("minor") {
            return .minorDisruption
        }
        if text.contains("maintenance") { return .maintenance }
        return nil
    }
}

private struct FeedItem {
    var title = ""
    var link = ""
    var description = ""
    var categories: [String] = []

    var containsResolvedStatus: Bool {
        [title, description, categories.joined(separator: " ")]
            .joined(separator: " ")
            .lowercased()
            .contains("status: resolved")
    }
}

private final class FeedParser: NSObject, XMLParserDelegate {
    private var items: [FeedItem] = []
    private var currentItem: FeedItem?
    private var text = ""

    static func parse(_ data: Data) throws -> [FeedItem] {
        let parser = XMLParser(data: data)
        let delegate = FeedParser()
        parser.delegate = delegate
        guard parser.parse() else {
            throw parser.parserError ?? URLError(.cannotParseResponse)
        }
        return delegate.items
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        if elementName == "item" {
            currentItem = FeedItem()
        } else if currentItem != nil {
            text = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        text += String(decoding: CDATABlock, as: UTF8.self)
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        guard var item = currentItem else { return }
        if elementName == "item" {
            items.append(item)
            currentItem = nil
            return
        }
        switch elementName {
        case "title": item.title = text.trimmingCharacters(in: .whitespacesAndNewlines)
        case "link": item.link = text.trimmingCharacters(in: .whitespacesAndNewlines)
        case "description": item.description = text.trimmingCharacters(in: .whitespacesAndNewlines)
        case "category": item.categories.append(text.trimmingCharacters(in: .whitespacesAndNewlines))
        default: break
        }
        currentItem = item
        text = ""
    }
}
