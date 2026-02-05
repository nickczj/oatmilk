import SwiftUI

struct UtilityHubView: View {
    @Environment(UtilityStore.self) private var store
    @State private var searchText = ""

    private var filteredUtilities: [UtilityInfo] {
        if searchText.isEmpty {
            return store.utilities
        }
        return store.utilities.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText) ||
            $0.category.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var categories: [String] {
        Array(Set(filteredUtilities.map { $0.category })).sorted()
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(categories, id: \.self) { category in
                    Section(category) {
                        ForEach(filteredUtilities.filter({ $0.category == category })) { utility in
                            UtilityRow(utility: utility) {
                                store.toggleInstall(utility)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Utility Hub")
            .searchable(text: $searchText, prompt: "Search utilities")
            .overlay {
                if filteredUtilities.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
        }
    }
}

private struct UtilityRow: View {
    let utility: UtilityInfo
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: utility.iconName)
                .font(.title2)
                .foregroundStyle(utility.isInstalled ? .orange : .secondary)
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(utility.name)
                    .font(.headline)
                Text(utility.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Button {
                withAnimation(.snappy) {
                    onToggle()
                }
            } label: {
                Text(utility.isInstalled ? "Remove" : "Install")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        utility.isInstalled
                            ? Color(.systemGray5)
                            : Color.orange
                    )
                    .foregroundStyle(utility.isInstalled ? .primary : .white)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    UtilityHubView()
        .environment(UtilityStore())
}
