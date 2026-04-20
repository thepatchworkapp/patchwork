import SwiftUI
import UIKit

@main
struct PatchworkApp: App {
    @State private var sessionStore: SessionStore
    @State private var appState = AppState()
    @State private var locationManager = LocationManager()
    @State private var revenueCatManager = RevenueCatManager()

    init() {
        let sessionPersistence = KeychainSessionPersistence()
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitesting") {
            UIView.setAnimationsEnabled(false)
        }
        if ProcessInfo.processInfo.arguments.contains("PATCHWORK_UI_RESET_SESSION") {
            let resetToken = ProcessInfo.processInfo.environment["PATCHWORK_UI_RESET_SESSION_TOKEN"] ?? "default"
            let resetTokenKey = "Patchwork.uiTestSessionResetToken"
            if UserDefaults.standard.string(forKey: resetTokenKey) != resetToken {
                sessionPersistence.saveSession(nil)
                UserDefaults.standard.set(resetToken, forKey: resetTokenKey)
            }
        }
#endif
        _sessionStore = State(initialValue: SessionStore(sessionPersistence: sessionPersistence))
    }

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
