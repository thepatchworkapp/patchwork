import SwiftUI

enum PatchworkTheme {
    static let brand = Color(red: 79 / 255, green: 70 / 255, blue: 229 / 255)
    static let brandBright = Color(red: 124 / 255, green: 92 / 255, blue: 255 / 255)
    static let brandSoft = Color(red: 227 / 255, green: 221 / 255, blue: 255 / 255)
    static let accent = Color(red: 14 / 255, green: 165 / 255, blue: 233 / 255)
    static let success = Color(red: 22 / 255, green: 163 / 255, blue: 74 / 255)
    static let warning = Color(red: 217 / 255, green: 119 / 255, blue: 6 / 255)
    static let danger = Color(red: 220 / 255, green: 38 / 255, blue: 38 / 255)
    static let ratingStar = Color(red: 251 / 255, green: 191 / 255, blue: 36 / 255)

    static let textPrimary = Color(red: 17 / 255, green: 24 / 255, blue: 39 / 255)
    static let textSecondary = Color(red: 107 / 255, green: 114 / 255, blue: 128 / 255)
    static let textTertiary = Color(red: 156 / 255, green: 163 / 255, blue: 175 / 255)

    static let background = Color(red: 246 / 255, green: 244 / 255, blue: 255 / 255)
    static let backgroundWarm = Color(red: 255 / 255, green: 251 / 255, blue: 247 / 255)
    static let surface = Color.white
    static let surfaceMuted = Color(red: 247 / 255, green: 247 / 255, blue: 252 / 255)
    static let stroke = Color(red: 225 / 255, green: 228 / 255, blue: 238 / 255)
    static let strokeStrong = Color(red: 199 / 255, green: 210 / 255, blue: 254 / 255)

    static let heroGradient = LinearGradient(
        colors: [
            Color(red: 86 / 255, green: 43 / 255, blue: 209 / 255),
            Color(red: 99 / 255, green: 102 / 255, blue: 241 / 255),
            Color(red: 79 / 255, green: 70 / 255, blue: 229 / 255),
            Color(red: 14 / 255, green: 165 / 255, blue: 233 / 255)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

enum PatchworkMetrics {
    static let screenPadding: CGFloat = 24
    static let sectionSpacing: CGFloat = 20
    static let cardSpacing: CGFloat = 14
    static let fieldHeight: CGFloat = 54
    static let buttonHeight: CGFloat = 54
    static let cardRadius: CGFloat = 24
    static let controlRadius: CGFloat = 16
    static let chipRadius: CGFloat = 999
    static let emptyStateContentMaxWidth: CGFloat = 280
}

extension Font {
    static let patchworkDisplay = Font.system(.largeTitle, design: .rounded).weight(.bold)
    static let patchworkWordmark = Font.system(.title, design: .rounded).weight(.bold)
    static let patchworkHeroTitle = Font.system(.title2, design: .rounded).weight(.bold)
    static let patchworkSectionTitle = Font.system(.title3, design: .rounded).weight(.bold)
    static let patchworkCardTitle = Font.system(.headline, design: .rounded).weight(.semibold)
    static let patchworkButton = Font.system(.headline, design: .rounded).weight(.semibold)
    static let patchworkBody = Font.system(.body, design: .rounded)
    static let patchworkBodyStrong = Font.system(.body, design: .rounded).weight(.semibold)
    static let patchworkCaption = Font.system(.caption, design: .rounded).weight(.medium)
}
