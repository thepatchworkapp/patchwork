import SwiftUI

struct TaskerPaywallOptionCard: View {
    let title: String
    let priceAmount: String
    let priceSuffix: String
    let detail: String
    let accent: Color
    let badgeText: String?
    let isSelected: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Text(title)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(PatchworkTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 8)

                    if let badgeText {
                        Text(badgeText)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                LinearGradient(
                                    colors: [
                                        PatchworkTheme.brandBright,
                                        PatchworkTheme.brand
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                in: Capsule()
                            )
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(priceAmount)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(isSelected ? accent : PatchworkTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.86)

                    Text(priceSuffix)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(PatchworkTheme.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                }

                Text(detail)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(PatchworkTheme.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 142, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(isSelected ? accent.opacity(0.08) : PatchworkTheme.surface.opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: isSelected
                                        ? [Color.white.opacity(0.3), accent.opacity(0.06)]
                                        : [Color.clear, Color.clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(isSelected ? accent : PatchworkTheme.stroke, lineWidth: isSelected ? 3 : 1)
            )
            .shadow(
                color: isSelected ? accent.opacity(0.2) : Color.black.opacity(0.04),
                radius: isSelected ? 22 : 12,
                y: isSelected ? 10 : 6
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}
