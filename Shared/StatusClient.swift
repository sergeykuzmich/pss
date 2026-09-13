import Foundation

public enum ProviderFactory {
    public static let live: [any StatusProvider] = [
        StatuspageProvider.github,
        StatuspageProvider.openAI,
        StatuspageProvider.claude,
        AWSProvider(),
        FeedProvider.grok,
        FeedProvider.deepSeek,
        StatuspageProvider.cursor
    ]
}

public struct StatusClient: Sendable {
    private let providers: [any StatusProvider]
    private let transport: any HTTPTransport

    public init(
        providers: [any StatusProvider] = ProviderFactory.live,
        transport: any HTTPTransport = URLSessionTransport()
    ) {
        self.providers = providers
        self.transport = transport
    }

    public func fetchAll(at date: Date = .now) async -> StatusSnapshot {
        let statuses = await withTaskGroup(of: ServiceStatus.self) { group in
            for provider in providers {
                group.addTask {
                    do {
                        return try await provider.fetch(using: transport)
                    } catch {
                        return ServiceStatus(service: provider.service, state: .unknown)
                    }
                }
            }

            return await group.reduce(into: []) { $0.append($1) }
        }
        return StatusSnapshot(updatedAt: date, statuses: statuses)
    }
}
