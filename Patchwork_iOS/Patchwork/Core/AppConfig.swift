import Foundation

enum AppConfig {
    static var convexCloudURL: URL {
        debugURLOverride("PATCHWORK_CONVEX_CLOUD_URL") ?? URL(string: "https://vibrant-caribou-150.convex.cloud")!
    }

    static var convexSiteURL: URL {
        debugURLOverride("PATCHWORK_CONVEX_SITE_URL") ?? URL(string: "https://vibrant-caribou-150.convex.site")!
    }

    static let revenueCatPublicAPIKey = "appl_KVrqPtiNVMghtWZGRGrnCnBQyfh"
    static let revenueCatEntitlementID = "tasker_access"
    static let revenueCatOfferingLookupKey = "tasker_access_paywall"
    static let revenueCatAnnualProductID = "ltd.ddga.patchwork.tasker.subscription.yearly"
    static let revenueCatLifetimeProductID = "ltd.ddga.patchwork.tasker.lifetime"

    private static func debugURLOverride(_ key: String) -> URL? {
        #if DEBUG
        let value = ProcessInfo.processInfo.environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value, !value.isEmpty else {
            return nil
        }
        return URL(string: value)
        #else
        return nil
        #endif
    }
}
