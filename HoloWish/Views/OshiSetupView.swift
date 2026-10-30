import SwiftUI

/// First-run setup: the user picks an oshi, whose palette becomes the app's first theme.
struct OshiSetupView: View {
    private enum Step { case welcome, pick }

    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = Step.welcome
    @State private var selection: AppTheme?
    @State private var category: AppThemeCategory?
    @State private var searchText = ""
    @State private var featured = Array(AppTheme.allCases.filter { $0.status == nil }.shuffled().prefix(5))

    private var colors: ThemeColors? { selection?.colors(for: colorScheme) }
    private var background: Color { colors?.background ?? Color(.systemBackground) }
    private var surface: Color { colors?.surface ?? Color(.secondarySystemBackground) }
    private var primaryText: Color { colors?.primaryText ?? .primary }
    private var secondaryText: Color { colors?.secondaryText ?? .secondary }
    private var accent: Color { colors?.accent ?? .accentColor }

    private var visibleThemes: [AppTheme] {
        let categories = category.map { [$0] } ?? AppThemeCategory.allCases
        return categories.flatMap { AppTheme.cases(in: $0, matching: searchText) }
    }

    var body: some View {
        ZStack {
            switch step {
            case .welcome:
                welcome
                    .transition(.asymmetric(insertion: .opacity, removal: .opacity.combined(with: .scale(scale: 0.96))))
            case .pick:
                picker
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.45), value: step)
        .animation(.easeInOut(duration: 0.3), value: selection)
        .tint(accent)
    }

    // MARK: Welcome

    private var welcome: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 24)

            portraitFan
                .accessibilityHidden(true)

            VStack(spacing: 10) {
                Text("Welcome to holoWish")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(primaryText)
                Text("Track your hololive OCG wishlist and collection. First, tell us who you support — their colors will theme the whole app.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(secondaryText)
            }
            .padding(.horizontal, 28)

            Spacer(minLength: 24)

            Button {
                step = .pick
            } label: {
                Text("Choose My Oshi")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(welcomeBackground.ignoresSafeArea())
    }

    private var welcomeBackground: some View {
        let hues = featured.prefix(3).map { $0.colors(for: colorScheme).accent.opacity(colorScheme == .dark ? 0.32 : 0.22) }
        return ZStack {
            Color(.systemBackground)
            LinearGradient(colors: hues + [Color(.systemBackground)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private var portraitFan: some View {
        let angles: [Double] = [-16, -8, 0, 8, 16]
        let offsets: [CGFloat] = [-112, -58, 0, 58, 112]
        return ZStack {
            ForEach(Array(featured.enumerated()), id: \.element) { index, theme in
                TalentPortraitView(theme: theme, cornerRadius: 22)
                    .frame(width: index == 2 ? 124 : 98, height: index == 2 ? 124 : 98)
                    .background(theme.colors(for: colorScheme).surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
                    .rotationEffect(.degrees(angles[index]))
                    .offset(x: offsets[index], y: abs(offsets[index]) * 0.22)
                    .zIndex(index == 2 ? 2 : (index == 1 || index == 3 ? 1 : 0))
            }
        }
        .frame(height: 170)
    }

    // MARK: Picker

    private var picker: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if searchText.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Who’s your oshi?")
                                .font(.title.bold())
                                .foregroundStyle(primaryText)
                            Text("Their portrait and colors become your first theme. You can change it anytime in Settings.")
                                .font(.subheadline)
                                .foregroundStyle(secondaryText)
                        }
                    }

                    categoryChips

                    if visibleThemes.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                            .frame(maxWidth: .infinity, minHeight: 240)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 12, alignment: .top)], spacing: 16) {
                            ForEach(visibleThemes) { theme in
                                oshiTile(theme)
                            }
                        }
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.immediately)
            .background(background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        step = .welcome
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                    }
                }
            }
            .toolbarBackground(background, for: .navigationBar)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search talents")
            .safeAreaInset(edge: .bottom) { confirmBar }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("All", isSelected: category == nil) { category = nil }
                ForEach(AppThemeCategory.allCases) { item in
                    chip(item.rawValue, isSelected: category == item) { category = item }
                }
            }
            .padding(.horizontal, 1)
        }
        .scrollClipDisabled()
    }

    private func chip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frame(minHeight: 36)
                .foregroundStyle(isSelected ? background : primaryText)
                .background(isSelected ? accent : surface, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func oshiTile(_ theme: AppTheme) -> some View {
        let isSelected = theme == selection
        let palette = theme.colors(for: colorScheme)
        return Button {
            selection = isSelected ? nil : theme
        } label: {
            VStack(spacing: 8) {
                TalentPortraitView(theme: theme, cornerRadius: 20)
                    .aspectRatio(1, contentMode: .fit)
                    .background(palette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(isSelected ? palette.accent : .clear, lineWidth: 3)
                    }
                    .overlay(alignment: .topTrailing) {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, palette.accent)
                                .padding(6)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .scaleEffect(isSelected && !reduceMotion ? 1.04 : 1)

                VStack(spacing: 2) {
                    Text(theme.rawValue)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(primaryText)
                        .lineLimit(2)
                    Text(theme.japaneseName)
                        .font(.caption2)
                        .foregroundStyle(secondaryText)
                        .lineLimit(1)
                }
                .multilineTextAlignment(.center)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(theme.rawValue), \(theme.japaneseName)")
        .accessibilityValue(theme.status?.label ?? "")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
    }

    private var confirmBar: some View {
        VStack(spacing: 0) {
            Divider().opacity(selection == nil ? 1 : 0)
            HStack(spacing: 12) {
                if let selection {
                    TalentPortraitView(theme: selection, cornerRadius: 12)
                        .frame(width: 48, height: 48)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selection.rawValue)
                            .font(.headline)
                            .foregroundStyle(primaryText)
                            .lineLimit(1)
                        Text(selection.paletteDescription)
                            .font(.caption)
                            .foregroundStyle(secondaryText)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("Tap a talent to preview their theme")
                        .font(.subheadline)
                        .foregroundStyle(secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    guard let selection else { return }
                    themeStore.chooseOshi(selection)
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .padding(.horizontal, 6)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .disabled(selection == nil)
                .accessibilityHint(selection.map { "Sets \($0.rawValue) as your oshi theme" } ?? "Choose a talent first")
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(surface.opacity(0.94).ignoresSafeArea(edges: .bottom))
        .background(.bar)
    }
}
