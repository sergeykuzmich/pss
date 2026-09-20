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
        return ServiceStatus(service: service, state: Self.state(for: events))
    }

    private func decodedData(from data: Data) throws -> Data {
        let encodings: [String.Encoding]
        if data.starts(with: [0xFE, 0xFF]) {
            encodings = [.utf16BigEndian]
        } else if data.starts(with: [0xFF, 0xFE]) {
            encodings = [.utf16LittleEndian]
        } else {
            encodings = [.utf16BigEndian, .utf8]
        }

        for encoding in encodings {
            guard let text = String(data: data, encoding: encoding) else { continue }
            let candidate = Data(text.utf8)
            if (try? JSONSerialization.jsonObject(with: candidate)) != nil {
                return candidate
            }
        }
        throw URLError(.cannotDecodeContentData)
    }

    private static func text(for event: Event) -> String {
        ([event.status, event.serviceName, event.summary] + event.eventLog.flatMap { [$0.summary, $0.message] })
            .compactMap { $0 }
            .joined(separator: " ")
    }

    private static func state(for events: [Event]) -> ServiceState {
        events.map { event in
            let text = Self.text(for: event).lowercased()
            if text.contains("outage") || text.contains("disruption") {
                return .outage
            }
            if text.contains("increased error") && text.contains("multiple services") {
                return .majorDisruption
            }
            return .minorDisruption
        }.max { $0.severity < $1.severity } ?? .operational
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
