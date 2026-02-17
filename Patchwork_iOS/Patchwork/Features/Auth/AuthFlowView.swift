import SwiftUI

struct AuthFlowView: View {
    private enum Step {
        case splash
        case onboarding
        case signIn
        case email
        case verify
    }

    private struct OnboardingSlide {
        let icon: String
        let title: String
        let description: String
    }

    @Environment(SessionStore.self) private var sessionStore

    @State private var step: Step = .splash
    @State private var otp = ""
    @State private var onboardingIndex = 0
    @State private var localErrorMessage: String?

    private let onboardingSlides: [OnboardingSlide] = [
        .init(
            icon: "person.2.fill",
            title: "Connect with local service providers",
            description: "Find trusted Taskers within 100 km for 65+ categories-from plumbing to tutoring."
        ),
        .init(
            icon: "mappin.and.ellipse",
            title: "Real reviews. No ads.",
            description: "Rankings are based on genuine client ratings and proximity-never paid placements."
        ),
        .init(
            icon: "bell.fill",
            title: "Grow your local business",
            description: "Start as a Seeker, add a Tasker profile anytime to offer your own services."
        ),
    ]

    var body: some View {
        Group {
            switch step {
            case .splash:
                splashScreen
            case .onboarding:
                onboardingScreen
            case .signIn:
                signInScreen
            case .email:
                emailEntryScreen
            case .verify:
                verifyScreen
            }
        }
        .animation(.easeInOut(duration: 0.2), value: step)
    }

    private var splashScreen: some View {
        ZStack {
            Color(red: 79 / 255, green: 70 / 255, blue: 229 / 255)
                .ignoresSafeArea()

            VStack {
                Spacer()

                VStack(spacing: 16) {
                    HStack(spacing: -8) {
                        Circle().fill(Color(red: 254 / 255, green: 215 / 255, blue: 170 / 255)).frame(width: 26, height: 26)
                        Circle().fill(Color(red: 253 / 255, green: 230 / 255, blue: 138 / 255)).frame(width: 26, height: 26)
                        Circle().fill(Color(red: 110 / 255, green: 231 / 255, blue: 183 / 255)).frame(width: 26, height: 26)
                        Circle().fill(Color(red: 103 / 255, green: 232 / 255, blue: 249 / 255)).frame(width: 26, height: 26)
                        Circle().fill(Color(red: 251 / 255, green: 207 / 255, blue: 232 / 255)).frame(width: 26, height: 26)
                    }

                    Text("patchwork")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Connect with local service providers, or list yourself in over 65 categories.")
                        .font(.subheadline)
                        .foregroundStyle(Color(red: 199 / 255, green: 210 / 255, blue: 254 / 255))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }

                Spacer()

                Button("Get Started") {
                    step = .onboarding
                }
                .font(.headline)
                .foregroundStyle(Color(red: 79 / 255, green: 70 / 255, blue: 229 / 255))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(.white, in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .accessibilityIdentifier("Auth.getStartedButton")
            }
        }
    }

    private var onboardingScreen: some View {
        let slide = onboardingSlides[onboardingIndex]

        return VStack {
            Spacer()

            Circle()
                .fill(Color(red: 224 / 255, green: 231 / 255, blue: 255 / 255))
                .frame(width: 84, height: 84)
                .overlay {
                    Image(systemName: slide.icon)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(Color(red: 79 / 255, green: 70 / 255, blue: 229 / 255))
                }
                .padding(.bottom, 24)

            Text(slide.title)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)

            Text(slide.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 34)
                .padding(.top, 8)

            HStack(spacing: 8) {
                ForEach(0 ..< onboardingSlides.count, id: \.self) { idx in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(idx == onboardingIndex ? Color(red: 79 / 255, green: 70 / 255, blue: 229 / 255) : Color(.systemGray3))
                        .frame(width: idx == onboardingIndex ? 32 : 8, height: 8)
                }
            }
            .padding(.top, 28)

            Spacer()

            VStack(spacing: 10) {
                if onboardingIndex < onboardingSlides.count - 1 {
                    Button("Next") {
                        onboardingIndex += 1
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(red: 79 / 255, green: 70 / 255, blue: 229 / 255), in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityIdentifier("Auth.onboardingContinueButton")

                    Button("Skip") {
                        step = .signIn
                    }
                    .font(.headline)
                    .foregroundStyle(Color(red: 79 / 255, green: 70 / 255, blue: 229 / 255))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .accessibilityIdentifier("Auth.onboardingSkipButton")
                } else {
                    Button("Get Started") {
                        step = .signIn
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(red: 79 / 255, green: 70 / 255, blue: 229 / 255), in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityIdentifier("Auth.onboardingContinueButton")
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(.white)
    }

    private var signInScreen: some View {
        VStack(spacing: 18) {
            Spacer()

            VStack(spacing: 10) {
                HStack(spacing: -8) {
                    Circle().fill(Color(red: 254 / 255, green: 215 / 255, blue: 170 / 255)).frame(width: 20, height: 20)
                    Circle().fill(Color(red: 253 / 255, green: 230 / 255, blue: 138 / 255)).frame(width: 20, height: 20)
                    Circle().fill(Color(red: 110 / 255, green: 231 / 255, blue: 183 / 255)).frame(width: 20, height: 20)
                    Circle().fill(Color(red: 103 / 255, green: 232 / 255, blue: 249 / 255)).frame(width: 20, height: 20)
                    Circle().fill(Color(red: 251 / 255, green: 207 / 255, blue: 232 / 255)).frame(width: 20, height: 20)
                }

                Text("patchwork")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
            }

            Text("Sign in to continue")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                Button {
                    localErrorMessage = "Google sign-in is not yet available in iOS. Use email sign in."
                } label: {
                    HStack(spacing: 8) {
                        Text("G")
                            .font(.headline)
                        Text("Continue with Google")
                            .font(.headline)
                    }
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.white, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.systemGray4), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("Auth.googleSignInButton")

                HStack {
                    Rectangle().fill(Color(.systemGray4)).frame(height: 1)
                    Text("or")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Rectangle().fill(Color(.systemGray4)).frame(height: 1)
                }

                Button("Continue with Email") {
                    step = .email
                }
                .font(.headline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(.white, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.systemGray4), lineWidth: 1))
                .accessibilityIdentifier("Auth.emailSignInButton")
            }
            .padding(.horizontal, 24)

            if let error = localErrorMessage ?? sessionStore.errorMessage {
                Text(error)
                    .foregroundStyle(Color(red: 220 / 255, green: 38 / 255, blue: 38 / 255))
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer()

            Button {
                // Reserved for account creation parity path.
            } label: {
                Text("Don't have an account? ") + Text("Create account").foregroundStyle(Color(red: 79 / 255, green: 70 / 255, blue: 229 / 255))
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .buttonStyle(.plain)
            .padding(.bottom, 24)
        }
        .background(.white)
    }

    private var emailEntryScreen: some View {
        VStack(spacing: 0) {
            authBar(title: "Sign In with Email", onBack: {
                step = .signIn
            })

            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Enter your email")
                        .font(.title3.weight(.semibold))
                    Text("We'll send you a verification code to sign in")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                TextField(
                    "your@email.com",
                    text: Binding(
                        get: { sessionStore.emailForOTP },
                        set: { sessionStore.emailForOTP = $0 }
                    )
                )
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityIdentifier("Auth.emailField")

                Button(sessionStore.isLoading ? "Sending..." : "Send Code") {
                    Task {
                        await sessionStore.sendOTP()
                        if sessionStore.errorMessage == nil {
                            localErrorMessage = nil
                            otp = ""
                            step = .verify
                        }
                    }
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(red: 79 / 255, green: 70 / 255, blue: 229 / 255), in: RoundedRectangle(cornerRadius: 10))
                .disabled(sessionStore.isLoading)
                .accessibilityIdentifier("Auth.sendCodeButton")

                if let error = sessionStore.errorMessage {
                    Text(error)
                        .foregroundStyle(Color(red: 220 / 255, green: 38 / 255, blue: 38 / 255))
                        .font(.footnote)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(24)
        }
        .background(.white)
    }

    private var verifyScreen: some View {
        VStack(spacing: 0) {
            authBar(title: "Verify Email", onBack: {
                step = .email
            })

            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Check your email")
                        .font(.title3.weight(.semibold))
                    Text("We sent a code to \(sessionStore.emailForOTP)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                TextField("6-digit code", text: $otp)
                    .keyboardType(.numberPad)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityIdentifier("Auth.codeField")

                Button(sessionStore.isLoading ? "Verifying..." : "Verify Code") {
                    Task {
                        await sessionStore.verifyOTP(code: otp)
                        if sessionStore.errorMessage == nil {
                            localErrorMessage = nil
                        }
                    }
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(red: 79 / 255, green: 70 / 255, blue: 229 / 255), in: RoundedRectangle(cornerRadius: 10))
                .disabled(sessionStore.isLoading || otp.count < 6)
                .accessibilityIdentifier("Auth.verifyButton")

                Button("Resend Code") {
                    Task {
                        await sessionStore.sendOTP()
                    }
                }
                .font(.subheadline)
                .foregroundStyle(Color(red: 79 / 255, green: 70 / 255, blue: 229 / 255))

                if let error = sessionStore.errorMessage {
                    Text(error)
                        .foregroundStyle(Color(red: 220 / 255, green: 38 / 255, blue: 38 / 255))
                        .font(.footnote)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(24)
        }
        .background(.white)
    }

    private func authBar(title: String, onBack: @escaping () -> Void) -> some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .frame(width: 32, height: 32)
            }
            Spacer()
            Text(title)
                .font(.headline)
            Spacer()
            Color.clear.frame(width: 32, height: 32)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}
