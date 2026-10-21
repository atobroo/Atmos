import SwiftUI

struct CitiesListView: View {
    @ObservedObject var model: AtmosViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AtmosBackground(glow: AtmosPalette.cyan, showStars: true)

                List {
                    ForEach(Array(model.cities.enumerated()), id: \.element.id) { index, city in
                        Button {
                            model.selectedIndex = index
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(city.name)
                                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white)
                                    Text(city.country)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(AtmosPalette.secondaryText)
                                }
                                
                                Spacer()
                                
                                if model.selectedIndex == index {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundStyle(AtmosPalette.cyan)
                                }
                            }
                            .padding(.vertical, 6)
                        }
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color.white.opacity(0.05))
                                .padding(.vertical, 4)
                        )
                        .listRowSeparator(.hidden)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            model.removeCity(at: index)
                        }
                    }
                    .onMove { source, destination in
                        model.moveCity(from: source, to: destination)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("My Cities")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AtmosPalette.cyan)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                        .foregroundStyle(AtmosPalette.cyan)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
