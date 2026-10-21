import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AtmosViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AtmosBackground(glow: AtmosPalette.cyan, showStars: true)

                VStack(alignment: .leading, spacing: 20) {
                    Text("UNITS")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .kerning(2)
                        .foregroundStyle(AtmosPalette.secondaryText)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                    ForEach(UnitSystem.allCases) { system in
                        Button {
                            // Добавляем вибрацию
                            Haptics.selection()
                            
                            // Меняем систему
                            model.unitSystem = system
                            
                        } label: {
                            HStack {
                                Text(system.name)
                                    .font(.system(size: 17, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white)
                                
                                Spacer()
                                
                                if model.unitSystem == system {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundStyle(AtmosPalette.cyan)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color.white.opacity(model.unitSystem == system ? 0.12 : 0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(Color.white.opacity(model.unitSystem == system ? 0.3 : 0.09), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain) // Важно, чтобы кнопка реагировала на тап
                        .padding(.horizontal, 20)
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AtmosPalette.cyan)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
