import SwiftUI

struct CategoriesView: View {
    @Environment(AppState.self) private var appState
    @Environment(SessionStore.self) private var sessionStore
    @Environment(\.dismiss) private var dismiss

    let title: String
    let selectedCategoryID: ConvexID?
    let excludedCategoryIDs: Set<ConvexID>
    let dismissOnSelect: Bool
    let onSelect: (Category) -> Void

    @State private var searchText = ""

    init(
        title: String = "Categories",
        selectedCategoryID: ConvexID? = nil,
        excludedCategoryIDs: Set<ConvexID> = [],
        dismissOnSelect: Bool = true,
        onSelect: @escaping (Category) -> Void
    ) {
        self.title = title
        self.selectedCategoryID = selectedCategoryID
        self.excludedCategoryIDs = excludedCategoryIDs
        self.dismissOnSelect = dismissOnSelect
        self.onSelect = onSelect
    }

    var body: some View {
        ZStack {
            PatchworkBackdrop(tint: PatchworkTheme.brand)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PatchworkSectionIntro(
                        eyebrow: "Browse",
                        title: title,
                        message: "Choose a category that best matches the work you want to do."
                    )
                    .padding(.top, 12)

                    if categoriesUnavailable {
                        PatchworkSurfaceCard {
                            VStack(spacing: 16) {
                                Circle()
                                    .fill(PatchworkTheme.brandSoft)
                                    .frame(width: 76, height: 76)
                                    .overlay {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.system(size: 28, weight: .semibold))
                                            .foregroundStyle(PatchworkTheme.brand)
                                    }

                                Text("Categories unavailable")
                                    .font(.patchworkCardTitle)
                                    .foregroundStyle(PatchworkTheme.textPrimary)

                                Text(categoryAvailabilityMessage)
                                    .font(.patchworkBody)
                                    .foregroundStyle(PatchworkTheme.textSecondary)
                                    .multilineTextAlignment(.center)

                                Button("Retry categories") {
                                    Task { await retryCategories() }
                                }
                                .buttonStyle(PatchworkPrimaryButtonStyle())
                                .accessibilityIdentifier("Categories.retryButton")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .accessibilityIdentifier("Categories.retryState")
                    } else if filteredCategories.isEmpty {
                        PatchworkSurfaceCard {
                            VStack(spacing: 16) {
                                Circle()
                                    .fill(PatchworkTheme.brandSoft)
                                    .frame(width: 76, height: 76)
                                    .overlay {
                                        Image(systemName: "magnifyingglass")
                                            .font(.system(size: 28, weight: .semibold))
                                            .foregroundStyle(PatchworkTheme.brand)
                                    }

                                Text("No categories found")
                                    .font(.patchworkCardTitle)
                                    .foregroundStyle(PatchworkTheme.textPrimary)

                                Text("Try a different search term.")
                                    .font(.patchworkBody)
                                    .foregroundStyle(PatchworkTheme.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .accessibilityIdentifier("Categories.emptyState")
                    } else {
                        ForEach(groupedCategories, id: \.key) { group, categories in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(group.uppercased())
                                    .font(.patchworkCaption)
                                    .tracking(1.1)
                                    .foregroundStyle(PatchworkTheme.textSecondary)

                                ForEach(categories) { category in
                                    Button {
                                        onSelect(category)
                                        if dismissOnSelect {
                                            dismiss()
                                        }
                                    } label: {
                                        HStack(spacing: 14) {
                                            Text(category.emoji ?? "📋")
                                                .font(.title3)

                                            Text(category.name)
                                                .font(.patchworkBody)
                                                .foregroundStyle(PatchworkTheme.textPrimary)

                                            Spacer()

                                            if category.id == selectedCategoryID {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundStyle(PatchworkTheme.brand)
                                                    .accessibilityIdentifier("Categories.selectedBadge")
                                            } else {
                                                Image(systemName: "chevron.right")
                                                    .font(.caption.weight(.bold))
                                                    .foregroundStyle(PatchworkTheme.textTertiary)
                                            }
                                        }
                                        .padding(16)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(PatchworkTheme.surface.opacity(0.92), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                .stroke(category.id == selectedCategoryID ? PatchworkTheme.strokeStrong : PatchworkTheme.stroke, lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("Categories.row.\(category.slug)")
                                }
                            }
                            .padding(.bottom, 6)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(title)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search categories")
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled(true)
        .accessibilityIdentifier("Categories.list")
    }

    private var filteredCategories: [Category] {
        let availableCategories = appState.categories.filter { !excludedCategoryIDs.contains($0.id) }
        guard !searchText.isEmpty else { return availableCategories }
        return availableCategories.filter { category in
            category.name.localizedStandardContains(searchText)
        }
    }

    private var categoriesUnavailable: Bool {
        appState.categories.isEmpty || appState.categoriesErrorMessage != nil
    }

    private var categoryAvailabilityMessage: String {
        if let errorMessage = appState.categoriesErrorMessage, !errorMessage.isEmpty {
            return errorMessage
        }
        return "We could not load the category library. Try again."
    }

    private func retryCategories() async {
        await appState.refreshCategories(client: sessionStore.client)
    }

    private var groupedCategories: [(key: String, value: [Category])] {
        let grouped = Dictionary(grouping: filteredCategories) { category in
            category.group ?? "Other"
        }
        return grouped.sorted(by: { $0.key < $1.key })
    }
}
