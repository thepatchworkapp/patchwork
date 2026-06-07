import XCTest
@testable import Patchwork

final class AppVersionInfoTests: XCTestCase {
    func testProfileFooterTextUsesBundleShortVersionAndBuildNumber() {
        let versionInfo = AppVersionInfo(
            infoDictionary: [
                "CFBundleShortVersionString": "9.8.7",
                "CFBundleVersion": "654"
            ]
        )

        XCTAssertEqual(versionInfo.profileFooterText, "Version 9.8.7 (654)")
    }

    func testProfileFooterTextFallsBackToAvailableMetadataOnly() {
        XCTAssertEqual(
            AppVersionInfo(
                infoDictionary: ["CFBundleShortVersionString": "9.8.7"]
            ).profileFooterText,
            "Version 9.8.7"
        )
        XCTAssertEqual(
            AppVersionInfo(
                infoDictionary: ["CFBundleVersion": "654"]
            ).profileFooterText,
            "Build 654"
        )
        XCTAssertEqual(
            AppVersionInfo(
                infoDictionary: [
                    "CFBundleShortVersionString": " ",
                    "CFBundleVersion": "\n"
                ]
            ).profileFooterText,
            "Version unavailable"
        )
    }

    func testPatchworkInfoPlistUsesVersionBuildSettings() throws {
        let plist = try patchworkInfoPlist()

        XCTAssertEqual(
            plist["CFBundleShortVersionString"] as? String,
            "$(MARKETING_VERSION)"
        )
        XCTAssertEqual(
            plist["CFBundleVersion"] as? String,
            "$(CURRENT_PROJECT_VERSION)"
        )
    }

    private func patchworkInfoPlist() throws -> [String: Any] {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let patchworkIOSURL = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let infoPlistURL = patchworkIOSURL
            .appendingPathComponent("Patchwork")
            .appendingPathComponent("Info.plist")
        let data = try Data(contentsOf: infoPlistURL)
        let plist = try PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        )

        return try XCTUnwrap(plist as? [String: Any])
    }
}
