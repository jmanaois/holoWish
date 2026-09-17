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
                    Text("Each palette includes coordinated colors for both light and dark appearance.")
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

struct SettingsView: View {
    @Environment(AppSettings.self) private var appSettings
    @Environment(ThemeStore.self) private var themeStore
    @Environment(CardCatalog.self) private var catalog
    @Environment(CardArtworkStore.self) private var artwork
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var showingThemes = false
    @State private var showingClearArtworkConfirmation = false

    var body: some View {
        @Bindable var appSettings = appSettings
        let colors = themeStore.colors(for: colorScheme)

        NavigationStack {
            Form {
                Section("Appearance") {
                    Button { showingThemes = true } label: {
                        HStack {
                            Label("Theme", systemImage: "paintpalette.fill")
                            Spacer()
                            Text(themeStore.selected.rawValue)
                                .foregroundStyle(colors.secondaryText)
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundStyle(colors.secondaryText)
                        }
                    }
                    .foregroundStyle(colors.primaryText)

                    Picker("Appearance", selection: $appSettings.appearance) {
                        ForEach(AppAppearance.allCases) { appearance in
                            Text(appearance.rawValue).tag(appearance)
                        }
                    }

                    Picker("Card names", selection: $appSettings.cardNamePreference) {
                        ForEach(CardNamePreference.allCases) { preference in
                            Text(preference.rawValue).tag(preference)
                        }
                    }
                }

                Section {
                    Picker("Quick add to Collection", selection: $appSettings.quickAddBehavior) {
                        ForEach(QuickAddBehavior.allCases) { behavior in
                            Text(behavior.rawValue).tag(behavior)
                        }
                    }
                } header: {
                    Text("Collection")
                } footer: {
                    Text("Controls whether a long-press quick add saves immediately or asks for quantity and purchase price.")
                }

                Section("Catalog") {
                    LabeledContent("Cards", value: catalog.cards.count.formatted())
                    LabeledContent("Last synced", value: catalogSyncDescription)
                    Button {
                        Task { await catalog.checkForUpdates(force: true) }
                    } label: {
                        Label(catalog.isCheckingForUpdates ? "Checking…" : "Check for Updates", systemImage: "arrow.clockwise")
                    }
                    .disabled(catalog.isCheckingForUpdates)
                    if let message = catalog.updateMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(colors.secondaryText)
                    }
                }

                Section {
                    HStack {
                        Label("Offline artwork", systemImage: "arrow.down.circle.fill")
                        Spacer()
                        Text("\(artwork.downloadedCount) / \(artwork.totalCount)")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(colors.secondaryText)
                    }
                    ProgressView(value: artwork.progress).tint(colors.accent)
                    if artwork.downloadedCount < artwork.totalCount {
                        Button {
                            if artwork.isDownloading { artwork.pauseDownloading() }
                            else { artwork.beginDownloading(catalog.cards) }
                        } label: {
                            Label(
                                artwork.isDownloading ? "Pause Download" : "Download Missing Artwork",
                                systemImage: artwork.isDownloading ? "pause.circle" : "arrow.down.circle"
                            )
                        }
                    }
                    if artwork.downloadedCount > 0 {
                        Button("Clear Downloaded Artwork", role: .destructive) {
                            showingClearArtworkConfirmation = true
                        }
                    }
                } header: {
                    Text("Storage")
                } footer: {
                    Text("Clearing artwork does not remove your collection, wishlist, or purchase history.")
                }

                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    Link(destination: URL(string: "https://hololive-official-cardgame.com/cardlist/?lang=ja")!) {
                        Label("Official Card List", systemImage: "arrow.up.right.square")
                    }
                    Link(destination: URL(string: "https://github.com/jmanaois/holoWish")!) {
                        Label("holoWish on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Privacy").font(.subheadline.bold())
                        Text("Your collection, wishlist, purchase history, and preferences stay on this device. Catalog and artwork requests are downloaded from their listed sources.")
                            .font(.caption)
                            .foregroundStyle(colors.secondaryText)
                    }
                    .padding(.vertical, 4)
                }
            }
            .scrollContentBackground(.hidden)
            .background(colors.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
            .tint(colors.accent)
            .sheet(isPresented: $showingThemes) { ThemePickerView() }
            .alert("Clear downloaded artwork?", isPresented: $showingClearArtworkConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Clear Artwork", role: .destructive) {
                    Task { await artwork.clearDownloadedArtwork() }
                }
            } message: {
                Text("Card and product images can be downloaded again later.")
            }
        }
    }

    private var catalogSyncDescription: String {
        guard let value = catalog.syncedAt, !value.isEmpty else { return "Bundled" }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return date.formatted(date: .abbreviated, time: .omitted)
        }
        return value
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }
}
