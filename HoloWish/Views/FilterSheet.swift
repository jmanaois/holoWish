import SwiftUI

struct FilterSheet: View {
    @Environment(CardCatalog.self) private var catalog
    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Binding var filters: CardFilters

    var body: some View {
        let colors = themeStore.colors(for: colorScheme)
        NavigationStack {
            Form {
                Picker("Rarity", selection: $filters.rarity) {
                    Text("All rarities").tag("")
                    ForEach(catalog.rarities, id: \.self) { Text($0).tag($0) }
                }
                Picker("Card type", selection: $filters.type) {
                    Text("All card types").tag("")
                    ForEach(catalog.types, id: \.self) { Text($0).tag($0) }
                }
                Picker("Color", selection: $filters.color) {
                    Text("All colors").tag("")
                    ForEach(catalog.colors, id: \.self) { Text($0).tag($0) }
                }
                Picker("Bloom level", selection: $filters.bloomLevel) {
                    Text("All levels").tag("")
                    ForEach(catalog.bloomLevels, id: \.self) { Text($0).tag($0) }
                }
                Picker("Product / set", selection: $filters.set) {
                    Text("All products").tag("")
                    ForEach(catalog.sets, id: \.self) { Text($0).tag($0) }
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
}
