public enum ServiceState: String, Codable, CaseIterable, Sendable {
    case operational, maintenance, minorDisruption, majorDisruption, outage, unknown

    public var label: String {
        switch self {
        case .operational: "Operational"
        case .maintenance: "Maintenance"
        case .minorDisruption: "Minor disruption"
        case .majorDisruption: "Major disruption"
        case .outage: "Outage"
        case .unknown: "Unknown"
        }
    }

    public var symbolName: String {
        switch self {
        case .operational: "checkmark.circle"
        case .maintenance: "wrench.and.screwdriver"
        case .minorDisruption: "exclamationmark.circle"
        case .majorDisruption: "exclamationmark.triangle"
        case .outage: "xmark.octagon"
        case .unknown: "questionmark.circle"
        }
    }

    public var severity: Int {
        switch self {
        case .operational: 0
        case .maintenance: 1
        case .minorDisruption: 2
        case .majorDisruption: 3
        case .outage: 4
        case .unknown: -1
        }
    }
}
