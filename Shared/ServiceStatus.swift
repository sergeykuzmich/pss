import Foundation

public struct ServiceStatus: Codable, Equatable, Identifiable, Sendable {
    public let service: Service
    public let state: ServiceState
    public let detail: String?

    public var id: Service { service }

    public init(service: Service, state: ServiceState, detail: String? = nil) {
        self.service = service
        self.state = state
        self.detail = detail
    }
}

public struct StatusSnapshot: Codable, Equatable, Sendable {
    public let updatedAt: Date
    public let statuses: [ServiceStatus]

    public init(updatedAt: Date, statuses: [ServiceStatus]) {
        self.updatedAt = updatedAt
        self.statuses = Service.allCases.map { service in
            statuses.first(where: { $0.service == service })
                ?? ServiceStatus(service: service, state: .unknown)
        }
    }

    public static func unknown(at date: Date) -> StatusSnapshot {
        StatusSnapshot(
            updatedAt: date,
            statuses: Service.allCases.map { ServiceStatus(service: $0, state: .unknown) }
        )
    }
}
