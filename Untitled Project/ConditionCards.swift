//
//  ConditionCards.swift
//  Atmos
//

import SwiftUI

// MARK: - Секция Conditions: ветер, влажность + три малые карточки

struct ConditionsSection: View {
    let current: CurrentWeather
    let hourly: HourlyWeather
    let unitSymbol: String

    private var isImperial: Bool { unitSymbol == "mph" }

    // Изменение давления за 3 часа (гПа). nil, если данных нет
    private var pressureTrend: Double? {
        let values: [Double?] = hourly.pressure_msl ?? []
        guard !values.isEmpty else { return nil }
        let currentHour: String = String(current.time.prefix(13))
        guard let index = hourly.time.firstIndex(where: { String($0.prefix(13)) >= currentHour }) else { return nil }
        let from: Int = index >= 3 ? index - 3 : index
        let to: Int = index >= 3 ? index : index + 3
        guard values.indices.contains(from), values.indices.contains(to) else { return nil }
        guard let start = values[from], let end = values[to] else { return nil }
        return end - start
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(title: "CONDITIONS", icon: "gauge.with.dots.needle.33percent")

            HStack(alignment: .top, spacing: 14) {
                WindPanel(speed: current.wind_speed_10m, direction: current.wind_direction_10m, unitSymbol: unitSymbol)
                    .frame(maxHeight: .infinity)
                HumidityPanel(humidity: current.relative_humidity_2m)
                    .frame(maxHeight: .infinity)
            }
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                FeelsLikeCard(actual: current.temperature_2m, feels: current.apparent_temperature, isImperial: isImperial, delay: 0.0)
                VisibilityCard(meters: current.visibility, isImperial: isImperial, delay: 0.12)
                PressureCard(pressure: current.pressure_msl, trend: pressureTrend, delay: 0.24)
            }
        }
    }
}

// MARK: - Общие кусочки

private func cardFract(_ value: Double) -> Double {
    value - floor(value)
}

private struct ConditionCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, minHeight: 150, maxHeight: 150, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Color.white.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Color.white.opacity(0.09), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

private struct ConditionEntrance: ViewModifier {
    let delay: Double
    @State private var appeared: Bool = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 14)
            .animation(.spring(response: 0.7, dampingFraction: 0.8).delay(delay), value: appeared)
            .onAppear { appeared = true }
    }
}

private struct CardLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .kerning(1.4)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .foregroundStyle(AtmosPalette.secondaryText)
    }
}

private struct CardValue: View {
    let value: String
    let unit: String
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(value)
                .font(.system(size: 30, weight: .light, design: .rounded))
            if !unit.isEmpty {
                Text(unit)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AtmosPalette.secondaryText)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
}

private struct CardCaption: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .foregroundStyle(AtmosPalette.secondaryText)
    }
}

// MARK: - Feels like

struct FeelsLikeCard: View {
    let actual: Double
    let feels: Double
    let isImperial: Bool
    let delay: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: Bool = false
    @State private var pulse: Bool = false

    private var delta: Double { feels - actual }
    private var coldLevel: Double { delta <= -2 ? min(1, -delta / 8) : 0 }
    private var warmLevel: Double { delta >= 2 ? min(1, delta / 8) : 0 }
    private var dotColor: Color { delta >= 1 ? AtmosPalette.amber : AtmosPalette.cyan }

    private var caption: String {
        let rounded: Int = Int(abs(delta).rounded())
        if rounded == 0 { return "Similar" }
        return delta < 0 ? "\(rounded)° colder" : "\(rounded)° warmer"
    }

    // Шкала считается в градусах Цельсия, от -30 до 40
    private func position(of value: Double) -> CGFloat {
        let celsius: Double = isImperial ? (value - 32) / 1.8 : value
        let fraction: Double = (celsius + 30) / 70
        return CGFloat(min(max(fraction, 0.04), 0.96))
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            coldTint
            frost
            warmGlow
            content
        }
        .modifier(ConditionCardStyle())
        .modifier(ConditionEntrance(delay: delay))
        .onAppear {
            if reduceMotion {
                shown = true
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.45) { shown = true }
                withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { pulse = true }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Feels like \(Int(feels.rounded())) degrees, \(caption)")
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            CardLabel(text: "FEELS LIKE")
            Spacer(minLength: 8)
            CardValue(value: "\(Int(feels.rounded()))°", unit: "")
            CardCaption(text: caption).padding(.top, 6)
            Spacer(minLength: 10)
            track
        }
        .padding(12)
    }

    private var track: some View {
        GeometryReader { geo in
            let width: CGFloat = geo.size.width
            let midY: CGFloat = geo.size.height / 2
            let actualX: CGFloat = width * position(of: actual)
            let feelsX: CGFloat = width * position(of: feels)
            ZStack {
                Capsule()
                    .fill(Color.white.opacity(0.18))
                    .frame(height: 4)
                Circle()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 9, height: 9)
                    .position(x: actualX, y: midY)
                Circle()
                    .fill(dotColor)
                    .frame(width: 14, height: 14)
                    .shadow(color: dotColor.opacity(0.7), radius: 6)
                    .position(x: shown ? feelsX : actualX, y: midY)
            }
            .frame(width: width, height: geo.size.height)
        }
        .frame(height: 16)
        .animation(.spring(response: 1.0, dampingFraction: 0.6), value: shown)
        .animation(.spring(response: 1.0, dampingFraction: 0.6), value: feels)
    }

    private var coldTint: some View {
        Rectangle()
            .fill(Color(red: 0.43, green: 0.75, blue: 1.0).opacity(0.18))
            .opacity(coldLevel)
            .animation(.easeInOut(duration: 0.8), value: coldLevel)
    }

    // Ледяные искры, мерцают, когда ощущается холоднее
    private var frost: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: coldLevel == 0 || reduceMotion)) { timeline in
            Canvas { context, size in
                let t: Double = timeline.date.timeIntervalSinceReferenceDate
                for i in 0..<12 {
                    let seed: Double = Double(i) + 1
                    let x: CGFloat = CGFloat(cardFract(sin(seed * 12.9898) * 43758.5453)) * size.width
                    let y: CGFloat = CGFloat(cardFract(sin(seed * 78.233) * 12345.6789)) * size.height
                    let speed: Double = 0.5 + cardFract(sin(seed * 39.346) * 9876.543)
                    let twinkle: Double = (sin(t * speed * 2 + seed * 3) + 1) / 2
                    let r: CGFloat = CGFloat(0.8 + twinkle * 1.6)
                    let rect = CGRect(x: x - r / 2, y: y - r / 2, width: r, height: r)
                    context.fill(Path(ellipseIn: rect), with: .color(Color.white.opacity(0.15 + twinkle * 0.7)))
                }
            }
        }
        .opacity(coldLevel)
        .animation(.easeInOut(duration: 0.8), value: coldLevel)
        .allowsHitTesting(false)
    }

    // Тёплое пульсирующее свечение, когда ощущается теплее
    private var warmGlow: some View {
        RadialGradient(
            colors: [AtmosPalette.amber.opacity(0.55), AtmosPalette.amber.opacity(0)],
            center: .bottomTrailing,
            startRadius: 0,
            endRadius: 130
        )
        .scaleEffect(pulse ? 1.12 : 0.92, anchor: .bottomTrailing)
        .opacity(warmLevel)
        .animation(.easeInOut(duration: 0.8), value: warmLevel)
        .allowsHitTesting(false)
    }
}

// MARK: - Visibility

struct VisibilityCard: View {
    let meters: Double?
    let isImperial: Bool
    let delay: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var litShown: Int = 0

    private var km: Double? {
        guard let meters = meters else { return nil }
        return meters / 1000
    }

    private var lit: Int {
        guard let km = km else { return 0 }
        if km >= 10 { return 6 }
        if km >= 7 { return 5 }
        if km >= 4 { return 4 }
        if km >= 2 { return 3 }
        if km >= 1 { return 2 }
        return 1
    }

    private var fogLevel: Double {
        guard let km = km, km < 10 else { return 0 }
        return min(0.9, (1 - km / 10) * 1.05)
    }

    private var valueText: String {
        guard let km = km else { return "–" }
        let converted: Double = isImperial ? km * 0.621371 : km
        if converted >= 10 { return "\(Int(converted.rounded()))" }
        return String(format: "%.1f", converted)
    }

    private var unitText: String { isImperial ? "mi" : "km" }

    private var caption: String {
        guard let km = km else { return "No data" }
        if km >= 10 { return "Clear" }
        if km >= 5 { return "Good" }
        if km >= 2 { return "Moderate" }
        if km >= 1 { return "Poor" }
        return "Very poor"
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            fog
            content
        }
        .modifier(ConditionCardStyle())
        .modifier(ConditionEntrance(delay: delay))
        .onAppear { lightUp() }
        .onChange(of: lit) { _, newValue in
            withAnimation(.easeOut(duration: 0.25)) { litShown = newValue }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Visibility \(valueText) \(unitText), \(caption)")
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            CardLabel(text: "VISIBILITY")
            Spacer(minLength: 8)
            CardValue(value: valueText, unit: unitText)
            CardCaption(text: caption).padding(.top, 6)
            Spacer(minLength: 10)
            dashes
        }
        .padding(12)
    }

    private var dashes: some View {
        HStack(spacing: 4) {
            ForEach(0..<6, id: \.self) { index in
                Capsule()
                    .fill(index < litShown ? Color.white.opacity(0.9) : Color.white.opacity(0.18))
                    .frame(height: 5)
            }
        }
        .frame(height: 16)
    }

    // Чёрточки загораются по очереди слева направо
    private func lightUp() {
        if reduceMotion {
            litShown = lit
            return
        }
        litShown = 0
        guard lit > 0 else { return }
        for step in 1...lit {
            let when: Double = delay + 0.3 + Double(step) * 0.09
            DispatchQueue.main.asyncAfter(deadline: .now() + when) {
                withAnimation(.easeOut(duration: 0.25)) { litShown = step }
            }
        }
    }

    // Туман: плывёт по карточке, когда видимость меньше 10 км
    private var fog: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: fogLevel == 0 || reduceMotion)) { timeline in
            Canvas { context, size in
                let t: Double = timeline.date.timeIntervalSinceReferenceDate
                context.addFilter(.blur(radius: 16))
                for i in 0..<4 {
                    let seed: Double = Double(i) + 1
                    let drift: CGFloat = CGFloat(sin(t * 0.25 + seed * 1.7)) * 14
                    let cx: CGFloat = size.width * (0.2 + 0.2 * CGFloat(i)) + drift
                    let cy: CGFloat = size.height * (0.25 + 0.18 * CGFloat(i % 3))
                    let rect = CGRect(x: cx - 40, y: cy - 22, width: 80, height: 44)
                    context.fill(Path(ellipseIn: rect), with: .color(Color(red: 0.88, green: 0.91, blue: 1.0).opacity(0.5)))
                }
            }
        }
        .opacity(fogLevel)
        .animation(.easeInOut(duration: 0.8), value: fogLevel)
        .allowsHitTesting(false)
    }
}

// MARK: - Pressure

struct PressureCard: View {
    let pressure: Double?
    let trend: Double?   // изменение за 3 часа, гПа
    let delay: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: Bool = false
    @State private var pulse: Bool = false

    // 1 растёт, -1 падает, 0 стабильно
    private var direction: Int {
        guard let trend = trend else { return 0 }
        if trend > 1 { return 1 }
        if trend < -1 { return -1 }
        return 0
    }

    private var valueText: String {
        guard let pressure = pressure else { return "–" }
        return "\(Int(pressure.rounded()))"
    }

    private var caption: String {
        guard let pressure = pressure else { return "No data" }
        if pressure < 1000 { return "Low" }
        if pressure > 1025 { return "High" }
        return "Normal"
    }

    // Шкала 980...1045 гПа
    private var fraction: CGFloat {
        guard let pressure = pressure else { return 0.5 }
        return CGFloat(min(max((pressure - 980) / 65, 0.04), 0.96))
    }

    private var arrowName: String {
        if direction > 0 { return "arrow.up" }
        if direction < 0 { return "arrow.down" }
        return "arrow.right"
    }

    private var trendWord: String {
        if direction > 0 { return "rising" }
        if direction < 0 { return "falling" }
        return "steady"
    }

    var body: some View {
        content
            .modifier(ConditionCardStyle())
            .modifier(ConditionEntrance(delay: delay))
            .onAppear {
                if reduceMotion {
                    shown = true
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.45) { shown = true }
                    pulse = true
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Pressure \(valueText) hectopascals, \(caption), \(trendWord)")
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            CardLabel(text: "PRESSURE")
            Spacer(minLength: 8)
            CardValue(value: valueText, unit: "hPa")
            captionRow.padding(.top, 6)
            Spacer(minLength: 10)
            track
        }
        .padding(12)
    }

    private var captionRow: some View {
        HStack(spacing: 4) {
            CardCaption(text: caption)
            if trend != nil {
                arrow
            }
        }
    }

    private var arrow: some View {
        let moving: Bool = direction != 0 && pulse
        let shift: CGFloat = moving ? CGFloat(-2 * direction) : 0
        return Image(systemName: arrowName)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(direction == 0 ? AtmosPalette.secondaryText : AtmosPalette.cyan)
            .offset(y: shift)
            .opacity(moving ? 0.45 : 1)
            .animation(reduceMotion ? nil : .easeInOut(duration: 1.3).repeatForever(autoreverses: true), value: pulse)
    }

    private var track: some View {
        GeometryReader { geo in
            let width: CGFloat = geo.size.width
            let midY: CGFloat = geo.size.height / 2
            let dotX: CGFloat = width * (shown ? fraction : 0.5)
            let tickX: CGFloat = width * 0.508
            ZStack {
                Capsule()
                    .fill(Color.white.opacity(0.18))
                    .frame(height: 4)
                Rectangle()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: 1, height: 10)
                    .position(x: tickX, y: midY)
                Circle()
                    .fill(AtmosPalette.cyan)
                    .frame(width: 14, height: 14)
                    .shadow(color: AtmosPalette.cyan.opacity(0.7), radius: 6)
                    .position(x: dotX, y: midY)
            }
            .frame(width: width, height: geo.size.height)
        }
        .frame(height: 16)
        .animation(.spring(response: 1.0, dampingFraction: 0.6), value: shown)
        .animation(.spring(response: 1.0, dampingFraction: 0.6), value: fraction)
    }
}
