import PSSCore
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var store: StatusStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(store.snapshot.statuses) { status in
                StatusRowView(status: status)
            }

            Divider()

            HStack {
                Text("Updated \(store.snapshot.updatedAt, style: .relative)")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Refresh") {
                    Task { await store.refresh() }
                }
                .disabled(store.isRefreshing)

                if store.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding()
        .frame(width: 320)
        .task { await store.refresh() }
    }
}
