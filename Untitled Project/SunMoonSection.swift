//
//  SunMoonSection.swift
//  Atmos
//

import SwiftUI

private func arcFract(_ value: Double) -> Double {
    value - floor(value)
}

// MARK: - Секция Sun & Moon

struct SunMoonSection: View {
    let current: CurrentWeather
    let daily: DailyWeather
    let fetchedAt: Date
    let city: SavedCity
    let utcOffset: Int?

    private struct SunState {
        let riseText: String
        let setText: String
        let daylightText: String
        let progress: Double
        let isUp: Bool
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            content(for: timeline.date)
        }
    }

    @ViewBuilder
    private func content(for date: Date) -> some View {
        if let sun = sunState(at: date) {
            let moon: MoonPass = MoonCalc.pass(now: date, latitude: city.latitude, longitude: city.longitude)
            let light = MoonCalc.illumination(at: date)

            VStack(alignment: .leading, spacing: 14) {
                SectionLabel(title: "SUN & MOON", icon: "moon.stars.fill")

                SunMoonArcs(
                    sunProgress: sun.progress,
                    sunUp: sun.isUp,
                    moonProgress: moon.progress,
                    phase: light.phase,
                    southern: city.latitude < 0
                )

                sunRow(sun)
                moonRow(moon: moon, fraction: light.fraction, phase: light.phase)
            }
        }
    }

    // MARK: Солнце

    private func sunState(at date: Date) -> SunState? {
        let formatter: DateFormatter = SunSection.dateFormatter
        guard let base = formatter.date(from: current.time) else { return nil }
        let simulatedNow: Date = base.addingTimeInterval(date.timeIntervalSince(fetchedAt))
        let todayKey: String = String(formatter.string(from: simulatedNow).prefix(10))

        guard let dayIndex = daily.time.firstIndex(where: { $0 == todayKey }),
              daily.sunrise.indices.contains(dayIndex),
              daily.sunset.indices.contains(dayIndex),
              let riseMinutes = AtmosFormat.minutes(daily.sunrise[dayIndex]),
              let setMinutes = AtmosFormat.minutes(daily.sunset[dayIndex]),
              setMinutes > riseMinutes else { return nil }

        let parts = Calendar(identifier: .gregorian).dateComponents(in: TimeZone(secondsFromGMT: 0)!, from: simulatedNow)
        let nowMinutes: Int = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        let isUp: Bool = nowMinutes >= riseMinutes && nowMinutes < setMinutes

        var progress: Double = 0
        if isUp {
            progress = Double(nowMinutes - riseMinutes) / Double(setMinutes - riseMinutes)
        } else if nowMinutes >= setMinutes {
            progress = 1
        }

        let daylight: Int = setMinutes - riseMinutes
        return SunState(
            riseText: AtmosFormat.clock(daily.sunrise[dayIndex]),
            setText: AtmosFormat.clock(daily.sunset[dayIndex]),
            daylightText: "\(daylight / 60)h \(daylight % 60)m of daylight",
            progress: progress,
            isUp: isUp
        )
    }

    private func sunRow(_ sun: SunState) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Label("Sunrise", systemImage: "sunrise.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AtmosPalette.secondaryText)
                Text(sun.riseText)
                    .font(.system(size: 22, weight: .light, design: .rounded))
            }
            Spacer()
            Text(sun.daylightText)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AtmosPalette.tertiaryText)
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Label("Sunset", systemImage: "sunset.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AtmosPalette.secondaryText)
                Text(sun.setText)
                    .font(.system(size: 22, weight: .light, design: .rounded))
            }
        }
    }

    // MARK: Луна

    private var moonTint: Color { Color(red: 0.62, green: 0.77, blue: 1.0) }

    private func moonRow(moon: MoonPass, fraction: Double, phase: Double) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Label("Moonrise", systemImage: "moonrise.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(moonTint.opacity(0.8))
                Text(clockText(moon.riseTime))
                    .font(.system(size: 22, weight: .light, design: .rounded))
            }
            Spacer()
            VStack(spacing: 3) {
                Text(phaseName(phase))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AtmosPalette.secondaryText)
                Text("\(Int((fraction * 100).rounded()))% lit")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AtmosPalette.tertiaryText)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Label("Moonset", systemImage: "moonset.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(moonTint.opacity(0.8))
                Text(clockText(moon.setTime))
                    .font(.system(size: 22, weight: .light, design: .rounded))
            }
        }
    }

    private func phaseName(_ phase: Double) -> String {
        let names: [String] = ["New moon", "Waxing crescent", "First quarter", "Waxing gibbous", "Full moon", "Waning gibbous", "Last quarter", "Waning crescent"]
        return names[Int((phase * 8).rounded()) % 8]
    }

    // Смещение часового пояса города. Если API его не прислал, оцениваем сами
    private var cityOffset: Int {
        if let offset = utcOffset { return offset }
        guard let wall = SunSection.dateFormatter.date(from: current.time) else { return 0 }
        return Int((wall.timeIntervalSince(fetchedAt) / 900).rounded()) * 900
    }

    private func clockText(_ date: Date?) -> String {
        guard let date = date else { return "--:--" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: cityOffset)
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Две дуги со звёздами

struct SunMoonArcs: View {
    let sunProgress: Double
    let sunUp: Bool
    let moonProgress: Double?
    let phase: Double
    let southern: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let moonColor = Color(red: 0.62, green: 0.77, blue: 1.0)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: reduceMotion)) { timeline in
            Canvas { context, size in
                draw(context: &context, size: size, time: timeline.date.timeIntervalSinceReferenceDate)
            }
        }
        .frame(height: 170)
        .accessibilityHidden(true)
    }

    private func draw(context: inout GraphicsContext, size: CGSize, time: Double) {
        let centerX: CGFloat = size.width / 2
        let baseY: CGFloat = size.height - 14
        let outer: CGFloat = min(size.width / 2 - 14, 128)
        let inner: CGFloat = outer * 0.68
        let center = CGPoint(x: centerX, y: baseY)

        drawStars(&context, size: size, time: time)

        var horizon = Path()
        horizon.move(to: CGPoint(x: centerX - outer - 14, y: baseY))
        horizon.addLine(to: CGPoint(x: centerX + outer + 14, y: baseY))
        context.stroke(horizon, with: .color(Color.white.opacity(0.12)), lineWidth: 1)

        // Солнце, внешняя дуга
        drawTrack(&context, center: center, radius: outer, progress: sunProgress, color: AtmosPalette.amber)
        if sunUp {
            drawSun(&context, at: point(center: center, radius: outer, progress: sunProgress))
        }

        // Луна, внутренняя дуга
        drawTrack(&context, center: center, radius: inner, progress: moonProgress ?? 0, color: moonColor)
        if let moonProgress = moonProgress {
            drawMoon(&context, at: point(center: center, radius: inner, progress: moonProgress), time: time)
        }

        drawShootingStar(&context, size: size, time: time)
    }

    private func point(center: CGPoint, radius: CGFloat, progress: Double) -> CGPoint {
        let angle: Double = Double.pi * (1 - min(max(progress, 0), 1))
        return CGPoint(
            x: center.x + radius * CGFloat(cos(angle)),
            y: center.y - radius * CGFloat(sin(angle))
        )
    }

    private func arcPath(center: CGPoint, radius: CGFloat, progress: Double) -> Path {
        var path = Path()
        let steps: Int = max(2, Int(progress * 80))
        for i in 0...steps {
            let q: Double = progress * Double(i) / Double(steps)
            let p: CGPoint = point(center: center, radius: radius, progress: q)
            if i == 0 {
                path.move(to: p)
            } else {
                path.addLine(to: p)
            }
        }
        return path
    }

    private func drawTrack(_ context: inout GraphicsContext, center: CGPoint, radius: CGFloat, progress: Double, color: Color) {
        let full: Path = arcPath(center: center, radius: radius, progress: 1)
        context.stroke(full, with: .color(Color.white.opacity(0.16)), style: StrokeStyle(lineWidth: 1.5, dash: [3, 5]))
        if progress > 0.001 {
            let done: Path = arcPath(center: center, radius: radius, progress: progress)
            context.stroke(done, with: .color(color.opacity(0.22)), style: StrokeStyle(lineWidth: 7, lineCap: .round))
            context.stroke(done, with: .color(color.opacity(0.9)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        }
    }

    private func drawSun(_ context: inout GraphicsContext, at p: CGPoint) {
        let halo = CGRect(x: p.x - 16, y: p.y - 16, width: 32, height: 32)
        let core = CGRect(x: p.x - 7, y: p.y - 7, width: 14, height: 14)
        context.fill(Path(ellipseIn: halo), with: .color(AtmosPalette.amber.opacity(0.25)))
        context.fill(Path(ellipseIn: core), with: .color(AtmosPalette.amber))
    }

    private func drawMoon(_ context: inout GraphicsContext, at p: CGPoint, time: Double) {
        let breathe: CGFloat = reduceMotion ? 1 : 1 + 0.08 * CGFloat(sin(time * 1.6))
        let haloSize: CGFloat = 17 * breathe
        let halo = CGRect(x: p.x - haloSize, y: p.y - haloSize, width: haloSize * 2, height: haloSize * 2)
        context.fill(Path(ellipseIn: halo), with: .color(moonColor.opacity(0.22)))

        let r: CGFloat = 9.5
        let disc = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
        context.fill(Path(ellipseIn: disc), with: .color(Color(red: 0.16, green: 0.21, blue: 0.34)))
        context.fill(litPath(center: p, radius: r), with: .color(Color(red: 0.93, green: 0.96, blue: 1.0)))
    }

    // Освещённая часть луны. Для южного полушария рисунок зеркалится
    private func litPath(center: CGPoint, radius: CGFloat) -> Path {
        let c: Double = cos(2 * Double.pi * phase)
        let waxing: Bool = phase < 0.5
        let mirror: CGFloat = southern ? -1 : 1
        let r: Double = Double(radius)
        let steps: Int = 24

        var limb: [CGPoint] = []
        var terminator: [CGPoint] = []
        for i in 0...steps {
            let y: Double = -r + 2 * r * Double(i) / Double(steps)
            let half: Double = max(0, r * r - y * y).squareRoot()
            let limbX: Double = waxing ? half : -half
            let termX: Double = waxing ? c * half : -c * half
            limb.append(CGPoint(x: center.x + CGFloat(limbX) * mirror, y: center.y + CGFloat(y)))
            terminator.append(CGPoint(x: center.x + CGFloat(termX) * mirror, y: center.y + CGFloat(y)))
        }

        var path = Path()
        guard let first = limb.first else { return path }
        path.move(to: first)
        for p in limb.dropFirst() { path.addLine(to: p) }
        for p in terminator.reversed() { path.addLine(to: p) }
        path.closeSubpath()
        return path
    }

    private func drawStars(_ context: inout GraphicsContext, size: CGSize, time: Double) {
        for i in 0..<36 {
            let seed: Double = Double(i) + 1
            let x: CGFloat = CGFloat(arcFract(sin(seed * 12.9898) * 43758.5453)) * size.width
            let y: CGFloat = CGFloat(arcFract(sin(seed * 78.233) * 12345.6789)) * size.height * 0.85
            let speed: Double = 0.6 + arcFract(sin(seed * 39.346) * 9876.543) * 1.6
            let twinkle: Double = reduceMotion ? 0.6 : (sin(time * speed + seed * 2.3) + 1) / 2
            let r: CGFloat = 0.7 + CGFloat(arcFract(sin(seed * 5.123) * 3456.789)) * 1.1
            let rect = CGRect(x: x, y: y, width: r, height: r)
            context.fill(Path(ellipseIn: rect), with: .color(Color.white.opacity(0.12 + twinkle * 0.55)))
        }
    }

    // Падающая звезда раз в 14 секунд
    private func drawShootingStar(_ context: inout GraphicsContext, size: CGSize, time: Double) {
        if reduceMotion { return }
        let cycle: Double = time.truncatingRemainder(dividingBy: 14)
        if cycle >= 0.9 { return }
        let k: Double = cycle / 0.9
        let lane: CGFloat = CGFloat(Int(time / 14) % 3)
        let startX: CGFloat = size.width * 0.12 + lane * size.width * 0.18
        let head = CGPoint(x: startX + CGFloat(k) * 110, y: size.height * 0.08 + CGFloat(k) * 50)
        let tail = CGPoint(x: head.x - 26, y: head.y - 12)
        var streak = Path()
        streak.move(to: tail)
        streak.addLine(to: head)
        context.stroke(streak, with: .color(Color.white.opacity((1 - k) * 0.8)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
    }
}
