import Charts
import SwiftData
import SwiftUI

struct DashboardView: View {
    @Environment(CardCatalog.self) private var catalog
    @Environment(ThemeStore.self) private var themeStore
    @Environment(AppSettings.self) private var appSettings
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \CardList.createdAt) private var lists: [CardList]
    @Query(sort: \CollectionValueSnapshot.recordedAt) private var allValueSnapshots: [CollectionValueSnapshot]
    @State private var showingSettings = false
    @State private var showcaseTheme: AppTheme?

    private var wishlist: CardList? { lists.first { $0.builtInKind == .wishlist } }
    private var collection: CardList? { lists.first { $0.builtInKind == .collection } }
    private var collectionQuantity: Int { collection?.items.reduce(0) { $0 + $1.quantity } ?? 0 }
    private var selectedTalentCards: [Card] { catalog.cards.filter { $0.belongs(to: themeStore.selected) } }
    private var selectedTalentCollectedCount: Int {
        let cardIDs = Set(selectedTalentCards.map(\.id))
        let ownedIDs = Set(collection?.items.map(\.cardID) ?? [])
        return cardIDs.intersection(ownedIDs).count
    }
    private var collectionSnapshots: [CollectionValueSnapshot] {
        guard let collection else { return [] }
        return allValueSnapshots.filter { $0.listID == collection.id }
    }
    private var recentCards: [Card] {
        guard let collection else { return [] }
        return collection.items
            .sorted { $0.addedAt > $1.addedAt }
            .prefix(6)
            .compactMap { catalog.cardsByID[$0.cardID] }
    }
    private var mostValuableCards: [ValuableCard] {
        guard let collection else { return [] }
        return collection.items
            .compactMap { item -> ValuableCard? in
                guard item.purchasePrice != nil, let card = catalog.cardsByID[item.cardID] else { return nil }
                return ValuableCard(item: item, card: card)
            }
            .sorted { ($0.item.purchasePrice ?? 0) > ($1.item.purchasePrice ?? 0) }
            .prefix(4)
            .map { $0 }
    }

    var body: some View {
        let colors = themeStore.colors(for: colorScheme)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("holoWish")
                            .font(.largeTitle.bold())
                            .foregroundStyle(colors.primaryText)

                        Text("your hololive ocg wishlist and collection at a glance")
                            .font(.subheadline)
                            .foregroundStyle(colors.secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                    }

                    TalentSpotlightHero(
                        theme: themeStore.selected,
                        cardCount: selectedTalentCards.count,
                        collectedCount: selectedTalentCollectedCount,
                        artworkIndex: appSettings.homeArtworkIndex(for: themeStore.selected),
                        artworkCount: TalentArtworkCatalog.record(for: themeStore.selected)?.artworkURLs.count ?? 0,
                        showNextArtwork: { appSettings.cycleHomeArtwork(for: themeStore.selected) },
                        showShowcase: { showcaseTheme = themeStore.selected }
                    )

                    if let collection {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(colors.accent)
                                Text("Collection")
                                    .font(.title2.bold())
                                    .textCase(.uppercase)
                                    .tracking(0.6)
                            }
                                .foregroundStyle(colors.primaryText)
                                .padding(.horizontal, 13)
                                .padding(.vertical, 7)
                                .background {
                                    Capsule()
                                        .fill(.ultraThinMaterial)
                                        .overlay { Capsule().fill(colors.accent.opacity(0.09)) }
                                        .overlay { Capsule().stroke(colors.accent.opacity(0.22), lineWidth: 1) }
                                }

                            CollectionValueCard(list: collection, snapshots: collectionSnapshots)
                            MostValuableCardsView(entries: mostValuableCards)
                        }
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        if let wishlist {
                            NavigationLink { ListDetailView(list: wishlist) } label: {
                                DashboardButton(title: "Wishlist", subtitle: "\(wishlist.items.count) cards", icon: "heart.fill", color: colors.accent)
                            }
                        }
                        if let collection {
                            NavigationLink { ListDetailView(list: collection) } label: {
                                DashboardButton(title: "Collection", subtitle: "\(collectionQuantity) cards", icon: "square.stack.3d.up.fill", color: colors.secondaryAccent)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    if !recentCards.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Recently Added")
                                    .font(.title2.bold())
                                    .foregroundStyle(colors.primaryText)
                                Spacer()
                                if let collection {
                                    NavigationLink("View all") { ListDetailView(list: collection) }
                                        .font(.caption.bold())
                                }
                            }
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 12) {
                                    ForEach(recentCards) { card in
                                        NavigationLink { CardDetailView(card: card) } label: {
                                            RecentCardTile(card: card)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 2)
                            }
                        }
                    }

                }
                .padding()
            }
            .contentMargins(.bottom, 100, for: .scrollContent)
            .background(colors.background)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingSettings = true } label: { Image(systemName: "gearshape.fill") }
                        .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showingSettings) { SettingsView() }
            .sheet(item: $showcaseTheme) { TalentShowcaseView(theme: $0) }
            .tint(colors.accent)
        }
    }
}

private struct TalentSpotlightHero: View {
    let theme: AppTheme
    let cardCount: Int
    let collectedCount: Int
    let artworkIndex: Int
    let artworkCount: Int
    let showNextArtwork: () -> Void
    let showShowcase: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let colors = theme.colors(for: colorScheme)
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [colors.accent.opacity(0.92), colors.secondaryAccent.opacity(0.72), colors.surface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [.white.opacity(0.3), colors.secondaryAccent.opacity(0.12), .clear],
                center: UnitPoint(x: 0.78, y: 0.27),
                startRadius: 8,
                endRadius: 210
            )

            Circle()
                .fill(.white.opacity(0.07))
                .frame(width: 190, height: 190)
                .blur(radius: 1)
                .offset(x: 150, y: -105)

            TalentArtworkView(theme: theme, artworkIndex: artworkIndex)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .padding(.leading, 105)
                .scaleEffect(1.68, anchor: .topTrailing)
                .offset(x: 104, y: -30)
                .shadow(color: .black.opacity(0.24), radius: 16, x: -4, y: 10)

            LinearGradient(
                colors: [.clear, .black.opacity(0.1), .black.opacity(0.72)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 7) {
                Label("Oshi Hub", systemImage: "sparkles")
                    .font(.caption.bold())
                    .textCase(.uppercase)
                    .tracking(0.7)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(.ultraThinMaterial, in: Capsule())
                Spacer()
                Text(theme.rawValue)
                    .font(.title2.bold())
                    .lineLimit(2)
                Text(theme.japaneseName)
                    .font(.subheadline.weight(.semibold))
                    .opacity(0.85)
                Text(cardCount == 0 ? "No matched cards yet" : "\(collectedCount) of \(cardCount) cards collected")
                    .font(.caption)
                    .opacity(0.8)
            }
            .foregroundStyle(.white)
            .padding(18)

            if artworkCount > 1 {
                Button(action: showNextArtwork) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.headline)
                        .padding(11)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .tint(.white)
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .accessibilityLabel("Next home outfit, look \(artworkIndex + 1) of \(artworkCount)")
            }
        }
        .frame(height: 310)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.5), colors.accent.opacity(0.2), .white.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        }
        .shadow(color: colors.accent.opacity(0.24), radius: 18, y: 9)
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onTapGesture(perform: showShowcase)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "Open showcase", showShowcase)
    }
}

private struct ValuableCard: Identifiable {
    let item: CardListItem
    let card: Card
    var id: UUID { item.id }
}

private struct DashboardButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let colors = themeStore.colors(for: colorScheme)
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon).font(.title).foregroundStyle(colors.background)
                .frame(width: 52, height: 52).background(color, in: RoundedRectangle(cornerRadius: 15))
            Spacer(minLength: 8)
            Text(title).font(.title3.bold()).foregroundStyle(colors.primaryText)
            Text(subtitle).font(.caption).foregroundStyle(colors.secondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
        .padding(16)
        .background(colors.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct CollectionValueCard: View {
    let list: CardList
    let snapshots: [CollectionValueSnapshot]
    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedRange = CollectionChartRange.oneMonth

    private var chartPoints: [CollectionValuePoint] {
        let now = Date.now
        let start = selectedRange.startDate(relativeTo: now)
        let sorted = snapshots.sorted { $0.recordedAt < $1.recordedAt }
        let baseline = sorted.last { $0.recordedAt < start }
        var points: [CollectionValuePoint] = []

        if let baseline {
            points.append(CollectionValuePoint(date: start, value: baseline.chartValue))
        }
        points.append(contentsOf: sorted.filter { $0.recordedAt >= start && $0.recordedAt <= now }.map {
            CollectionValuePoint(date: $0.recordedAt, value: $0.chartValue)
        })

        let currentValue = NSDecimalNumber(decimal: list.totalPaidYen).doubleValue
        if points.isEmpty {
            points.append(CollectionValuePoint(date: start, value: currentValue))
        }
        if points.last?.date != now {
            points.append(CollectionValuePoint(date: now, value: currentValue))
        }
        return points
    }
    private var movement: Double {
        guard let first = chartPoints.first, let last = chartPoints.last else { return 0 }
        return last.value - first.value
    }

    var body: some View {
        let colors = themeStore.colors(for: colorScheme)
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 5) {
                Label("Tracked purchase value", systemImage: "yensign.circle.fill")
                    .font(.caption.bold())
                    .foregroundStyle(colors.secondaryText)
                Text(list.totalPaidYen.formatted(.currency(code: "JPY")))
                    .font(.title2.bold().monospacedDigit())
                    .foregroundStyle(colors.primaryText)
                if movement != 0 {
                    Label(
                        movement.formatted(.currency(code: "JPY")),
                        systemImage: movement > 0 ? "arrow.up.right" : "arrow.down.right"
                    )
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(movement > 0 ? colors.secondaryAccent : colors.secondaryText)
                } else {
                    Text("No change in the selected range")
                        .font(.caption)
                        .foregroundStyle(colors.secondaryText)
                }
                }
                Spacer()
                Text(selectedRange.rawValue)
                    .font(.caption.bold())
                    .foregroundStyle(colors.secondaryText)
            }

            Chart(chartPoints) { point in
                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [colors.accent.opacity(0.25), colors.accent.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(colors.accent)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            }
            .animation(.easeInOut(duration: 0.35), value: selectedRange)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 2)) {
                    AxisGridLine().foregroundStyle(colors.secondaryText.opacity(0.1))
                    AxisValueLabel(format: selectedRange == .oneDay ? .dateTime.hour() : .dateTime.month(.abbreviated).day())
                        .foregroundStyle(colors.secondaryText)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) {
                    AxisGridLine().foregroundStyle(colors.secondaryText.opacity(0.1))
                    AxisValueLabel().foregroundStyle(colors.secondaryText)
                }
            }
            .frame(height: 175)

            Picker("History range", selection: $selectedRange) {
                ForEach(CollectionChartRange.allCases) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Collection value history range")
            .sensoryFeedback(.selection, trigger: selectedRange)
        }
        .padding(18)
        .background(colors.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private enum CollectionChartRange: String, CaseIterable, Identifiable {
    case oneDay = "1D"
    case sevenDays = "7D"
    case oneMonth = "1M"
    case threeMonths = "3M"
    case sixMonths = "6M"
    case yearToDate = "YTD"

    var id: String { rawValue }

    func startDate(relativeTo date: Date) -> Date {
        let calendar = Calendar.current
        return switch self {
        case .oneDay: calendar.date(byAdding: .day, value: -1, to: date) ?? date
        case .sevenDays: calendar.date(byAdding: .day, value: -7, to: date) ?? date
        case .oneMonth: calendar.date(byAdding: .month, value: -1, to: date) ?? date
        case .threeMonths: calendar.date(byAdding: .month, value: -3, to: date) ?? date
        case .sixMonths: calendar.date(byAdding: .month, value: -6, to: date) ?? date
        case .yearToDate: calendar.dateInterval(of: .year, for: date)?.start ?? date
        }
    }
}

private struct CollectionValuePoint: Identifiable {
    let date: Date
    let value: Double
    var id: Date { date }
}

private struct MostValuableCardsView: View {
    let entries: [ValuableCard]
    @Environment(ThemeStore.self) private var themeStore
    @Environment(AppSettings.self) private var appSettings
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let colors = themeStore.colors(for: colorScheme)
        VStack(alignment: .leading, spacing: 10) {
            Text("Most Valuable")
                .font(.headline)
                .foregroundStyle(colors.primaryText)

            if entries.isEmpty {
                Label("Add purchase prices to see your top cards.", systemImage: "tag")
                    .font(.subheadline)
                    .foregroundStyle(colors.secondaryText)
                    .padding(.vertical, 8)
            } else {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    NavigationLink { CardDetailView(card: entry.card) } label: {
                        HStack(spacing: 12) {
                            Text((index + 1).formatted())
                                .font(.caption.bold().monospacedDigit())
                                .foregroundStyle(colors.secondaryText)
                                .frame(width: 18)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(entry.card.primaryName(for: appSettings.cardNamePreference))
                                    .font(.subheadline.bold())
                                    .foregroundStyle(colors.primaryText)
                                    .lineLimit(1)
                                Text(setName(for: entry.card))
                                    .font(.caption)
                                    .foregroundStyle(colors.secondaryText)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Text((entry.item.purchasePrice ?? 0).formatted(.currency(code: "JPY")))
                                .font(.subheadline.bold().monospacedDigit())
                                .foregroundStyle(colors.primaryText)
                        }
                    }
                    .buttonStyle(.plain)
                    if index < entries.count - 1 { Divider() }
                }
            }
        }
        .padding(16)
        .background(colors.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func setName(for card: Card) -> String {
        if appSettings.cardNamePreference == .englishFirst,
           let englishSet = card.allEnglishSets.first,
           !englishSet.isEmpty {
            return englishSet
        }
        return card.allSets.first ?? "Unknown set"
    }
}

private struct RecentCardTile: View {
    let card: Card
    @Environment(ThemeStore.self) private var themeStore
    @Environment(AppSettings.self) private var appSettings
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let colors = themeStore.colors(for: colorScheme)
        VStack(alignment: .leading, spacing: 6) {
            CachedCardImage(card: card, contentMode: .fill)
                .frame(width: 104, height: 146)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text(card.primaryName(for: appSettings.cardNamePreference))
                .font(.caption.bold())
                .foregroundStyle(colors.primaryText)
                .lineLimit(1)
            Text(card.number.uppercased())
                .font(.caption2.monospaced())
                .foregroundStyle(colors.secondaryText)
        }
        .frame(width: 104, alignment: .leading)
    }
}
