import SwiftUI

struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @Environment(SessionStore.self) private var sessionStore

    let onSignOut: () -> Void

    var body: some View {
        List {
            ProfileAccountSection(name: appState.currentUser?.name, email: appState.currentUser?.email)
            ProfileTaskerSection(isTaskerConfigured: appState.taskerProfile != nil)
            ProfileSupportSection()
            ProfileSignOutSection(onSignOut: onSignOut)
        }
        .navigationTitle("Profile")
        .task {
            await appState.refreshAuthedData(client: sessionStore.client)
        }
    }
}

private struct ProfileAccountSection: View {
    let name: String?
    let email: String?

    var body: some View {
        Section("Account") {
            Text(name ?? "Signed in")
            Text(email ?? "")
                .foregroundStyle(.secondary)
        }
    }
}

private struct ProfileTaskerSection: View {
    let isTaskerConfigured: Bool

    var body: some View {
        Section("Tasker") {
            NavigationLink(isTaskerConfigured ? "Manage Tasker Profile" : "Become a Tasker") {
                TaskerOnboardingView()
            }
            .accessibilityIdentifier("Profile.taskerOnboardingLink")

            NavigationLink("Category Library") {
                CategoriesView(title: "Category Library", dismissOnSelect: false, onSelect: { _ in })
            }
            .accessibilityIdentifier("Profile.categoryLibraryLink")

            NavigationLink("Subscription") {
                SubscriptionsView()
            }
            .accessibilityIdentifier("Profile.subscriptionLink")

            NavigationLink("Premium Upgrade") {
                PremiumUpgradeView()
            }
            .accessibilityIdentifier("Profile.premiumUpgradeLink")
        }
    }
}

private struct ProfileSupportSection: View {
    var body: some View {
        Section("Support") {
            NavigationLink("Help") {
                HelpView()
            }
            .accessibilityIdentifier("Profile.helpLink")
        }
    }
}

private struct ProfileSignOutSection: View {
    let onSignOut: () -> Void

    var body: some View {
        Section {
            Button("Sign Out", role: .destructive) {
                onSignOut()
            }
            .accessibilityIdentifier("Profile.signOutButton")
        }
    }
}

struct TaskerOnboardingView: View {
    @Environment(AppState.self) private var appState
    @Environment(SessionStore.self) private var sessionStore
    @Environment(\.dismiss) private var dismiss

    @State private var step = 1
    @State private var displayName = ""
    @State private var selectedCategoryId: ConvexID?

    @State private var categoryBio = ""
    @State private var rateType = "hourly"
    @State private var hourlyRate = ""
    @State private var fixedRate = ""
    @State private var serviceRadius = 25

    @State private var profileDisplayName = ""
    @State private var profileBio = ""
    @State private var addCategorySheet = false

    var body: some View {
        Group {
            if let profile = appState.taskerProfile {
                TaskerProfileManageView(
                    profileDisplayName: $profileDisplayName,
                    profileBio: $profileBio,
                    addCategorySheet: $addCategorySheet,
                    categories: appState.categories,
                    existingCategoryIDs: Set(profile.categories.map { $0.categoryId }),
                    onSaveProfile: { Task { await updateTaskerProfile() } },
                    onRemoveCategory: { categoryId in Task { await removeCategory(categoryId: categoryId) } },
                    onAddCategory: { draft in Task { await addCategory(draft: draft) } }
                )
                .onAppear {
                    profileDisplayName = profile.displayName
                    profileBio = profile.bio ?? ""
                }
            } else {
                TaskerCreateFlowView(
                    step: $step,
                    displayName: $displayName,
                    selectedCategoryId: $selectedCategoryId,
                    categories: appState.categories,
                    categoryBio: $categoryBio,
                    rateType: $rateType,
                    hourlyRate: $hourlyRate,
                    fixedRate: $fixedRate,
                    serviceRadius: $serviceRadius,
                    onSubmit: { Task { await createProfile() } },
                    onDone: { dismiss() }
                )
            }
        }
        .navigationTitle("Tasker Setup")
        .task {
            await appState.refreshAuthedData(client: sessionStore.client)
        }
    }

    private func createProfile() async {
        guard let selectedCategoryId else { return }

        let hourlyCents = Int((Double(hourlyRate) ?? 0) * 100)
        let fixedCents = Int((Double(fixedRate) ?? 0) * 100)
        var args: [String: Any] = [
            "displayName": displayName,
            "categoryId": selectedCategoryId,
            "categoryBio": categoryBio,
            "rateType": rateType,
            "serviceRadius": serviceRadius,
        ]
        if rateType == "hourly" {
            args["hourlyRate"] = max(hourlyCents, 1)
        } else {
            args["fixedRate"] = max(fixedCents, 1)
        }

        do {
            _ = try await sessionStore.client.mutation("taskers:createTaskerProfile", args: args) as ConvexID
            await appState.refreshAuthedData(client: sessionStore.client)
            step = 4
        } catch {
            appState.lastError = error.localizedDescription
        }
    }

    private func updateTaskerProfile() async {
        do {
            struct EmptyResult: Decodable {}
            _ = try await sessionStore.client.mutation(
                "taskers:updateTaskerProfile",
                args: [
                    "displayName": profileDisplayName,
                    "bio": profileBio,
                ]
            ) as EmptyResult
            await appState.refreshAuthedData(client: sessionStore.client)
        } catch {
            appState.lastError = error.localizedDescription
        }
    }

    private func removeCategory(categoryId: ConvexID) async {
        do {
            struct EmptyResult: Decodable {}
            _ = try await sessionStore.client.mutation(
                "taskers:removeTaskerCategory",
                args: ["categoryId": categoryId]
            ) as EmptyResult
            await appState.refreshAuthedData(client: sessionStore.client)
        } catch {
            appState.lastError = error.localizedDescription
        }
    }

    private func addCategory(draft: AddCategoryDraft) async {
        do {
            struct EmptyResult: Decodable {}
            _ = try await sessionStore.client.mutation(
                "taskers:addTaskerCategory",
                args: [
                    "categoryId": draft.categoryId,
                    "categoryBio": draft.categoryBio,
                    "rateType": draft.rateType,
                    "hourlyRate": draft.rateType == "hourly" ? max(Int((Double(draft.hourlyRate) ?? 0) * 100), 1) : nil,
                    "fixedRate": draft.rateType == "fixed" ? max(Int((Double(draft.fixedRate) ?? 0) * 100), 1) : nil,
                    "serviceRadius": draft.serviceRadius,
                ].compactMapValues { $0 }
            ) as EmptyResult
            await appState.refreshAuthedData(client: sessionStore.client)
            addCategorySheet = false
        } catch {
            appState.lastError = error.localizedDescription
        }
    }
}

private struct AddCategoryDraft {
    let categoryId: ConvexID
    let categoryBio: String
    let rateType: String
    let hourlyRate: String
    let fixedRate: String
    let serviceRadius: Int
}

private struct TaskerCreateFlowView: View {
    @Binding var step: Int
    @Binding var displayName: String
    @Binding var selectedCategoryId: ConvexID?
    let categories: [Category]
    @Binding var categoryBio: String
    @Binding var rateType: String
    @Binding var hourlyRate: String
    @Binding var fixedRate: String
    @Binding var serviceRadius: Int
    let onSubmit: () -> Void
    let onDone: () -> Void

    @State private var acceptedTerms = false

    private var canCompleteSetup: Bool {
        acceptedTerms
    }

    var body: some View {
        Form {
            Section {
                StepHeader(currentStep: min(step, 3))
            }

            switch step {
            case 1:
                Section("TaskerOnboarding1") {
                    TextField("Display name", text: $displayName)
                        .accessibilityIdentifier("TaskerOnboarding1.displayNameField")

                    NavigationLink {
                        CategoriesView(
                            title: "Select Primary Category",
                            selectedCategoryID: selectedCategoryId,
                            dismissOnSelect: true,
                            onSelect: { category in
                                selectedCategoryId = category.id
                            }
                        )
                    } label: {
                        HStack {
                            Text("Primary category")
                            Spacer()
                            Text(selectedCategoryName)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("TaskerOnboarding1.categoryPicker")
                }
                Section {
                    Button("Continue") {
                        step = 2
                    }
                    .disabled(displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedCategoryId == nil)
                    .accessibilityIdentifier("TaskerOnboarding1.continueButton")
                }
            case 2:
                CategoryServiceDetailsSection(
                    title: "TaskerOnboarding2",
                    bio: $categoryBio,
                    rateType: $rateType,
                    hourlyRate: $hourlyRate,
                    fixedRate: $fixedRate,
                    serviceRadius: $serviceRadius,
                    accessibilityPrefix: "TaskerOnboarding2"
                )

                Section {
                    Button("Back") { step = 1 }
                        .accessibilityIdentifier("TaskerOnboarding2.backButton")
                    Button("Continue") { step = 3 }
                        .disabled(categoryBio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("TaskerOnboarding2.continueButton")
                }
            case 3:
                Section("TaskerOnboarding4") {
                    Text("Review & accept")
                        .font(.headline)
                    Text("Final step to complete your Tasker profile.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    LabeledContent("Display name", value: displayName)
                    LabeledContent("Rate type", value: rateType.capitalized)
                    LabeledContent("Radius", value: "\(serviceRadius) km")

                    Toggle(isOn: $acceptedTerms) {
                        Text("I agree to the Tasker terms and community guidelines.")
                            .font(.subheadline)
                    }
                    .accessibilityIdentifier("TaskerOnboarding4.acceptTermsToggle")
                }

                Section {
                    Button("Back") { step = 2 }
                        .accessibilityIdentifier("TaskerOnboarding4.backButton")
                    Button("Complete Setup", action: onSubmit)
                        .disabled(!canCompleteSetup)
                        .accessibilityIdentifier("TaskerOnboarding4.completeButton")
                }
            default:
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.green)
                    Text("Tasker profile created")
                        .font(.title3.bold())
                    Text("To become discoverable to Seekers in your area, subscribe to a plan.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    NavigationLink("Subscribe") {
                        SubscriptionsView()
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("TaskerOnboarding4.subscribeButton")
                    Button("Done", action: onDone)
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("TaskerOnboarding4.doneButton")
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var selectedCategoryName: String {
        guard let selectedCategoryId,
              let selectedCategory = categories.first(where: { $0.id == selectedCategoryId }) else {
            return "Choose"
        }
        return selectedCategory.name
    }
}

private struct TaskerProfileManageView: View {
    @Environment(AppState.self) private var appState

    @Binding var profileDisplayName: String
    @Binding var profileBio: String
    @Binding var addCategorySheet: Bool
    let categories: [Category]
    let existingCategoryIDs: Set<ConvexID>
    let onSaveProfile: () -> Void
    let onRemoveCategory: (ConvexID) -> Void

    let onAddCategory: (AddCategoryDraft) -> Void

    @State private var selectedCategory: TaskerManagedCategory?

    var body: some View {
        Form {
            Section("Profile") {
                TextField("Display name", text: $profileDisplayName)
                    .accessibilityIdentifier("TaskerProfile.displayNameField")
                TextEditor(text: $profileBio)
                    .frame(minHeight: 100)
                    .accessibilityIdentifier("TaskerProfile.bioField")
                Button("Save", action: onSaveProfile)
                    .accessibilityIdentifier("TaskerProfile.saveButton")
            }

            Section("Categories") {
                NavigationLink("Browse Category Library") {
                    CategoriesView(title: "Category Library", dismissOnSelect: false, onSelect: { _ in })
                }
                .accessibilityIdentifier("TaskerProfile.categoryLibraryLink")

                ForEach(appState.taskerProfile?.categories ?? []) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(category.categoryName)
                                Text(category.rateType.capitalized)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("TaskerProfile.category.\(category.categoryId)")
                }

                Button("Add Category") {
                    addCategorySheet = true
                }
                .accessibilityIdentifier("TaskerProfile.addCategoryButton")

                NavigationLink("Category Help") {
                    HelpView()
                }
                .accessibilityIdentifier("TaskerProfile.categoryHelpLink")
            }
        }
        .sheet(isPresented: $addCategorySheet) {
            AddCategorySheet(
                categories: categories,
                existingCategoryIDs: existingCategoryIDs,
                onAdd: onAddCategory
            )
        }
        .sheet(item: $selectedCategory) { category in
            CategoryDetailSheet(
                category: category,
                onRemove: {
                    onRemoveCategory(category.categoryId)
                    selectedCategory = nil
                }
            )
        }
    }
}

private struct CategoryServiceDetailsSection: View {
    let title: String
    @Binding var bio: String
    @Binding var rateType: String
    @Binding var hourlyRate: String
    @Binding var fixedRate: String
    @Binding var serviceRadius: Int
    let accessibilityPrefix: String

    var body: some View {
        Section(title) {
            TextEditor(text: $bio)
                .frame(minHeight: 90)
                .accessibilityIdentifier("\(accessibilityPrefix).bioField")

            Picker("Rate type", selection: $rateType) {
                Text("Hourly").tag("hourly")
                Text("Fixed").tag("fixed")
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("\(accessibilityPrefix).rateTypePicker")

            if rateType == "hourly" {
                TextField("Hourly rate", text: $hourlyRate)
                    .keyboardType(.decimalPad)
                    .accessibilityIdentifier("\(accessibilityPrefix).hourlyRateField")
            } else {
                TextField("Fixed rate", text: $fixedRate)
                    .keyboardType(.decimalPad)
                    .accessibilityIdentifier("\(accessibilityPrefix).fixedRateField")
            }

            Stepper("Service radius: \(serviceRadius) km", value: $serviceRadius, in: 1 ... 250)
                .accessibilityIdentifier("\(accessibilityPrefix).radiusStepper")
        }
    }
}

private struct AddCategorySheet: View {
    @Environment(\.dismiss) private var dismiss

    let categories: [Category]
    let existingCategoryIDs: Set<ConvexID>
    let onAdd: (AddCategoryDraft) -> Void

    @State private var selectedCategoryId: ConvexID?
    @State private var categoryBio = ""
    @State private var rateType = "hourly"
    @State private var hourlyRate = ""
    @State private var fixedRate = ""
    @State private var serviceRadius = 25

    var body: some View {
        NavigationStack {
            Form {
                Section("Category") {
                    NavigationLink {
                        CategoriesView(
                            title: "Select Category",
                            selectedCategoryID: selectedCategoryId,
                            excludedCategoryIDs: existingCategoryIDs,
                            dismissOnSelect: true,
                            onSelect: { category in
                                selectedCategoryId = category.id
                            }
                        )
                    } label: {
                        HStack {
                            Text("Category")
                            Spacer()
                            Text(selectedCategoryName)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("AddCategorySheet.categoryPicker")
                }

                CategoryServiceDetailsSection(
                    title: "Details",
                    bio: $categoryBio,
                    rateType: $rateType,
                    hourlyRate: $hourlyRate,
                    fixedRate: $fixedRate,
                    serviceRadius: $serviceRadius,
                    accessibilityPrefix: "AddCategorySheet"
                )
            }
            .navigationTitle("Add Category")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("AddCategorySheet.cancelButton")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        guard let selectedCategoryId else { return }
                        onAdd(
                            AddCategoryDraft(
                                categoryId: selectedCategoryId,
                                categoryBio: categoryBio,
                                rateType: rateType,
                                hourlyRate: hourlyRate,
                                fixedRate: fixedRate,
                                serviceRadius: serviceRadius
                            )
                        )
                    }
                    .disabled(!canSubmit)
                    .accessibilityIdentifier("AddCategorySheet.addButton")
                }
            }
        }
    }

    private var availableCategories: [Category] {
        categories.filter { !existingCategoryIDs.contains($0.id) }
    }

    private var selectedCategoryName: String {
        guard let selectedCategoryId,
              let selectedCategory = availableCategories.first(where: { $0.id == selectedCategoryId }) else {
            return "Choose"
        }
        return selectedCategory.name
    }

    private var canSubmit: Bool {
        guard selectedCategoryId != nil,
              !categoryBio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        if rateType == "hourly" {
            return (Double(hourlyRate) ?? 0) > 0
        }
        return (Double(fixedRate) ?? 0) > 0
    }
}

private struct CategoryDetailSheet: View {
    @Environment(\.dismiss) private var dismiss

    let category: TaskerManagedCategory
    let onRemove: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("Rate") {
                    LabeledContent("Type", value: category.rateType.capitalized)
                    LabeledContent("Price", value: priceLabel)
                    LabeledContent("Service Radius", value: "\(category.serviceRadius) km")
                }

                Section("Bio") {
                    Text(category.bio)
                        .foregroundStyle(.secondary)
                }

                Section("Performance") {
                    LabeledContent("Rating", value: ratingLabel)
                    LabeledContent("Reviews", value: "\(category.reviewCount ?? 0)")
                    LabeledContent("Completed Jobs", value: "\(category.completedJobs ?? 0)")
                }

                Section {
                    Button("Remove Category", role: .destructive) {
                        onRemove()
                    }
                    .accessibilityIdentifier("TaskerProfile.removeCategoryButton")
                }
            }
            .navigationTitle(category.categoryName)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .accessibilityIdentifier("TaskerProfile.categoryCloseButton")
                }
            }
        }
    }

    private var priceLabel: String {
        if category.rateType == "hourly", let hourlyRate = category.hourlyRate {
            return "$\(String(format: "%.2f", Double(hourlyRate) / 100))/hr"
        }
        if let fixedRate = category.fixedRate {
            return "$\(String(format: "%.2f", Double(fixedRate) / 100))"
        }
        return "-"
    }

    private var ratingLabel: String {
        guard let rating = category.rating else { return "0.0" }
        return String(format: "%.1f", rating)
    }
}

struct SubscriptionsView: View {
    @Environment(AppState.self) private var appState
    @Environment(SessionStore.self) private var sessionStore

    @State private var isUpdating = false

    var body: some View {
        List {
            Section("Plan") {
                Text("Current: \((appState.taskerProfile?.subscriptionPlan ?? "none").capitalized)")
                    .foregroundStyle(.secondary)
                Button("Subscribe Basic ($7)") {
                    Task { await subscribe(plan: "basic") }
                }
                .disabled(isUpdating)
                .accessibilityIdentifier("Subscription.basicButton")
                Button("Subscribe Premium ($15)") {
                    Task { await subscribe(plan: "premium") }
                }
                .disabled(isUpdating)
                .accessibilityIdentifier("Subscription.premiumButton")
            }

            if let profile = appState.taskerProfile,
               profile.subscriptionPlan != "none" {
                Section("Ghost Mode") {
                    Toggle("Hidden from discovery", isOn: Binding(
                        get: { profile.ghostMode },
                        set: { value in Task { await setGhostMode(value) } }
                    ))
                    .accessibilityIdentifier("Subscription.ghostToggle")
                }
            }

            if let pin = appState.taskerProfile?.premiumPin,
               appState.taskerProfile?.subscriptionPlan == "premium" {
                Section("Premium PIN") {
                    Text(pin)
                        .font(.title3.monospacedDigit())
                }
            }
        }
        .navigationTitle("Subscriptions")
    }

    private func subscribe(plan: String) async {
        isUpdating = true
        defer { isUpdating = false }
        do {
            struct EmptyResult: Decodable {}
            _ = try await sessionStore.client.mutation("taskers:updateSubscriptionPlan", args: ["plan": plan]) as EmptyResult
            await appState.refreshAuthedData(client: sessionStore.client)
        } catch {
            appState.lastError = error.localizedDescription
        }
    }

    private func setGhostMode(_ enabled: Bool) async {
        do {
            struct EmptyResult: Decodable {}
            _ = try await sessionStore.client.mutation("taskers:setGhostMode", args: ["ghostMode": enabled]) as EmptyResult
            await appState.refreshAuthedData(client: sessionStore.client)
        } catch {
            appState.lastError = error.localizedDescription
        }
    }
}

private struct PremiumUpgradeView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 42))
                .foregroundStyle(.indigo)
            Text("Upgrade to Premium")
                .font(.title2.bold())
            Text("Unlock multi-category support and premium visibility controls.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Close") { dismiss() }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("PremiumUpgradeView.closeButton")
        }
        .padding(24)
    }
}

private struct HelpView: View {
    private let faqs: [(question: String, category: String)] = [
        ("How accurate is location tracking?", "Location"),
        ("What if no Taskers are available?", "Search"),
        ("How do I report a safety concern?", "Safety"),
        ("Can Taskers pay for better placement?", "Reviews"),
        ("How are rankings determined?", "Reviews"),
        ("What if I need to cancel a job?", "Jobs"),
    ]

    var body: some View {
        List {
            Section("Frequently asked questions") {
                ForEach(Array(faqs.enumerated()), id: \.offset) { index, faq in
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(faq.question)
                            Text(faq.category)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .accessibilityIdentifier("Help.faq.\(index)")
                }
            }

            Section("Support") {
                LabeledContent("Email", value: "support@patchwork.app")
                    .textSelection(.enabled)
                    .accessibilityIdentifier("Help.emailSupport")
                LabeledContent("Phone", value: "1-800-PATCH-WK")
                    .accessibilityIdentifier("Help.phoneSupport")
                Text("Mon-Fri, 9 AM - 5 PM ET")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Ranking promise") {
                Text("Patchwork never accepts payment for better placement. Rankings are based solely on:")
                    .foregroundStyle(.secondary)
                Text("• Verified client reviews and ratings")
                Text("• Proximity to your location")
                Text("• Recent activity and response time")
                Text("• Completion rate and reliability")
            }
        }
        .navigationTitle("Help")
        .accessibilityIdentifier("Help.list")
    }
}

private struct StepHeader: View {
    let currentStep: Int

    var body: some View {
        HStack(spacing: 12) {
            ForEach(1 ... 3, id: \.self) { value in
                Circle()
                    .fill(value <= currentStep ? Color.indigo : Color.gray.opacity(0.2))
                    .frame(width: 28, height: 28)
                    .overlay {
                        Text(value <= currentStep && value < currentStep ? "\u{2713}" : "\(value)")
                            .font(.caption.bold())
                            .foregroundStyle(value <= currentStep ? .white : .secondary)
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}
