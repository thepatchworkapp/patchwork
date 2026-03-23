import SwiftUI

struct PatchworkBackdrop: View {
    let tint: Color

    init(tint: Color = PatchworkTheme.brand) {
        self.tint = tint
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [PatchworkTheme.backgroundWarm, PatchworkTheme.background],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(tint.opacity(0.16))
                .frame(width: 320, height: 320)
                .blur(radius: 20)
                .offset(x: -120, y: -260)

            Circle()
                .fill(PatchworkTheme.accent.opacity(0.14))
                .frame(width: 260, height: 260)
                .blur(radius: 24)
                .offset(x: 130, y: -180)

            Circle()
                .fill(PatchworkTheme.brandBright.opacity(0.12))
                .frame(width: 260, height: 260)
                .blur(radius: 28)
                .offset(x: 110, y: 280)
        }
        .ignoresSafeArea()
    }
}
