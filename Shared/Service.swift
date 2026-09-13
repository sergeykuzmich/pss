import Foundation

public enum Service: String, CaseIterable, Codable, Identifiable, Sendable {
    case github, openAI, claude, aws, grok, deepSeek, cursor

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .github: "GitHub"
        case .openAI: "OpenAI"
        case .claude: "Claude"
        case .aws: "AWS"
        case .grok: "Grok"
        case .deepSeek: "DeepSeek"
        case .cursor: "Cursor"
        }
    }

    public var statusPageURL: URL {
        switch self {
        case .github: URL(string: "https://www.githubstatus.com")!
        case .openAI: URL(string: "https://status.openai.com")!
        case .claude: URL(string: "https://status.claude.com")!
        case .aws: URL(string: "https://health.aws.amazon.com/health/status")!
        case .grok: URL(string: "https://status.x.ai")!
        case .deepSeek: URL(string: "https://status.deepseek.com")!
        case .cursor: URL(string: "https://status.cursor.com")!
        }
    }

    public var adapterConfiguration: AdapterConfiguration {
        switch self {
        case .github:
            .statuspage(endpoint: URL(string: "https://www.githubstatus.com/api/v2/status.json")!)
        case .openAI:
            .statuspage(endpoint: URL(string: "https://status.openai.com/api/v2/status.json")!)
        case .claude:
            .statuspage(endpoint: URL(string: "https://status.claude.com/api/v2/status.json")!)
        case .aws:
            .awsHealth
        case .grok:
            .xAIFeed(endpoint: URL(string: "https://status.x.ai/feed.rss")!, productPath: "/grok-com/")
        case .deepSeek:
            .flashDutyFeed(endpoint: URL(string: "https://status.deepseek.com/feed.rss")!)
        case .cursor:
            .statuspage(endpoint: URL(string: "https://status.cursor.com/api/v2/status.json")!)
        }
    }

    public enum AdapterConfiguration: Equatable, Sendable {
        case statuspage(endpoint: URL)
        case xAIFeed(endpoint: URL, productPath: String)
        case flashDutyFeed(endpoint: URL)
        case awsHealth
    }
}
