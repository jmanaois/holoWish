import SwiftUI

struct FilterSheet: View {
    @Environment(CardCatalog.self) private var catalog
    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Binding var filters: CardFilters
    private let availableCards: [Card]?
    private let showsSetPicker: Bool

    init(filters: Binding<CardFilters>, availableCards: [Card]? = nil, showsSetPicker: Bool = true) {
        _filters = filters
        self.availableCards = availableCards
        self.showsSetPicker = showsSetPicker
    }

    private var rarities: [String] { values(\.rarity, fallback: catalog.rarities) }
    private var types: [String] { values(\.type, fallback: catalog.types) }
    private var bloomLevels: [String] { values(\.bloomLevel, fallback: catalog.bloomLevels) }
    private var availableColors: [String] {
        guard let availableCards else { return catalog.colors }
        return Array(Set(availableCards.flatMap(\.allColors))).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    var body: some View {
        let colors = themeStore.colors(for: colorScheme)
        NavigationStack {
            Form {
                Picker("Rarity", selection: $filters.rarity) {
                    Text("All rarities").tag("")
                    ForEach(rarities, id: \.self) { Text($0).tag($0) }
                }
                Picker("Card type", selection: $filters.type) {
                    Text("All card types").tag("")
                    ForEach(types, id: \.self) { Text($0).tag($0) }
                }
                Picker("Color", selection: $filters.color) {
                    Text("All colors").tag("")
                    ForEach(availableColors, id: \.self) { Text($0).tag($0) }
                }
                Picker("Bloom level", selection: $filters.bloomLevel) {
                    Text("All levels").tag("")
                    ForEach(bloomLevels, id: \.self) { Text($0).tag($0) }
                }
                if showsSetPicker {
                    Picker("Product / set", selection: $filters.set) {
                        Text("All products").tag("")
                        ForEach(catalog.sets, id: \.self) { Text($0).tag($0) }
                    }
                }
                Toggle("Parallel cards only", isOn: $filters.parallelsOnly)
            }
            .scrollContentBackground(.hidden)
            .background(colors.background)
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Reset") { filters.clear() } }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.fontWeight(.semibold) }
            }
            .tint(colors.accent)
        }
        .presentationDetents([.medium, .large])
    }

    private func values(_ keyPath: KeyPath<Card, String>, fallback: [String]) -> [String] {
        guard let availableCards else { return fallback }
        return Array(Set(availableCards.map { $0[keyPath: keyPath] }.filter { !$0.isEmpty }))
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }
}
