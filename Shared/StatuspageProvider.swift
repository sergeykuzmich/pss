import Foundation

public struct StatuspageProvider: StatusProvider {
    public let service: Service
    public let endpoint: URL

    public init(service: Service, endpoint: URL) {
        self.service = service
        self.endpoint = endpoint
    }

    public func fetch(using transport: any HTTPTransport) async throws -> ServiceStatus {
        let (data, response) = try await transport.data(from: endpoint)
        guard (200...299).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let payload = try JSONDecoder().decode(Payload.self, from: data)
        return ServiceStatus(
            service: service,
            state: Self.state(for: payload.status.indicator),
            detail: payload.status.description
        )
    }

    public static let github = StatuspageProvider(
        service: .github,
        endpoint: URL(string: "https://www.githubstatus.com/api/v2/status.json")!
    )

    public static let openAI = StatuspageProvider(
        service: .openAI,
        endpoint: URL(string: "https://status.openai.com/api/v2/status.json")!
    )

    public static let claude = StatuspageProvider(
        service: .claude,
        endpoint: URL(string: "https://status.claude.com/api/v2/status.json")!
    )

    public static let cursor = StatuspageProvider(
        service: .cursor,
        endpoint: URL(string: "https://status.cursor.com/api/v2/status.json")!
    )

    private static func state(for indicator: String) -> ServiceState {
        switch indicator {
        case "none": .operational
        case "maintenance": .maintenance
        case "minor": .minorDisruption
        case "major": .majorDisruption
        case "critical": .outage
        default: .unknown
        }
    }

    private struct Payload: Decodable {
        struct Status: Decodable {
            let indicator: String
            let description: String
        }

        let status: Status
    }
}
