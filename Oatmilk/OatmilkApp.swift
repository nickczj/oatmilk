import SwiftUI

@main
struct OatmilkApp: App {
    @State private var utilityStore = UtilityStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(utilityStore)
        }
    }
}
