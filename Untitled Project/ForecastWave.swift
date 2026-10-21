import SwiftUI

// MARK: - 7-day forecast: orbit wave

struct ForecastWave: View {
    let daily: DailyWeather
    @State private var selected = 0

    private let hot = Color(red: 1.0, green: 0.54, blue: 0.36)
    private let cold = AtmosPalette.cyan

    private var count: Int {
        min(daily.time.count, daily.temperature_2m_max.count, daily.temperature_2m_min.count, daily.weather_code.count, 7)
    }

    var body: some View {
        if count > 0 {
            content
        }
    }

    private var content: some View {
        let highs: [Double] = Array(daily.temperature_2m_max.prefix(count))
        let lows: [Double] = Array(daily.temperature_2m_min.prefix(count))
        let sel: Int = min(selected, count - 1)

        return VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: "\(count)-DAY FORECAST", icon: "calendar")

            VStack(spacing: 8) {
                WaveCanvas(highs: highs, lows: lows, selected: sel, hot: hot, cold: cold)
                    .frame(height: 150)
                    .accessibilityHidden(true)

                dayRow(sel: sel)
                readout(sel: sel, high: highs[sel], low: lows[sel])
            }
            .padding(.vertical, 12)
        }
    }

    private func dayLabel(_ i: Int) -> String {
        if i == 0 { return "TODAY" }
        return AtmosFormat.weekday(daily.time[i]).uppercased()
    }

    private func symbol(_ i: Int) -> String {
        SkyCondition(code: daily.weather_code[i]).symbol(isDay: true)
    }

    private func dayRow(sel: Int) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<count, id: \.self) { i in
                dayButton(i: i, on: i == sel)
            }
        }
    }

    private func dayButton(i: Int, on: Bool) -> some View {
        Button {
            withAnimation(.snappy) { selected = i }
            Haptics.selection()
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle().fill(cold.opacity(on ? 0.12 : 0))
                    Circle().strokeBorder(cold.opacity(on ? 1 : 0.35), lineWidth: 1)
                    Image(systemName: symbol(i))
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: 15))
                }
                .frame(width: 30, height: 30)

                Text(dayLabel(i))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .kerning(1)
                    .foregroundStyle(on ? Color.white : AtmosPalette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(dayLabel(i)), \(AtmosFormat.degrees(daily.temperature_2m_max[i])) high, \(AtmosFormat.degrees(daily.temperature_2m_min[i])) low")
    }

    private func readout(sel: Int, high: Double, low: Double) -> some View {
        let title: String = sel == 0 ? "TODAY" : "\(dayLabel(sel)) \(daily.time[sel].suffix(2))"
        return HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(cold)
            Spacer()
            Text("↑ \(AtmosFormat.degrees(high))")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(hot)
            Text("↓ \(AtmosFormat.degrees(low))")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(cold)
            Image(systemName: symbol(sel))
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 16))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(cold.opacity(0.25), lineWidth: 1))
    }
}

// MARK: - Canvas with the two orbit lines (drawn once, no timer)

private struct WaveCanvas: View {
    let highs: [Double]
    let lows: [Double]
    let selected: Int
    let hot: Color
    let cold: Color

    private let stars: [(CGFloat, CGFloat, CGFloat, Double)] = [
        (0.04, 0.08, 1.2, 0.7), (0.18, 0.17, 0.8, 0.35), (0.33, 0.05, 1.2, 0.6),
        (0.50, 0.13, 0.8, 0.35), (0.68, 0.06, 1.2, 0.7), (0.85, 0.16, 0.8, 0.35),
        (0.96, 0.06, 1.2, 0.6), (0.12, 0.94, 0.8, 0.35), (0.41, 0.92, 1.2, 0.5),
        (0.74, 0.95, 0.8, 0.35), (0.94, 0.90, 1.2, 0.6)
    ]

    var body: some View {
        Canvas { context, size in
            drawWave(&context, size)
        }
    }

    private func addCurves(_ path: inout Path, _ pts: [CGPoint]) {
        if pts.count < 2 { return }
        for i in 0..<(pts.count - 1) {
            let a = pts[i]
            let b = pts[i + 1]
            let mx = (a.x + b.x) / 2
            path.addCurve(to: b, control1: CGPoint(x: mx, y: a.y), control2: CGPoint(x: mx, y: b.y))
        }
    }

    private func curve(_ pts: [CGPoint]) -> Path {
        var p = Path()
        guard let first = pts.first else { return p }
        p.move(to: first)
        addCurves(&p, pts)
        return p
    }

    private func drawWave(_ context: inout GraphicsContext, _ size: CGSize) {
        let n = highs.count
        if n == 0 { return }

        let cw: CGFloat = size.width / CGFloat(n)
        let top: CGFloat = 30
        let plotH: CGFloat = size.height - top - 30
        let vmax: Double = highs.max() ?? 1
        let vmin: Double = lows.min() ?? 0
        let span: Double = max(vmax - vmin, 1)

        var hiPts: [CGPoint] = []
        var loPts: [CGPoint] = []
        for i in 0..<n {
            let px: CGFloat = cw * (CGFloat(i) + 0.5)
            let hy: CGFloat = top + CGFloat((vmax - highs[i]) / span) * plotH
            let ly: CGFloat = top + CGFloat((vmax - lows[i]) / span) * plotH
            hiPts.append(CGPoint(x: px, y: hy))
            loPts.append(CGPoint(x: px, y: ly))
        }

        for s in stars {
            let r: CGFloat = s.2
            let rect = CGRect(x: s.0 * size.width - r, y: s.1 * size.height - r, width: r * 2, height: r * 2)
            context.fill(Path(ellipseIn: rect), with: .color(Color.white.opacity(s.3)))
        }

        var t: Double = (vmin / 5).rounded(.up) * 5
        while t <= vmax {
            let gy: CGFloat = top + CGFloat((vmax - t) / span) * plotH
            var g = Path()
            g.move(to: CGPoint(x: 0, y: gy))
            g.addLine(to: CGPoint(x: size.width, y: gy))
            context.stroke(g, with: .color(cold.opacity(0.16)), style: StrokeStyle(lineWidth: 1, dash: [2, 5]))
            t += 5
        }

        for i in 0..<n {
            var v = Path()
            v.move(to: CGPoint(x: hiPts[i].x, y: 12))
            v.addLine(to: CGPoint(x: hiPts[i].x, y: size.height - 8))
            if i == selected {
                context.stroke(v, with: .color(cold.opacity(0.55)), lineWidth: 1)
            } else {
                context.stroke(v, with: .color(cold.opacity(0.10)), style: StrokeStyle(lineWidth: 1, dash: [1, 4]))
            }
        }

        if n > 1 {
            var band = curve(hiPts)
            band.addLine(to: loPts[n - 1])
            addCurves(&band, Array(loPts.reversed()))
            band.closeSubpath()
            context.fill(band, with: .color(hot.opacity(0.12)))
        }

        let hiPath = curve(hiPts)
        let loPath = curve(loPts)
        let passes: [(CGFloat, Double)] = [(9, 0.07), (5, 0.14), (2.2, 1.0)]
        for pass in passes {
            let style = StrokeStyle(lineWidth: pass.0, lineCap: .round)
            context.stroke(hiPath, with: .color(hot.opacity(pass.1)), style: style)
            context.stroke(loPath, with: .color(cold.opacity(pass.1)), style: style)
        }

        let font = Font.system(size: 11, weight: .medium, design: .monospaced)
        for i in 0..<n {
            let on = i == selected
            let ringR: CGFloat = on ? 9 : 6

            let hp = hiPts[i]
            let hRing = CGRect(x: hp.x - ringR, y: hp.y - ringR, width: ringR * 2, height: ringR * 2)
            context.stroke(Path(ellipseIn: hRing), with: .color(hot.opacity(on ? 0.9 : 0.4)), lineWidth: 1)
            context.fill(Path(ellipseIn: CGRect(x: hp.x - 2.6, y: hp.y - 2.6, width: 5.2, height: 5.2)), with: .color(.white))
            let hText = Text("\(Int(highs[i].rounded()))").font(font).foregroundColor(Color.white.opacity(on ? 1 : 0.75))
            context.draw(hText, at: CGPoint(x: hp.x, y: hp.y - 15))

            let lp = loPts[i]
            let lRing = CGRect(x: lp.x - ringR, y: lp.y - ringR, width: ringR * 2, height: ringR * 2)
            context.stroke(Path(ellipseIn: lRing), with: .color(cold.opacity(on ? 0.9 : 0.4)), lineWidth: 1)
            context.fill(Path(ellipseIn: CGRect(x: lp.x - 2.6, y: lp.y - 2.6, width: 5.2, height: 5.2)), with: .color(.white))
            let lText = Text("\(Int(lows[i].rounded()))").font(font).foregroundColor(cold.opacity(on ? 1 : 0.7))
            context.draw(lText, at: CGPoint(x: lp.x, y: lp.y + 17))
        }
    }
}
