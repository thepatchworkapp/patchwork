import SwiftUI

private struct RequestDraft {
    var categoryId: ConvexID?
    var categoryName = ""
    var description = ""
    var address = ""
    var city = "Toronto"
    var province = "ON"
    var searchRadius = 25
    var timingType = "flexible"
    var specificDate = ""
    var specificTime = ""
    var budgetMin = ""
    var budgetMax = ""
}

private enum RequestWizardStep: Int {
    case details = 1
    case location = 2
    case timingBudget = 3
    case review = 4
    case success = 5
}

private enum RequestWizardValidation {
    static func trimmedDescription(_ draft: RequestDraft) -> String {
        draft.description.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func trimmedAddress(_ draft: RequestDraft) -> String {
        draft.address.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func trimmedCity(_ draft: RequestDraft) -> String {
        draft.city.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func trimmedProvince(_ draft: RequestDraft) -> String {
        draft.province.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func parsedBudgetValue(_ value: String) -> Double? {
        guard !value.isEmpty else { return nil }
        let normalized = value.replacingOccurrences(of: ",", with: "")
        guard let parsed = Double(normalized), parsed >= 0 else { return nil }
        return parsed
    }

    static func stepError(step: RequestWizardStep, draft: RequestDraft) -> String? {
        switch step {
        case .details:
            if draft.categoryId == nil {
                return "Select a category before continuing."
            }
            if trimmedDescription(draft).count < 12 {
                return "Add a bit more detail so Taskers can estimate the job accurately."
            }
            return nil
        case .location:
            if trimmedAddress(draft).isEmpty || trimmedCity(draft).isEmpty || trimmedProvince(draft).isEmpty {
                return "Enter your address, city, and province to continue."
            }
            return nil
        case .timingBudget:
            if draft.timingType == "specific_date" {
                if draft.specificDate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return "Pick a preferred date for this request."
                }
                if draft.specificTime.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return "Pick a preferred time for this request."
                }
            }

            let minBudget = parsedBudgetValue(draft.budgetMin)
            let maxBudget = parsedBudgetValue(draft.budgetMax)

            if !draft.budgetMin.isEmpty && minBudget == nil {
                return "Minimum budget must be a valid number."
            }
            if !draft.budgetMax.isEmpty && maxBudget == nil {
                return "Maximum budget must be a valid number."
            }
            if let minBudget, let maxBudget, maxBudget < minBudget {
                return "Maximum budget must be greater than or equal to minimum budget."
            }
            return nil
        case .review, .success:
            return nil
        }
    }

    static func canContinue(step: RequestWizardStep, draft: RequestDraft) -> Bool {
        stepError(step: step, draft: draft) == nil
    }
}

struct RequestWizardView: View {
    @Environment(AppState.self) private var appState
    @Environment(SessionStore.self) private var sessionStore
    @Environment(\.dismiss) private var dismiss

    @State private var step: RequestWizardStep = .details
    @State private var draft = RequestDraft()
    @State private var isSubmitting = false
    @State private var validationMessage: String?

    var body: some View {
        Group {
            switch step {
            case .details:
                RequestStep1View(
                    draft: $draft,
                    categories: appState.categories,
                    validationMessage: validationMessage,
                    onNext: {
                        advanceFromStep(.details)
                    }
                )
            case .location:
                RequestStep2View(
                    draft: $draft,
                    validationMessage: validationMessage,
                    onBack: { step = .details },
                    onNext: {
                        advanceFromStep(.location)
                    }
                )
            case .timingBudget:
                RequestStep3View(
                    draft: $draft,
                    validationMessage: validationMessage,
                    onBack: { step = .location },
                    onNext: {
                        advanceFromStep(.timingBudget)
                    }
                )
            case .review:
                RequestStep4View(
                    draft: $draft,
                    isSubmitting: isSubmitting,
                    onBack: { step = .timingBudget },
                    onSubmit: { Task { await submit() } }
                )
            case .success:
                RequestSuccessView(draft: draft, onClose: { dismiss() })
            }
        }
        .navigationTitle("New Request")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func advanceFromStep(_ currentStep: RequestWizardStep) {
        if let error = RequestWizardValidation.stepError(step: currentStep, draft: draft) {
            validationMessage = error
            return
        }
        validationMessage = nil
        switch currentStep {
        case .details:
            step = .location
        case .location:
            step = .timingBudget
        case .timingBudget:
            step = .review
        case .review, .success:
            break
        }
    }

    private func submit() async {
        guard let categoryId = draft.categoryId else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let budget = budgetDictionary()
            var payload: [String: Any] = [
                "categoryId": categoryId,
                "categoryName": draft.categoryName,
                "description": RequestWizardValidation.trimmedDescription(draft),
                "location": [
                    "address": RequestWizardValidation.trimmedAddress(draft),
                    "city": RequestWizardValidation.trimmedCity(draft),
                    "province": RequestWizardValidation.trimmedProvince(draft),
                    "searchRadius": draft.searchRadius,
                ],
                "timing": [
                    "type": draft.timingType,
                    "specificDate": draft.timingType == "specific_date" ? draft.specificDate : nil,
                    "specificTime": draft.timingType == "specific_date" ? draft.specificTime : nil,
                ].compactMapValues { $0 },
            ]

            if let budget {
                payload["budget"] = budget
            }

            _ = try await sessionStore.client.mutation(
                "jobRequests:createJobRequest",
                args: payload
            ) as ConvexID
            await appState.refreshAuthedData(client: sessionStore.client)
            step = .success
        } catch {
            appState.lastError = error.localizedDescription
        }
    }

    private func budgetDictionary() -> [String: Int]? {
        let minValue = Int((RequestWizardValidation.parsedBudgetValue(draft.budgetMin) ?? 0) * 100)
        let maxValue = Int((RequestWizardValidation.parsedBudgetValue(draft.budgetMax) ?? 0) * 100)
        if draft.budgetMin.isEmpty && draft.budgetMax.isEmpty {
            return nil
        }
        let resolvedMax = maxValue == 0 ? minValue : maxValue
        return ["min": minValue, "max": Swift.max(minValue, resolvedMax)]
    }
}

private struct RequestStep1View: View {
    @Binding var draft: RequestDraft
    let categories: [Category]
    let validationMessage: String?
    let onNext: () -> Void

    private var canContinue: Bool {
        RequestWizardValidation.canContinue(step: .details, draft: draft)
    }

    var body: some View {
        RequestStepLayout(
            currentStep: 1,
            title: "What do you need?",
            subtitle: "Choose a category and describe the task clearly so Taskers can quote accurately.",
            validationMessage: validationMessage
        ) {
            VStack(spacing: 16) {
                WizardCard {
                    Text("Category")
                        .font(.subheadline.weight(.semibold))
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                        ForEach(categories) { category in
                            Button {
                                draft.categoryId = category.id
                                draft.categoryName = category.name
                            } label: {
                                Text(category.name)
                                    .font(.caption.weight(.medium))
                                    .lineLimit(1)
                                    .padding(.horizontal, 12)
                                    .frame(maxWidth: .infinity, minHeight: 36)
                                    .background(
                                        draft.categoryId == category.id ? Color.indigo : Color.gray.opacity(0.12),
                                        in: RoundedRectangle(cornerRadius: 10)
                                    )
                                    .foregroundStyle(draft.categoryId == category.id ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("RequestStep1.categoryChip.\(category.id)")
                        }
                    }
                    .accessibilityIdentifier("RequestStep1.categoryGrid")
                }

                WizardCard {
                    Text("Describe your task")
                        .font(.subheadline.weight(.semibold))
                    TextEditor(text: $draft.description)
                        .frame(minHeight: 150)
                        .padding(6)
                        .background(Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                        .accessibilityLabel("Task description")
                        .accessibilityIdentifier("RequestStep1.descriptionField")
                    Text("Mention the issue, where it is, and anything a Tasker should bring.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        } footer: {
            Button("Continue", action: onNext)
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .disabled(!canContinue)
                .accessibilityIdentifier("RequestStep1.continueButton")
        }
    }
}

private struct RequestStep2View: View {
    @Binding var draft: RequestDraft
    let validationMessage: String?
    let onBack: () -> Void
    let onNext: () -> Void

    private var canContinue: Bool {
        RequestWizardValidation.canContinue(step: .location, draft: draft)
    }

    var body: some View {
        RequestStepLayout(
            currentStep: 2,
            title: "Where is the task?",
            subtitle: "Your exact address is only shared after you confirm a Tasker.",
            validationMessage: validationMessage
        ) {
            VStack(spacing: 16) {
                WizardCard {
                    TextField("Address", text: $draft.address)
                        .accessibilityIdentifier("RequestStep2.addressField")
                    Divider()
                    TextField("City", text: $draft.city)
                        .accessibilityIdentifier("RequestStep2.cityField")
                    Divider()
                    TextField("Province", text: $draft.province)
                        .accessibilityIdentifier("RequestStep2.provinceField")
                }

                WizardCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Search radius: \(draft.searchRadius) km")
                            .font(.subheadline.weight(.semibold))
                        Text("Taskers within this distance can see your request.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Slider(value: Binding(
                            get: { Double(draft.searchRadius) },
                            set: { draft.searchRadius = Int($0.rounded()) }
                        ), in: 5 ... 100, step: 5)
                        .accessibilityIdentifier("RequestStep2.radiusSlider")
                    }
                }
            }
        } footer: {
            HStack(spacing: 12) {
                Button("Back", action: onBack)
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("RequestStep2.backButton")
                Button("Continue", action: onNext)
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .disabled(!canContinue)
                    .accessibilityIdentifier("RequestStep2.continueButton")
            }
        }
    }
}

private struct RequestStep3View: View {
    @Binding var draft: RequestDraft
    let validationMessage: String?
    let onBack: () -> Void
    let onNext: () -> Void

    private var canContinue: Bool {
        RequestWizardValidation.canContinue(step: .timingBudget, draft: draft)
    }

    var body: some View {
        RequestStepLayout(
            currentStep: 3,
            title: "When and budget?",
            subtitle: "Help Taskers understand your urgency and expectations.",
            validationMessage: validationMessage
        ) {
            VStack(spacing: 16) {
                WizardCard {
                    Text("When do you need this done?")
                        .font(.subheadline.weight(.semibold))
                    HStack(spacing: 8) {
                        TimingChip(
                            title: "Flexible",
                            isSelected: draft.timingType == "flexible",
                            accessibilityIdentifier: "RequestStep3.timingFlexible"
                        ) {
                            draft.timingType = "flexible"
                            draft.specificDate = ""
                            draft.specificTime = ""
                        }
                        TimingChip(
                            title: "ASAP",
                            isSelected: draft.timingType == "asap",
                            accessibilityIdentifier: "RequestStep3.timingAsap"
                        ) {
                            draft.timingType = "asap"
                            draft.specificDate = ""
                            draft.specificTime = ""
                        }
                        TimingChip(
                            title: "Specific date",
                            isSelected: draft.timingType == "specific_date",
                            accessibilityIdentifier: "RequestStep3.timingSpecificDate"
                        ) {
                            draft.timingType = "specific_date"
                        }
                    }

                    if draft.timingType == "specific_date" {
                        TextField("Preferred date (YYYY-MM-DD)", text: $draft.specificDate)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .accessibilityIdentifier("RequestStep3.dateField")
                        TextField("Preferred time (HH:MM)", text: $draft.specificTime)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .accessibilityIdentifier("RequestStep3.timeField")
                    }
                }

                WizardCard {
                    Text("Budget (optional)")
                        .font(.subheadline.weight(.semibold))
                    HStack {
                        TextField("Min ($)", text: $draft.budgetMin)
                            .keyboardType(.decimalPad)
                            .accessibilityIdentifier("RequestStep3.budgetMinField")
                        Text("-")
                            .foregroundStyle(.secondary)
                        TextField("Max ($)", text: $draft.budgetMax)
                            .keyboardType(.decimalPad)
                            .accessibilityIdentifier("RequestStep3.budgetMaxField")
                    }
                    Text("Providing a budget helps Taskers decide quickly if they are a fit.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                WizardCard {
                    Text("Pro tip")
                        .font(.subheadline.weight(.semibold))
                    Text("Flexible timing usually gets you faster responses and better rates.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        } footer: {
            HStack(spacing: 12) {
                Button("Back", action: onBack)
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("RequestStep3.backButton")
                Button("Continue", action: onNext)
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .disabled(!canContinue)
                    .accessibilityIdentifier("RequestStep3.continueButton")
            }
        }
    }
}

private struct RequestStep4View: View {
    @Binding var draft: RequestDraft
    let isSubmitting: Bool
    let onBack: () -> Void
    let onSubmit: () -> Void

    private var timingLabel: String {
        switch draft.timingType {
        case "asap":
            return "ASAP"
        case "specific_date":
            return "\(draft.specificDate) at \(draft.specificTime)"
        default:
            return "Flexible"
        }
    }

    private var budgetLabel: String {
        if draft.budgetMin.isEmpty && draft.budgetMax.isEmpty {
            return "Not specified"
        }
        let minValue = draft.budgetMin.isEmpty ? "0" : draft.budgetMin
        let maxValue = draft.budgetMax.isEmpty ? "No max" : draft.budgetMax
        return "$\(minValue) - $\(maxValue)"
    }

    var body: some View {
        RequestStepLayout(
            currentStep: 4,
            title: "Review your request",
            subtitle: "Everything look right? Send it to nearby Taskers.",
            validationMessage: nil
        ) {
            VStack(spacing: 16) {
                WizardCard {
                    ReviewRow(label: "Category", value: draft.categoryName)
                    Divider()
                    ReviewRow(label: "Description", value: draft.description)
                    Divider()
                    ReviewRow(label: "Location", value: "\(draft.address), \(draft.city), \(draft.province)")
                    Divider()
                    ReviewRow(label: "Radius", value: "\(draft.searchRadius) km")
                }

                WizardCard {
                    ReviewRow(label: "Timing", value: timingLabel)
                    Divider()
                    ReviewRow(label: "Budget", value: budgetLabel)
                }

                WizardCard {
                    Text("What happens next")
                        .font(.subheadline.weight(.semibold))
                    VStack(alignment: .leading, spacing: 8) {
                        Text("- Taskers within \(draft.searchRadius) km can view your request.")
                        Text("- You will receive quotes and messages in your inbox.")
                        Text("- Compare profiles, pricing, and response times before choosing.")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityIdentifier("RequestStep4.nextStepsCard")
            }
        } footer: {
            HStack(spacing: 12) {
                Button("Back", action: onBack)
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("RequestStep4.backButton")
                Button(isSubmitting ? "Sending..." : "Send Request", action: onSubmit)
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .disabled(isSubmitting)
                    .accessibilityIdentifier("RequestStep4.sendButton")
            }
        }
    }
}

private struct RequestSuccessView: View {
    @Environment(AppState.self) private var appState
    let draft: RequestDraft
    let onClose: () -> Void

    @State private var showRequests = false

    var body: some View {
        if showRequests {
            List(appState.myRequests) { request in
                VStack(alignment: .leading, spacing: 6) {
                    Text(request.categoryName)
                        .font(.headline)
                    Text(request.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Text(request.status.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("My Requests")
        } else {
            VStack(spacing: 16) {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 84, height: 84)
                    .overlay {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 42))
                            .foregroundStyle(.green)
                    }
                    .accessibilityIdentifier("RequestSuccess.icon")

                Text("Request sent!")
                    .font(.title2.weight(.bold))

                Text("Your request is now visible to nearby Taskers within \(draft.searchRadius) km. You will be notified as soon as quotes come in.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                VStack(spacing: 12) {
                    Button("View My Requests") {
                        showRequests = true
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("RequestSuccess.viewRequestsButton")

                    Button("Back to Home", action: onClose)
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("RequestSuccess.closeButton")
                }
            }
            .padding(24)
        }
    }
}

private struct RequestStepLayout<Content: View, Footer: View>: View {
    let currentStep: Int
    let title: String
    let subtitle: String
    let validationMessage: String?
    @ViewBuilder let content: Content
    @ViewBuilder let footer: Footer

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                StepHeader(currentStep: currentStep)
                    .accessibilityIdentifier("RequestStep\(currentStep).progressIndicator")

                Text(title)
                    .font(.title3.weight(.semibold))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let validationMessage {
                    Text(validationMessage)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                        .accessibilityIdentifier("RequestStep\(currentStep).validationMessage")
                }

                content
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .safeAreaInset(edge: .bottom) {
            footer
                .padding(16)
                .background(.ultraThinMaterial)
        }
    }
}

private struct WizardCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct TimingChip: View {
    let title: String
    let isSelected: Bool
    let accessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(isSelected ? Color.indigo : Color.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private struct ReviewRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
        }
    }
}

private struct StepHeader: View {
    let currentStep: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ForEach(1 ... 4, id: \.self) { step in
                    StepBadge(step: step, currentStep: currentStep)
                    if step < 4 {
                        Rectangle()
                            .fill(step < currentStep ? Color.green : Color.gray.opacity(0.2))
                            .frame(height: 4)
                            .frame(maxWidth: .infinity)
                    }
                }
            }

            Text("Step \(currentStep) of 4")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(currentStep) of 4")
    }
}

private struct StepBadge: View {
    let step: Int
    let currentStep: Int

    private var fillColor: Color {
        if step < currentStep { return .green }
        if step == currentStep { return .indigo }
        return Color.gray.opacity(0.2)
    }

    private var textColor: Color {
        step <= currentStep ? .white : .secondary
    }

    private var labelText: String {
        step < currentStep ? "✓" : "\(step)"
    }

    var body: some View {
        Circle()
            .fill(fillColor)
            .frame(width: 30, height: 30)
            .overlay {
                Text(labelText)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(textColor)
            }
    }
}
