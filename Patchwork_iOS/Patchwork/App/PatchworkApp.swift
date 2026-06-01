import SwiftUI
import UIKit
import BackgroundTasks
import UserNotifications

final class PatchworkAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private enum Defaults {
        static let deviceTokenKey = "Patchwork.remoteNotificationDeviceToken"
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let notificationConversationId = PatchworkNotificationCenter.conversationId(from: notification)
        PatchworkNotificationCenter.postForegroundConversationNotification(conversationId: notificationConversationId)
        if let notificationConversationId,
           PatchworkNotificationCenter.isActiveConversation(notificationConversationId) {
            return [.badge]
        }
        return [.banner, .sound, .badge]
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(token, forKey: Defaults.deviceTokenKey)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("[Notifications] Failed to register for remote notifications: \(error.localizedDescription)")
    }
}

enum PatchworkNotificationCenter {
    static let foregroundConversationNotification = Notification.Name("Patchwork.foregroundConversationNotification")
    static let conversationIdUserInfoKey = "conversationId"

    @MainActor private static var activeConversationId: ConvexID?

    @MainActor
    @discardableResult
    static func requestAuthorizationAndRegister() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            }
            return granted
        } catch {
            return false
        }
    }

    @MainActor
    static func setActiveConversation(_ conversationId: ConvexID?) {
        activeConversationId = conversationId
    }

    @MainActor
    static func isActiveConversation(_ conversationId: ConvexID) -> Bool {
        activeConversationId == conversationId
    }

    static func conversationId(from notification: UNNotification) -> ConvexID? {
        notification.request.content.userInfo["conversationId"] as? String
    }

    @MainActor
    static func postForegroundConversationNotification(conversationId: ConvexID?) {
        let userInfo: [String: Any]
        if let conversationId {
            userInfo = [conversationIdUserInfoKey: conversationId]
        } else {
            userInfo = [:]
        }
        NotificationCenter.default.post(
            name: foregroundConversationNotification,
            object: nil,
            userInfo: userInfo
        )
    }

    @MainActor
    static func updateAppBadge(_ count: Int) {
        let sanitizedCount = max(0, count)
        if #available(iOS 16.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(sanitizedCount)
        } else {
            UIApplication.shared.applicationIconBadgeNumber = sanitizedCount
        }
    }
}

@main
struct PatchworkApp: App {
    private static let sessionRefreshTaskIdentifier = "ltd.ddga.patchwork.session-refresh"

    @UIApplicationDelegateAdaptor(PatchworkAppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var sessionStore: SessionStore
    @State private var realtimeChatClient: RealtimeChatClient
    @State private var chatLocalStore: ChatLocalStore
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
                UserDefaults.standard.removeObject(forKey: "Patchwork.taskerOnboardingDraft")
                UserDefaults.standard.removeObject(forKey: "Patchwork.taskerOnboardingRouteActive")
                UserDefaults.standard.removeObject(forKey: "Patchwork.taskerOnboardingRouteUserId")
                UserDefaults.standard.set(resetToken, forKey: resetTokenKey)
            }
        }
        if ProcessInfo.processInfo.arguments.contains("PATCHWORK_UI_STALE_TASKER_ROUTE") {
            UserDefaults.standard.set(true, forKey: "Patchwork.taskerOnboardingRouteActive")
            UserDefaults.standard.set("stale-user", forKey: "Patchwork.taskerOnboardingRouteUserId")
            UserDefaults.standard.set(
                """
                {"step":1,"displayName":"Stale Tasker","selectedCategoryId":null,"websiteLinks":[""],"socialLinks":[""],"categoryBio":"","rateType":"hourly","hourlyRate":"","fixedRate":"","serviceRadius":25}
                """,
                forKey: "Patchwork.taskerOnboardingDraft"
            )
        }
#endif
        let sessionStore = SessionStore(sessionPersistence: sessionPersistence)
        _sessionStore = State(initialValue: sessionStore)
        _realtimeChatClient = State(initialValue: RealtimeChatClient(sessionStore: sessionStore))
        do {
            _chatLocalStore = State(
                initialValue: ChatLocalStore(modelContainer: try ChatLocalStore.makeModelContainer())
            )
        } catch {
            fatalError("Failed to initialize chat local store: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(sessionStore)
                .environment(realtimeChatClient)
                .environment(chatLocalStore)
                .environment(appState)
                .environment(locationManager)
                .environment(revenueCatManager)
                .preferredColorScheme(.light)
        }
        .backgroundTask(.appRefresh(Self.sessionRefreshTaskIdentifier)) {
            await refreshSessionInBackground()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                scheduleSessionRefresh()
            }
        }
    }

    private func refreshSessionInBackground() async {
        scheduleSessionRefresh()
        guard sessionStore.isAuthenticated else {
            return
        }

        _ = await sessionStore.restorePersistedSessionIfNeeded(forceRefresh: false)
    }

    private func scheduleSessionRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.sessionRefreshTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}
