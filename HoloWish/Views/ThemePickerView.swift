import SwiftUI
import UIKit

struct ThemePickerView: View {
    enum Mode { case theme, favorites }

    var mode = Mode.theme
    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    var body: some View {
        let active = themeStore.colors(for: colorScheme)
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12, pinnedViews: [.sectionHeaders]) {
                    if searchText.isEmpty {
                        Text(mode == .theme
                             ? "Choose a talent portrait and a coordinated palette for light and dark appearance. Tap the star to follow a talent on Home."
                             : "Follow talents to see them on Home, filter Search by them, and get new card alerts.")
                            .font(.subheadline)
                            .foregroundStyle(active.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.bottom, 4)
                    }

                    ForEach(AppThemeCategory.allCases) { category in
                        let themes = AppTheme.cases(in: category, matching: searchText)
                        if !themes.isEmpty {
                            Section {
                                ForEach(themes) { theme in
                                    themeButton(theme, active: active)
                                }
                            } header: {
                                Text(category.rawValue)
                                    .font(.caption.bold())
                                    .textCase(.uppercase)
                                    .foregroundStyle(active.secondaryText)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 8)
                                    .background(active.background)
                            }
                        }
                    }
                }
                .padding()
            }
            .background(active.background)
            .navigationTitle(mode == .theme ? "Themes" : "Follow Talents")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search talents")
            .toolbarBackground(active.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .tint(active.accent)
        }
        .background(active.background)
        .presentationBackground(active.background)
    }

    private func themeButton(_ theme: AppTheme, active: ThemeColors) -> some View {
        let colors = theme.colors(for: colorScheme)
        let isSelected = mode == .theme ? theme == themeStore.selected : themeStore.isFavorite(theme)
        return HStack(spacing: 2) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if mode == .theme { themeStore.selected = theme }
                    else { themeStore.toggleFavorite(theme) }
                }
            } label: {
                HStack(spacing: 13) {
                    TalentPortraitView(theme: theme)
                        .frame(width: 62, height: 62)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(theme.rawValue)
                            .font(.headline)
                            .foregroundStyle(active.primaryText)
                            .lineLimit(2)
                        HStack(spacing: 6) {
                            Text(theme.japaneseName)
                            if let status = theme.status {
                                Text(status.label.uppercased())
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(active.background, in: Capsule())
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(active.secondaryText)
                    }

                    Spacer(minLength: 4)

                    HStack(spacing: -5) {
                        swatch(colors.accent)
                        swatch(colors.secondaryAccent)
                    }
                    .accessibilityHidden(true)

                    Image(systemName: isSelected ? (mode == .theme ? "checkmark.circle.fill" : "star.fill") : (mode == .theme ? "circle" : "star"))
                        .foregroundStyle(isSelected ? active.accent : active.secondaryText.opacity(0.45))
                        .font(.title3)
                }
                .padding(11)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(theme.rawValue), \(theme.japaneseName)")
            .accessibilityValue(isSelected ? (mode == .theme ? "Selected" : "Following") : "")
            .accessibilityAddTraits(isSelected ? [.isSelected] : [])

            if mode == .theme {
                favoriteButton(theme, active: active)
                    .padding(.trailing, 6)
            }
        }
        .background(active.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(active.accent.opacity(0.55), lineWidth: 1.5)
            }
        }
    }

    private func favoriteButton(_ theme: AppTheme, active: ThemeColors) -> some View {
        let isFavorite = themeStore.isFavorite(theme)
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { themeStore.toggleFavorite(theme) }
        } label: {
            Image(systemName: isFavorite ? "star.fill" : "star")
                .font(.body.weight(.semibold))
                .foregroundStyle(isFavorite ? active.accent : active.secondaryText.opacity(0.6))
                .frame(width: 36, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isFavorite)
        .accessibilityLabel(isFavorite ? "Unfollow \(theme.rawValue)" : "Follow \(theme.rawValue)")
    }

    private func swatch(_ color: Color) -> some View {
        Circle().fill(color).frame(width: 25, height: 25)
            .overlay(Circle().stroke(themeStore.colors(for: colorScheme).primaryText.opacity(0.25), lineWidth: 1))
    }
}

struct SettingsView: View {
    @Environment(AppSettings.self) private var appSettings
    @Environment(ThemeStore.self) private var themeStore
    @Environment(CardCatalog.self) private var catalog
    @Environment(CardArtworkStore.self) private var artwork
    @Environment(TalentArtworkStore.self) private var talentArtwork
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var showingThemes = false
    @State private var showingFavorites = false
    @State private var showingClearArtworkConfirmation = false
    @State private var notificationsDenied = false

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

                    Button { showingFavorites = true } label: {
                        HStack {
                            Label("Followed Talents", systemImage: "star.fill")
                            Spacer()
                            Text((themeStore.followedOshi.count - 1).formatted())
                                .foregroundStyle(colors.secondaryText)
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundStyle(colors.secondaryText)
                        }
                    }
                    .foregroundStyle(colors.primaryText)

                    Picker(
                        "Appearance",
                        selection: Binding(
                            get: { appSettings.appearance },
                            set: { appearance in
                                withAnimation(.easeInOut(duration: 0.28)) {
                                    appSettings.appearance = appearance
                                }
                            }
                        )
                    ) {
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
                    Picker("Quick Add", selection: $appSettings.quickAddBehavior) {
                        ForEach(QuickAddBehavior.allCases) { behavior in
                            Text(behavior.displayName).tag(behavior)
                        }
                    }
                    .pickerStyle(.navigationLink)
                } header: {
                    Text("Collection")
                } footer: {
                    Text("Controls whether a long-press quick add saves immediately or asks for quantity and purchase price.")
                }

                Section {
                    Toggle(isOn: Binding(
                        get: { appSettings.newCardAlerts },
                        set: { enabled in setNewCardAlerts(enabled) }
                    )) {
                        Label("New Card Alerts", systemImage: "bell.badge.fill")
                    }
                    if notificationsDenied {
                        Text("Notifications are turned off for holoWish. Allow them in the Settings app to get alerts.")
                            .font(.caption)
                            .foregroundStyle(colors.secondaryText)
                    }
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Get notified when the catalog adds cards for \(themeStore.selected.rawValue) or talents you follow. holoWish checks for new cards about twice a day in the background.")
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
                    HStack {
                        Label("Offline Oshi outfits", systemImage: "person.crop.rectangle")
                        Spacer()
                        Text("\(talentArtwork.downloadedCount) / \(talentArtwork.totalCount)")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(colors.secondaryText)
                    }
                    ProgressView(value: talentArtwork.progress).tint(colors.accent)
                    if talentArtwork.downloadedCount < talentArtwork.totalCount {
                        Button(talentArtwork.isDownloading ? "Pause Outfit Download" : "Download Missing Outfits") {
                            if talentArtwork.isDownloading { talentArtwork.pauseDownloading() }
                            else { talentArtwork.beginDownloading() }
                        }
                        .disabled(talentArtwork.isClearing)
                    }
                    if talentArtwork.failedCount > 0 {
                        Text("\(talentArtwork.failedCount) outfits couldn’t download. Retry when connected.")
                            .font(.caption)
                            .foregroundStyle(colors.secondaryText)
                    }
                    if artwork.downloadedCount > 0 || talentArtwork.downloadedCount > 0 {
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
            .id(themeStore.selected)
            .scrollContentBackground(.hidden)
            .background(colors.background)
            .animation(.easeInOut(duration: 0.28), value: appSettings.appearance)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
            .tint(colors.accent)
            .sheet(isPresented: $showingThemes) { ThemePickerView() }
            .sheet(isPresented: $showingFavorites) { ThemePickerView(mode: .favorites) }
            .alert("Clear downloaded artwork?", isPresented: $showingClearArtworkConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Clear Artwork", role: .destructive) {
                    Task {
                        await artwork.clearDownloadedArtwork()
                        await talentArtwork.clearDownloadedArtwork()
                    }
                }
            } message: {
                Text("Card, product, and talent images can be downloaded again later.")
            }
        }
        .background(colors.background)
        .presentationBackground(colors.background)
        .preferredColorScheme(appSettings.appearance.colorScheme)
    }

    private func setNewCardAlerts(_ enabled: Bool) {
        guard enabled else {
            appSettings.newCardAlerts = false
            NewCardNotifier.shared.cancelBackgroundRefresh()
            return
        }
        Task {
            let granted = await NewCardNotifier.shared.requestAuthorization()
            appSettings.newCardAlerts = granted
            notificationsDenied = !granted
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
