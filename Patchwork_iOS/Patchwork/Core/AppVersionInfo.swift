import Foundation

struct AppVersionInfo: Equatable {
    let shortVersion: String?
    let buildNumber: String?

    init(bundle: Bundle = .main) {
        self.init(infoDictionaryValue: { key in
            bundle.object(forInfoDictionaryKey: key)
        })
    }

    init(infoDictionary: [String: Any]) {
        self.init(infoDictionaryValue: { key in
            infoDictionary[key]
        })
    }

    var profileFooterText: String {
        switch (shortVersion, buildNumber) {
        case let (version?, build?):
            return "Version \(version) (\(build))"
        case let (version?, nil):
            return "Version \(version)"
        case let (nil, build?):
            return "Build \(build)"
        case (nil, nil):
            return "Version unavailable"
        }
    }

    private init(infoDictionaryValue: (String) -> Any?) {
        shortVersion = Self.normalizedString(
            infoDictionaryValue("CFBundleShortVersionString")
        )
        buildNumber = Self.normalizedString(
            infoDictionaryValue("CFBundleVersion")
        )
    }

    private static func normalizedString(_ value: Any?) -> String? {
        guard let string = value as? String else {
            return nil
        }

        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
