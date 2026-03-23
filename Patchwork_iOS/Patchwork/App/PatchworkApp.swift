import SwiftUI

@main
struct PatchworkApp: App {
    @State private var sessionStore = SessionStore()
    @State private var appState = AppState()
    @State private var locationManager = LocationManager()
    @State private var revenueCatManager = RevenueCatManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(sessionStore)
                .environment(appState)
                .environment(locationManager)
                .environment(revenueCatManager)
                .preferredColorScheme(.light)
        }
    }
}
