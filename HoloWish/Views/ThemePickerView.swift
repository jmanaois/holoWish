import SwiftUI

struct ThemePickerView: View {
    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let active = themeStore.colors(for: colorScheme)
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    Text("Each palette automatically follows your iPhone or iPad’s light and dark appearance.")
                        .font(.subheadline)
                        .foregroundStyle(active.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 4)
                    ForEach(AppTheme.allCases) { theme in
                        let colors = theme.colors(for: colorScheme)
                        Button {
                            themeStore.selected = theme
                        } label: {
                            HStack(spacing: 14) {
                                HStack(spacing: -8) {
                                    swatch(colors.accent)
                                    swatch(colors.secondaryAccent)
                                    swatch(colors.surface)
                                }
                                .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(theme.rawValue).font(.headline).foregroundStyle(active.primaryText)
                                    Text(theme.paletteDescription)
                                        .font(.caption).foregroundStyle(active.secondaryText)
                                }
                                Spacer()
                                if theme == themeStore.selected {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(active.accent).font(.title3)
                                }
                            }
                            .padding(14)
                            .background(active.surface, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(theme.rawValue)
                        .accessibilityValue(theme == themeStore.selected ? "Selected" : "")
                        .accessibilityAddTraits(theme == themeStore.selected ? [.isSelected] : [])
                    }
                }
                .padding()
            }
            .background(active.background)
            .navigationTitle("Themes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .tint(active.accent)
        }
    }

    private func swatch(_ color: Color) -> some View {
        Circle().fill(color).frame(width: 34, height: 34)
            .overlay(Circle().stroke(themeStore.colors(for: colorScheme).primaryText.opacity(0.25), lineWidth: 1))
    }
}
