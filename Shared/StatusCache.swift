import Foundation

public struct StatusCache: Sendable {
    public enum Error: Swift.Error, Equatable {
        case containerUnavailable
    }

    private static let filename = "status-snapshot.json"
    private let directory: URL?

    public init(directory: URL? = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.sergeykuzmich.pss")) {
        self.directory = directory
    }

    public func load() -> StatusSnapshot? {
        guard let fileURL else { return nil }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970
            return try decoder.decode(StatusSnapshot.self, from: Data(contentsOf: fileURL))
        } catch {
            return nil
        }
    }

    public func save(_ snapshot: StatusSnapshot) throws {
        guard let fileURL else { throw Error.containerUnavailable }
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        try encoder.encode(snapshot).write(to: fileURL, options: .atomic)
    }

    private var fileURL: URL? {
        directory?.appendingPathComponent(Self.filename)
    }
}
