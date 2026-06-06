import SwiftUI
import UIKit

private struct PatchworkInputFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.patchworkBody)
            .foregroundStyle(PatchworkTheme.textPrimary)
            .padding(.horizontal, 16)
            .frame(height: PatchworkMetrics.fieldHeight)
            .background(
                PatchworkTheme.surface,
                in: RoundedRectangle(cornerRadius: PatchworkMetrics.controlRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PatchworkMetrics.controlRadius, style: .continuous)
                    .stroke(PatchworkTheme.stroke, lineWidth: 1)
            )
    }
}

private struct PatchworkTextEditorModifier: ViewModifier {
    let minHeight: CGFloat

    func body(content: Content) -> some View {
        content
            .font(.patchworkBody)
            .foregroundStyle(PatchworkTheme.textPrimary)
            .scrollContentBackground(.hidden)
            .frame(minHeight: minHeight)
            .padding(10)
            .background(
                PatchworkTheme.surface,
                in: RoundedRectangle(cornerRadius: PatchworkMetrics.controlRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PatchworkMetrics.controlRadius, style: .continuous)
                    .stroke(PatchworkTheme.stroke, lineWidth: 1)
            )
    }
}

private struct PatchworkInsetSurfaceModifier: ViewModifier {
    let fill: Color
    let stroke: Color
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(fill, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(stroke, lineWidth: 1)
            )
    }
}

extension View {
    func patchworkInputFieldStyle() -> some View {
        modifier(PatchworkInputFieldModifier())
    }

    func patchworkTextEditorStyle(minHeight: CGFloat = 120) -> some View {
        modifier(PatchworkTextEditorModifier(minHeight: minHeight))
    }

    func patchworkInsetSurface(
        fill: Color = PatchworkTheme.surfaceMuted,
        stroke: Color = PatchworkTheme.stroke,
        cornerRadius: CGFloat = PatchworkMetrics.controlRadius
    ) -> some View {
        modifier(PatchworkInsetSurfaceModifier(fill: fill, stroke: stroke, cornerRadius: cornerRadius))
    }

    func patchworkKeyboardDismissToolbar(isPresented: Bool = true) -> some View {
        toolbar {
            if isPresented {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        PatchworkKeyboard.dismiss()
                    }
                }
            }
        }
    }
}

struct HomeBaseDropdownField: View {
    let placeholder: String
    @Binding var text: String
    @Binding var selectedHomeBase: HomeBaseOption?
    let fieldAccessibilityIdentifier: String
    let suggestionAccessibilityPrefix: String
    let noResultsAccessibilityIdentifier: String
    let noResultsMessage: String
    let onTextChanged: () -> Void
    let onSelect: (HomeBaseOption) -> Void

    @FocusState private var isFocused: Bool

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var matchingSuggestions: [HomeBaseOption] {
        guard trimmedText.count >= 3 else {
            return []
        }

        let lowercasedQuery = trimmedText.lowercased()
        return HomeBaseOptions.all
            .filter { suggestion in
                suggestion.city.lowercased().hasPrefix(lowercasedQuery)
                    || suggestion.label.lowercased().contains(lowercasedQuery)
            }
            .prefix(6)
            .map { $0 }
    }

    private var showsDropdown: Bool {
        isFocused && trimmedText.count >= 3
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField(placeholder, text: $text)
                .font(.patchworkBody)
                .foregroundStyle(PatchworkTheme.textPrimary)
                .textContentType(.addressCity)
                .padding(.horizontal, 16)
                .frame(height: PatchworkMetrics.fieldHeight)
                .focused($isFocused)
                .accessibilityIdentifier(fieldAccessibilityIdentifier)
                .onChange(of: text) { _, _ in
                    onTextChanged()
                }

            if showsDropdown {
                Divider()
                    .overlay(PatchworkTheme.stroke)

                if matchingSuggestions.isEmpty {
                    Text(noResultsMessage)
                        .font(.patchworkCaption)
                        .foregroundStyle(PatchworkTheme.textTertiary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .accessibilityIdentifier(noResultsAccessibilityIdentifier)
                } else {
                    VStack(spacing: 0) {
                        ForEach(matchingSuggestions) { suggestion in
                            Button {
                                selectedHomeBase = suggestion
                                onSelect(suggestion)
                                isFocused = false
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: selectedHomeBase == suggestion ? "checkmark.circle.fill" : "mappin.and.ellipse")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(selectedHomeBase == suggestion ? PatchworkTheme.success : PatchworkTheme.brand)
                                        .accessibilityHidden(true)

                                    Text(suggestion.label)
                                        .font(.patchworkBodyStrong)
                                        .foregroundStyle(PatchworkTheme.textPrimary)

                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("\(suggestionAccessibilityPrefix).\(suggestion.id)")

                            if suggestion.id != matchingSuggestions.last?.id {
                                Divider()
                                    .padding(.leading, 42)
                                    .overlay(PatchworkTheme.stroke.opacity(0.7))
                            }
                        }
                    }
                }
            }
        }
        .background(
            PatchworkTheme.surface,
            in: RoundedRectangle(cornerRadius: PatchworkMetrics.controlRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PatchworkMetrics.controlRadius, style: .continuous)
                .stroke(showsDropdown ? PatchworkTheme.brand.opacity(0.45) : PatchworkTheme.stroke, lineWidth: 1)
        )
    }
}

enum PatchworkKeyboard {
    static func dismiss() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
