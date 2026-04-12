import SwiftUI

struct TaskerPaywallArtworkView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            PatchworkTheme.backgroundWarm,
                            Color.white,
                            PatchworkTheme.brandSoft.opacity(0.55)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Canvas { context, size in
                let gridColor = PatchworkTheme.brand.opacity(0.06)

                for x in stride(from: 14.0, through: size.width, by: 24.0) {
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    context.stroke(path, with: .color(gridColor), lineWidth: 1)
                }

                for y in stride(from: 14.0, through: size.height, by: 24.0) {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(path, with: .color(gridColor), lineWidth: 1)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))

            Circle()
                .fill(PatchworkTheme.brandSoft.opacity(0.85))
                .frame(width: 180, height: 180)
                .blur(radius: 6)
                .offset(x: -108, y: -60)

            Circle()
                .fill(PatchworkTheme.accent.opacity(0.18))
                .frame(width: 160, height: 160)
                .blur(radius: 10)
                .offset(x: 112, y: 68)

            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.white.opacity(0.92))
                .frame(width: 156, height: 178)
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(PatchworkTheme.strokeStrong, lineWidth: 1.5)
                )
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            Circle()
                                .fill(PatchworkTheme.heroGradient)
                                .frame(width: 34, height: 34)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.white)
                                )

                            VStack(alignment: .leading, spacing: 4) {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(PatchworkTheme.textPrimary.opacity(0.88))
                                    .frame(width: 58, height: 8)
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(PatchworkTheme.textSecondary.opacity(0.36))
                                    .frame(width: 42, height: 6)
                            }
                        }

                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(PatchworkTheme.brandSoft.opacity(0.45))
                            .frame(height: 60)
                            .overlay(
                                HStack(spacing: 8) {
                                    ForEach(0 ..< 3, id: \.self) { _ in
                                        Circle()
                                            .fill(PatchworkTheme.brand.opacity(0.18))
                                            .frame(width: 10, height: 10)
                                    }
                                }
                            )

                        HStack(spacing: 8) {
                            ForEach(0 ..< 2, id: \.self) { index in
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(index == 0 ? PatchworkTheme.brand.opacity(0.14) : PatchworkTheme.accent.opacity(0.16))
                                    .frame(height: 30)
                            }
                        }
                    }
                    .padding(18)
                }
                .rotationEffect(.degrees(-8))
                .offset(x: -38, y: -8)
                .shadow(color: PatchworkTheme.brand.opacity(0.16), radius: 24, y: 14)

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.96))
                .frame(width: 126, height: 132)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(PatchworkTheme.strokeStrong, lineWidth: 1.5)
                )
                .overlay {
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .stroke(PatchworkTheme.accent.opacity(0.22), lineWidth: 2)
                                .frame(width: 50, height: 50)
                            Circle()
                                .stroke(PatchworkTheme.brand.opacity(0.24), lineWidth: 2)
                                .frame(width: 70, height: 70)
                            Circle()
                                .fill(PatchworkTheme.heroGradient)
                                .frame(width: 34, height: 34)
                                .overlay(
                                    Image(systemName: "mappin.and.ellipse")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(.white)
                                )
                        }

                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(PatchworkTheme.textPrimary.opacity(0.84))
                            .frame(width: 60, height: 8)

                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(PatchworkTheme.textSecondary.opacity(0.24))
                            .frame(width: 82, height: 6)
                    }
                }
                .rotationEffect(.degrees(7))
                .offset(x: 78, y: 16)
                .shadow(color: PatchworkTheme.accent.opacity(0.16), radius: 22, y: 12)

            Capsule()
                .fill(PatchworkTheme.surface.opacity(0.85))
                .frame(width: 122, height: 18)
                .overlay(
                    HStack(spacing: 8) {
                        Circle()
                            .fill(PatchworkTheme.success)
                            .frame(width: 6, height: 6)
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(PatchworkTheme.success.opacity(0.28))
                            .frame(width: 58, height: 6)
                    }
                )
                .offset(x: 72, y: -82)
                .shadow(color: PatchworkTheme.brand.opacity(0.08), radius: 12, y: 6)
        }
        .frame(height: 220)
        .accessibilityHidden(true)
    }
}
