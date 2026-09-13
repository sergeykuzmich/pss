import SwiftUI

public struct StatusRowView: View {
    let status: ServiceStatus

    public init(status: ServiceStatus) {
        self.status = status
    }

    public var body: some View {
        Link(destination: status.service.statusPageURL) {
            HStack {
                Image(systemName: status.state.symbolName)
                Text(status.service.displayName)
                Spacer()
                Text(status.state.label)
            }
            .foregroundStyle(.primary)
            .contentShape(Rectangle())
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(status.service.displayName), \(status.state.label)")
    }
}
