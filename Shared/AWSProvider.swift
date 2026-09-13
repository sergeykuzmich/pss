import Foundation

public struct AWSProvider: StatusProvider {
    public let service: Service = .aws
    public let endpoint = URL(string: "https://health.aws.amazon.com/public/currentevents")!

    public init() {}

    public func fetch(using transport: any HTTPTransport) async throws -> ServiceStatus {
        let (data, response) = try await transport.data(from: endpoint)
        guard (200...299).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let events = try JSONDecoder().decode([Event].self, from: decodedData(from: data))
        let text = events.map(Self.text(for:)).joined(separator: " ").lowercased()
        return ServiceStatus(service: service, state: Self.state(for: events, text: text))
    }

    private func decodedData(from data: Data) throws -> Data {
        let text: String?
        if data.starts(with: [0xFE, 0xFF]) {
            text = String(data: data, encoding: .utf16BigEndian)
        } else if data.starts(with: [0xFF, 0xFE]) {
            text = String(data: data, encoding: .utf16LittleEndian)
        } else {
            let bigEndian = String(data: data, encoding: .utf16BigEndian)
            text = bigEndian?.first == "[" || bigEndian?.first == "{" ? bigEndian : String(data: data, encoding: .utf8)
        }

        guard let text else {
            throw URLError(.cannotDecodeContentData)
        }
        return Data(text.utf8)
    }

    private static func text(for event: Event) -> String {
        ([event.status, event.serviceName, event.summary] + event.eventLog.flatMap { [$0.summary, $0.message] })
            .compactMap { $0 }
            .joined(separator: " ")
    }

    private static func state(for events: [Event], text: String) -> ServiceState {
        guard !events.isEmpty else { return .operational }
        if text.contains("outage") || text.contains("disruption") {
            return .outage
        }
        if text.contains("increased error") && text.contains("multiple services") {
            return .majorDisruption
        }
        return .minorDisruption
    }

    private struct Event: Decodable {
        let status: String
        let serviceName: String?
        let summary: String
        let eventLog: [Log]

        enum CodingKeys: String, CodingKey {
            case status, summary
            case serviceName = "service_name"
            case eventLog = "event_log"
        }
    }

    private struct Log: Decodable {
        let summary: String
        let message: String
        let status: Int
    }
}
