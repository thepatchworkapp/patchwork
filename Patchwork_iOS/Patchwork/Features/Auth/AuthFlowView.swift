import SwiftUI

struct AuthFlowView: View {
    private enum OnboardingLayout {
        static let contentTopPadding: CGFloat = 180
        static let contentSpacing: CGFloat = 22
        static let iconCircleSize: CGFloat = 88
    }

    private enum Step {
        case splash
        case onboarding
        case signIn
        case email
        case verify
    }

    private enum AuthIntent {
        case signIn
        case createAccount

        var promptTitle: String {
            switch self {
            case .signIn:
                return "Sign in to continue"
            case .createAccount:
                return "Create your account"
            }
        }

        var emailScreenTitle: String {
            switch self {
            case .signIn:
                return "Sign In with Email"
            case .createAccount:
                return "Create Account"
            }
        }

        var emailIntroTitle: String {
            switch self {
            case .signIn:
                return "Enter your email"
            case .createAccount:
                return "Enter your email to get started"
            }
        }

        var emailIntroMessage: String {
            switch self {
            case .signIn:
                return "We'll send you a verification code to sign in"
            case .createAccount:
                return "We'll send you a verification code to create your account"
            }
        }

        var verifyScreenTitle: String {
            switch self {
            case .signIn:
                return "Verify Email"
            case .createAccount:
                return "Confirm Your Email"
            }
        }

        var verifyIntroTitle: String {
            switch self {
            case .signIn:
                return "Check your email"
            case .createAccount:
                return "Finish creating your account"
            }
        }
    }

    private struct OnboardingSlide {
        let icon: String
        let title: String
        let description: String
        let iconSize: CGFloat
    }

    @Environment(SessionStore.self) private var sessionStore

    @State private var step: Step = .splash
    @State private var authIntent: AuthIntent = .signIn
    @State private var otpDigits = Array(repeating: "", count: 6)
    @State private var onboardingIndex = 0
    @State private var localErrorMessage: String?
    @FocusState private var focusedOTPIndex: Int?

    private var otpCode: String {
        otpDigits.joined()
    }

    private var isOTPComplete: Bool {
        otpDigits.allSatisfy { $0.count == 1 }
    }

    private let onboardingSlides: [OnboardingSlide] = [
        .init(
            icon: "person.2.fill",
            title: "Connect with local service providers",
            description: "Find trusted Taskers within 100 km for 65+ categories, from plumbing to tutoring.",
            iconSize: 34
        ),
        .init(
            icon: "mappin.and.ellipse",
            title: "Real reviews. No ads.",
            description: "Rankings are based on genuine client ratings and proximity, never paid placements.",
            iconSize: 34
        ),
        .init(
            icon: "bell.fill",
            title: "Grow your local business",
            description: "Start as a Seeker, then add a Tasker profile whenever you're ready to offer services.",
            iconSize: 28
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.2), value: step)
    }

    private var splashScreen: some View {
        ZStack {
            PatchworkTheme.heroGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                splashWordmark

                Text("Connect with local service providers, or list yourself in over 65 categories.")
                    .font(.patchworkBody)
                    .foregroundStyle(.white.opacity(0.78))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
                    .padding(.top, 10)

                Spacer()
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button("Get Started") {
                step = .onboarding
            }
            .font(.patchworkButton)
            .foregroundStyle(PatchworkTheme.brand)
            .frame(maxWidth: .infinity, minHeight: PatchworkMetrics.buttonHeight)
            .background(.white, in: RoundedRectangle(cornerRadius: PatchworkMetrics.controlRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PatchworkMetrics.controlRadius, style: .continuous)
                    .stroke(.white.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.16), radius: 22, y: 12)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .padding(.top, 14)
            .accessibilityLabel("Get Started")
            .accessibilityIdentifier("Auth.getStartedButton")
            .background(
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.white.opacity(0.06),
                        Color.white.opacity(0.20)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea(edges: .bottom)
            )
        }
    }

    private var splashWordmark: some View {
        VStack(spacing: 16) {
            Image("PatchworkLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 140, height: 140)
                .clipShape(.rect(cornerRadius: 30))
                .shadow(color: .black.opacity(0.16), radius: 28, y: 14)
                .accessibilityHidden(true)

            Text("patchwork")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
                .accessibilityHidden(true)
        }
    }

    private var onboardingScreen: some View {
        let slide = onboardingSlides[onboardingIndex]

        return ZStack {
            PatchworkBackdrop()

            VStack(alignment: .leading, spacing: OnboardingLayout.contentSpacing) {
                Color.clear
                    .frame(height: OnboardingLayout.contentTopPadding)

                Circle()
                    .fill(PatchworkTheme.brandSoft)
                    .frame(width: OnboardingLayout.iconCircleSize, height: OnboardingLayout.iconCircleSize)
                    .overlay {
                        Image(systemName: slide.icon)
                            .font(.system(size: slide.iconSize, weight: .semibold))
                            .foregroundStyle(PatchworkTheme.brand)
                    }

                PatchworkSectionIntro(
                    eyebrow: nil,
                    title: slide.title,
                    message: slide.description
                )

                HStack(spacing: 8) {
                    ForEach(0 ..< onboardingSlides.count, id: \.self) { idx in
                        Capsule()
                            .fill(idx == onboardingIndex ? PatchworkTheme.brand : PatchworkTheme.stroke)
                            .frame(width: idx == onboardingIndex ? 34 : 10, height: 10)
                    }
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                if onboardingIndex > 0 {
                    Button("Back") {
                        onboardingIndex -= 1
                    }
                    .buttonStyle(PatchworkTextButtonStyle())
                    .accessibilityLabel("Go back")
                    .accessibilityIdentifier("Auth.onboardingBackButton")
                } else {
                    Button("Back") {
                        onboardingIndex = 0
                        step = .splash
                    }
                    .buttonStyle(PatchworkTextButtonStyle())
                    .accessibilityLabel("Back to start")
                    .accessibilityIdentifier("Auth.onboardingBackToSplashButton")
                }

                if onboardingIndex < onboardingSlides.count - 1 {
                    Button("Next") {
                        onboardingIndex += 1
                    }
                    .buttonStyle(PatchworkPrimaryButtonStyle())
                    .accessibilityLabel("Next")
                    .accessibilityIdentifier("Auth.onboardingContinueButton")
                } else {
                    Button("Get Started") {
                        step = .signIn
                    }
                    .buttonStyle(PatchworkPrimaryButtonStyle())
                    .accessibilityLabel("Get Started")
                    .accessibilityIdentifier("Auth.onboardingContinueButton")
                }

                if onboardingIndex < onboardingSlides.count - 1 {
                    Button("Skip") {
                        step = .signIn
                    }
                    .buttonStyle(PatchworkTextButtonStyle())
                    .accessibilityLabel("Skip onboarding")
                    .accessibilityIdentifier("Auth.onboardingSkipButton")
                } else {
                    Button("Skip") {}
                        .buttonStyle(PatchworkTextButtonStyle())
                        .hidden()
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 14)
            .padding(.bottom, 24)
            .background(
                LinearGradient(
                    colors: [
                        PatchworkTheme.background.opacity(0),
                        PatchworkTheme.background.opacity(0.78),
                        PatchworkTheme.background.opacity(0.96)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea(edges: .bottom)
            )
        }
    }

    private var signInScreen: some View {
        ZStack {
            PatchworkBackdrop()

            VStack(spacing: 18) {
                Spacer(minLength: 20)

                PatchworkSurfaceCard {
                    VStack(spacing: 22) {
                        PatchworkWordmark()

                        PatchworkSectionIntro(
                            eyebrow: "Welcome back",
                            title: authIntent.promptTitle,
                            message: "Use email verification to sign in or create a new Patchwork account."
                        )

                        Button("Continue with Email") {
                            authIntent = .signIn
                            localErrorMessage = nil
                            step = .email
                        }
                        .buttonStyle(PatchworkPrimaryButtonStyle())
                        .accessibilityLabel("Continue with Email")
                        .accessibilityIdentifier("Auth.emailSignInButton")

                        if let error = localErrorMessage ?? sessionStore.errorMessage {
                            PatchworkInlineStatusBanner(tone: .error, text: error)
                        }

                        Button {
                            authIntent = .createAccount
                            localErrorMessage = nil
                            step = .email
                        } label: {
                            let createAccount = Text("Create account").foregroundStyle(PatchworkTheme.brand)
                            Text("Don't have an account? \(createAccount)")
                        }
                        .buttonStyle(.plain)
                        .font(.patchworkBody)
                        .foregroundStyle(PatchworkTheme.textSecondary)
                        .accessibilityLabel("Create account")
                        .accessibilityIdentifier("Auth.createAccountButton")
                    }
                }
                .padding(.horizontal, 24)

                Spacer()
            }
        }
    }

    private var emailEntryScreen: some View {
        ZStack {
            PatchworkBackdrop(tint: PatchworkTheme.accent)

            VStack(spacing: 0) {
                authBar(title: authIntent.emailScreenTitle, onBack: {
                    step = .signIn
                })

                PatchworkSurfaceCard {
                    EmailEntryForm(
                        eyebrow: authIntent == .createAccount ? "Create account" : "Sign in",
                        title: authIntent.emailIntroTitle,
                        message: authIntent.emailIntroMessage,
                        sessionStore: sessionStore,
                        onSent: {
                            localErrorMessage = nil
                            clearOTP()
                            if !sessionStore.isAuthenticated {
                                step = .verify
                            }
                        }
                    )
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)

                Spacer()
            }
        }
    }

    private var otpInput: some View {
        HStack(spacing: 8) {
            ForEach(0..<6, id: \.self) { index in
                TextField("", text: otpBinding(for: index))
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .multilineTextAlignment(.center)
                    .font(.title3.weight(.semibold))
                    .accessibilityLabel("Verification code digit \(index + 1)")
                    .accessibilityIdentifier("Auth.codeField.\(index)")
                    .focused($focusedOTPIndex, equals: index)
                    .frame(maxWidth: .infinity)
                    .frame(height: PatchworkMetrics.fieldHeight)
                    .background(
                        PatchworkTheme.surface,
                        in: RoundedRectangle(cornerRadius: PatchworkMetrics.controlRadius, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: PatchworkMetrics.controlRadius, style: .continuous)
                            .stroke(
                                focusedOTPIndex == index ? PatchworkTheme.brand : PatchworkTheme.stroke,
                                lineWidth: focusedOTPIndex == index ? 1.5 : 1
                            )
                    )
            }
        }
        .onAppear {
            focusedOTPIndex = 0
        }
    }

    private func otpBinding(for index: Int) -> Binding<String> {
        Binding(
            get: {
                otpDigits[index]
            },
            set: { newValue in
                handleOTPInput(newValue, at: index)
            }
        )
    }

    private func handleOTPInput(_ value: String, at index: Int) {
        let previous = otpDigits[index]
        let digits = Array(value.filter(\.isNumber))

        if digits.isEmpty {
            otpDigits[index] = ""
            if !previous.isEmpty, index > 0 {
                focusedOTPIndex = index - 1
            }
            return
        }

        if digits.count > 1 {
            if index == 0 {
                otpDigits = Array(repeating: "", count: 6)
            }

            var cursor = index
            for digit in digits.prefix(6 - index) {
                otpDigits[cursor] = String(digit)
                cursor += 1
            }

            if cursor <= 5 {
                focusedOTPIndex = cursor
            } else {
                focusedOTPIndex = nil
                autoSubmitOTPIfNeeded()
            }
            return
        }

        otpDigits[index] = String(digits[0])
        if index < 5 {
            focusedOTPIndex = index + 1
        } else {
            focusedOTPIndex = nil
            autoSubmitOTPIfNeeded()
        }
    }

    private func autoSubmitOTPIfNeeded() {
        guard isOTPComplete else {
            return
        }

        Task {
            await verifyOTP()
        }
    }

    private func verifyOTP() async {
        guard !sessionStore.isLoading else {
            return
        }

        await sessionStore.verifyOTP(code: otpCode)
        if sessionStore.errorMessage == nil {
            localErrorMessage = nil
        }
    }

    private func clearOTP() {
        otpDigits = Array(repeating: "", count: 6)
        focusedOTPIndex = 0
    }

    private var verifyScreen: some View {
        ZStack {
            PatchworkBackdrop(tint: PatchworkTheme.brandBright)

            VStack(spacing: 0) {
                authBar(title: authIntent.verifyScreenTitle, onBack: {
                    step = .email
                })

                PatchworkSurfaceCard {
                    VStack(alignment: .leading, spacing: 20) {
                        PatchworkSectionIntro(
                            eyebrow: "Secure sign-in",
                            title: authIntent.verifyIntroTitle,
                            message: "We sent a code to \(sessionStore.emailForOTP)"
                        )

                        otpInput
                            .onAppear {
                                focusedOTPIndex = 0
                            }

                        Button(sessionStore.isLoading ? "Verifying..." : "Verify Code") {
                            Task {
                                await verifyOTP()
                            }
                        }
                        .buttonStyle(PatchworkPrimaryButtonStyle())
                        .disabled(sessionStore.isLoading || !isOTPComplete)
                        .accessibilityLabel(sessionStore.isLoading ? "Verifying code" : "Verify code")
                        .accessibilityIdentifier("Auth.verifyButton")

                        Button("Resend Code") {
                            Task {
                                clearOTP()
                                await sessionStore.sendOTP()
                            }
                        }
                        .buttonStyle(PatchworkTextButtonStyle())
                        .accessibilityLabel("Resend verification code")
                        .accessibilityIdentifier("Auth.resendCodeButton")

                        if let error = sessionStore.errorMessage {
                            PatchworkInlineStatusBanner(tone: .error, text: error)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)

                Spacer()
            }
        }
    }

    private func authBar(title: String, onBack: @escaping () -> Void) -> some View {
        PatchworkTopBar(title: title, onBack: onBack)
    }
}

private struct EmailEntryForm: View {
    let eyebrow: String
    let title: String
    let message: String
    @Bindable var sessionStore: SessionStore
    let onSent: () -> Void

    var body: some View {
        let usesAppReviewShortcut = sessionStore.usesAppReviewShortcut

        VStack(alignment: .leading, spacing: 20) {
            PatchworkSectionIntro(
                eyebrow: eyebrow,
                title: title,
                message: message
            )

            TextField("your@email.com", text: $sessionStore.emailForOTP)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .patchworkInputFieldStyle()
                .accessibilityLabel("Email address")
                .accessibilityIdentifier("Auth.emailField")

            Button(sessionStore.isLoading ? "Sending..." : (usesAppReviewShortcut ? "Continue" : "Send Code")) {
                Task {
                    await sessionStore.sendOTP()
                    if sessionStore.errorMessage == nil {
                        onSent()
                    }
                }
            }
            .buttonStyle(PatchworkPrimaryButtonStyle())
            .disabled(sessionStore.isLoading)
            .accessibilityLabel(sessionStore.isLoading ? "Sending code" : (usesAppReviewShortcut ? "Continue" : "Send verification code"))
            .accessibilityIdentifier("Auth.sendCodeButton")

            if let error = sessionStore.errorMessage {
                PatchworkInlineStatusBanner(tone: .error, text: error)
            }
        }
    }
}
