import SwiftUI

struct CategoriesView: View {
    @Environment(AppState.self) private var appState
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
        List {
            if filteredCategories.isEmpty {
                ContentUnavailableView(
                    "No categories found",
                    systemImage: "magnifyingglass",
                    description: Text("Try a different search term.")
                )
                .accessibilityIdentifier("Categories.emptyState")
            } else {
                ForEach(groupedCategories, id: \.key) { group, categories in
                    Section(group) {
                        ForEach(categories) { category in
                            Button {
                                onSelect(category)
                                if dismissOnSelect {
                                    dismiss()
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Text(category.emoji ?? "📋")
                                        .font(.body)
                                    Text(category.name)
                                    Spacer()
                                    if category.id == selectedCategoryID {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.indigo)
                                            .accessibilityIdentifier("Categories.selectedBadge")
                                    }
                                }
                            }
                            .accessibilityIdentifier("Categories.row.\(category.slug)")
                        }
                    }
                }
            }
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

    private var groupedCategories: [(key: String, value: [Category])] {
        let grouped = Dictionary(grouping: filteredCategories) { category in
            category.group ?? "Other"
        }
        return grouped.sorted(by: { $0.key < $1.key })
    }
}
