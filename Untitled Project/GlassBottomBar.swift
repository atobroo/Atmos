//
//  GlassBottomBar.swift
//  Atmos
//

import SwiftUI

// Стекло: настоящий Liquid Glass на iOS 26+, на старых версиях матовый материал
private struct AtmosGlass<S: Shape>: ViewModifier {
    let shape: S
    var interactive: Bool = false

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(interactive ? Glass.regular.interactive() : Glass.regular, in: shape)
        } else {
            content
                .background(shape.fill(.ultraThinMaterial))
                .overlay(shape.stroke(Color.white.opacity(0.15), lineWidth: 1))
        }
    }
}

// Круглая стеклянная кнопка
private struct GlassCircleButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.impact(.light)
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .modifier(AtmosGlass(shape: Circle(), interactive: true))
    }
}

// Нижняя панель: [настройки]  ( ➤ • • • • )  [список]
struct GlassBottomBar: View {
    let count: Int
    let selected: Int
    var locationIndex: Int? = 0      // у какого города рисовать стрелку вместо точки
    let onSelect: (Int) -> Void
    let onLeft: () -> Void
    let onRight: () -> Void

    private let maxVisible: Int = 7

    // Если городов много, показываем окно из 7 точек вокруг выбранного
    private var visibleIndices: [Int] {
        guard count > maxVisible else { return Array(0..<max(count, 0)) }
        let start: Int = min(max(selected - 3, 0), count - maxVisible)
        return Array(start..<(start + maxVisible))
    }

    var body: some View {
        HStack(spacing: 14) {
            GlassCircleButton(systemName: "gearshape.fill", action: onLeft)

            HStack(spacing: 0) {
                ForEach(visibleIndices, id: \.self) { index in
                    dot(index)
                }
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .modifier(AtmosGlass(shape: Capsule()))

            GlassCircleButton(systemName: "list.bullet", action: onRight)
        }
        .padding(.horizontal, 20)
    }

    private func dot(_ index: Int) -> some View {
        let isActive: Bool = index == selected
        return Button {
            onSelect(index)
        } label: {
            ZStack {
                if index == locationIndex {
                    Image(systemName: "location.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.white.opacity(isActive ? 1 : 0.5))
                        .scaleEffect(isActive ? 1.15 : 1)
                } else {
                    Capsule()
                        .fill(Color.white.opacity(isActive ? 1 : 0.4))
                        .frame(width: isActive ? 16 : 8, height: 8)
                }
            }
            .frame(width: 22, height: 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: selected)
    }
}
