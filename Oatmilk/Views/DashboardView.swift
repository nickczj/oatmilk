import SwiftUI

struct DashboardView: View {
    @Environment(UtilityStore.self) private var store

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    var body: some View {
        NavigationStack {
            Group {
                if store.installedUtilities.isEmpty {
                    emptyState
                } else {
                    installedGrid
                }
            }
            .navigationTitle("Dashboard")
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No Utilities Installed",
            systemImage: "wrench.and.screwdriver",
            description: Text("Head over to the Utility Hub to browse and install utilities.")
        )
    }

    private var installedGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(store.installedUtilities) { utility in
                    NavigationLink {
                        destinationView(for: utility)
                    } label: {
                        UtilityCardView(utility: utility, style: .dashboard)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private func destinationView(for utility: UtilityInfo) -> some View {
        switch utility.id {
        case "charging_status":
            ChargingStatusView()
        default:
            Text("Utility not found")
        }
    }
}

#Preview {
    let store = UtilityStore()
    DashboardView()
        .environment(store)
}
