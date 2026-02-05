import SwiftUI

struct ContentView: View {
    @Environment(UtilityStore.self) private var store

    var body: some View {
        TabView {
            Tab("Dashboard", systemImage: "square.grid.2x2.fill") {
                DashboardView()
            }

            Tab("Utility Hub", systemImage: "plus.circle.fill") {
                UtilityHubView()
            }
        }
        .tint(.orange)
    }
}

#Preview {
    ContentView()
        .environment(UtilityStore())
}
