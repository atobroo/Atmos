//
//  LightningLayer.swift
//  Atmos
//

import SwiftUI

// Сила вспышки неба: 0 ... 1 (в макете было 0.6)
private let flashStrength: Double = 0.6

private func lightningFract(_ value: Double) -> Double {
    value - floor(value)
}

// MARK: - Расписание ударов

private enum LightningSchedule {
    /// Средний интервал, секунд. Реальный интервал от 5 до 15 секунд
    static let period: Double = 10

    static func start(of slot: Int) -> Double {
        let jitter: Double = lightningFract(sin(Double(slot) * 12.9898) * 43758.5453) * 5
        return Double(slot) * period + jitter
    }

    /// Удар, который идёт прямо сейчас (длится 1 секунду)
    static func active(at t: Double) -> (slot: Int, age: Double)? {
        let slot: Int = Int(floor(t / period))
        for candidate in [slot - 1, slot] {
            let age: Double = t - start(of: candidate)
            if age >= 0 && age < 1.0 {
                return (candidate, age)
            }
        }
        return nil
    }

    static func next(after t: Double) -> Double {
        let slot: Int = Int(floor(t / period))
        for candidate in (slot - 1)...(slot + 1) {
            let begin: Double = start(of: candidate)
            if begin > t { return begin }
        }
        return t + period
    }

    /// Тук-тук: первый тап в момент удара, второй вместе со второй вспышкой
    static func rumble() async {
        while !Task.isCancelled {
            let now: Double = Date().timeIntervalSinceReferenceDate
            let wait: Double = max(0, next(after: now) - now)
            try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
            if Task.isCancelled { break }
            await MainActor.run { Haptics.impact(.medium) }
            try? await Task.sleep(nanoseconds: 130_000_000)
            if Task.isCancelled { break }
            await MainActor.run { Haptics.impact(.light) }
        }
    }
}

// MARK: - Случайные числа с зерном (молния не «прыгает» между кадрами)

private struct BoltRandom {
    private var state: UInt64

    init(seed: Int) {
        state = UInt64(truncatingIfNeeded: seed) &* 6364136223846793005 &+ 1442695040888963407
    }

    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        let value: UInt64 = state >> 11
        return Double(value) / 9007199254740992.0
    }
}

// MARK: - Молния

struct LightningLayer: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            Canvas { context, size in
                let t: Double = timeline.date.timeIntervalSinceReferenceDate
                guard let strike = LightningSchedule.active(at: t) else { return }
                drawStrike(context: &context, size: size, slot: strike.slot, age: strike.age)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task { await LightningSchedule.rumble() }
    }

    // Двойная вспышка: удар, короткая тьма, второй удар, затухание
    private func flashLevel(_ age: Double) -> Double {
        if age < 0.07 { return 1 }
        if age < 0.13 { return 0.2 }
        if age < 0.25 { return 0.95 }
        if age < 1.0 { return 0.9 * exp(-(age - 0.25) * 5) }
        return 0
    }

    // Зубчатая линия: середину каждого отрезка сдвигаем вбок, и так несколько раз
    private func makeBolt(from start: CGPoint, to end: CGPoint, spread: CGFloat, passes: Int, rng: inout BoltRandom) -> [CGPoint] {
        var points: [CGPoint] = [start, end]
        var amount: CGFloat = spread
        for _ in 0..<passes {
            var refined: [CGPoint] = []
            for index in 0..<(points.count - 1) {
                let a: CGPoint = points[index]
                let b: CGPoint = points[index + 1]
                let dx: CGFloat = b.x - a.x
                let dy: CGFloat = b.y - a.y
                let length: CGFloat = max(hypot(dx, dy), 0.001)
                let offset: CGFloat = CGFloat(rng.next() - 0.5) * amount
                let midX: CGFloat = (a.x + b.x) / 2 - dy / length * offset
                let midY: CGFloat = (a.y + b.y) / 2 + dx / length * offset
                refined.append(a)
                refined.append(CGPoint(x: midX, y: midY))
            }
            refined.append(points[points.count - 1])
            points = refined
            amount *= 0.55
        }
        return points
    }

    private func polyline(_ points: [CGPoint]) -> Path {
        var path = Path()
        for (index, point) in points.enumerated() {
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        return path
    }

    private func drawStrike(context: inout GraphicsContext, size: CGSize, slot: Int, age: Double) {
        let intensity: Double = flashLevel(age)
        if intensity < 0.01 { return }

        let scale: CGFloat = size.width / 260
        let widthScale: CGFloat = max(1, scale * 0.8)
        var rng = BoltRandom(seed: slot)

        // Где ударит: каждый раз в новом месте
        let startX: CGFloat = size.width * CGFloat(0.22 + rng.next() * 0.56)
        let endX: CGFloat = startX + CGFloat(rng.next() - 0.5) * 70 * scale
        let endY: CGFloat = size.height * CGFloat(0.6 + rng.next() * 0.18)
        let main: [CGPoint] = makeBolt(
            from: CGPoint(x: startX, y: -4),
            to: CGPoint(x: endX, y: endY),
            spread: 70 * scale,
            passes: 6,
            rng: &rng
        )

        // Ответвления
        var branches: [[CGPoint]] = []
        for i in 8..<(main.count - 8) {
            if rng.next() < 0.05 {
                let side: Double = rng.next() < 0.5 ? -1 : 1
                let direction: Double = Double.pi / 2 + side * (0.4 + rng.next() * 0.6)
                let length: CGFloat = (50 + CGFloat(rng.next()) * 90) * scale
                let from: CGPoint = main[i]
                let to = CGPoint(x: from.x + CGFloat(cos(direction)) * length, y: from.y + CGFloat(sin(direction)) * length)
                branches.append(makeBolt(from: from, to: to, spread: length * 0.4, passes: 4, rng: &rng))
            }
        }

        context.blendMode = .plusLighter

        // Вспышка неба
        let skyTint: Color = Color(red: 0.67, green: 0.59, blue: 1.0)
        let wash = GraphicsContext.Shading.radialGradient(
            Gradient(colors: [skyTint.opacity(0.55 * intensity * flashStrength), skyTint.opacity(0)]),
            center: CGPoint(x: startX, y: size.height * 0.22),
            startRadius: 0,
            endRadius: size.height * 0.95
        )
        let screen = Path(CGRect(origin: .zero, size: size))
        context.fill(screen, with: wash)
        context.fill(screen, with: .color(Color(red: 0.78, green: 0.75, blue: 1.0).opacity(0.12 * intensity * flashStrength)))

        // Свечение вокруг разряда
        let glow: Color = Color(red: 0.55, green: 0.47, blue: 1.0)
        let halo: Color = Color(red: 0.75, green: 0.70, blue: 1.0)
        let mainPath: Path = polyline(main)
        let branchPaths: [Path] = branches.map { polyline($0) }

        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 12 * widthScale))
            let wide = StrokeStyle(lineWidth: 9 * widthScale, lineCap: .round, lineJoin: .round)
            layer.stroke(mainPath, with: .color(glow.opacity(0.35 * intensity)), style: wide)
            let wideBranch = StrokeStyle(lineWidth: 4.5 * widthScale, lineCap: .round, lineJoin: .round)
            for path in branchPaths {
                layer.stroke(path, with: .color(glow.opacity(0.35 * intensity)), style: wideBranch)
            }
        }

        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 4 * widthScale))
            let medium = StrokeStyle(lineWidth: 4 * widthScale, lineCap: .round, lineJoin: .round)
            layer.stroke(mainPath, with: .color(halo.opacity(0.55 * intensity)), style: medium)
            let mediumBranch = StrokeStyle(lineWidth: 2 * widthScale, lineCap: .round, lineJoin: .round)
            for path in branchPaths {
                layer.stroke(path, with: .color(halo.opacity(0.55 * intensity)), style: mediumBranch)
            }
        }

        // Белое ядро
        let core = StrokeStyle(lineWidth: 1.8 * widthScale + 0.3, lineCap: .round, lineJoin: .round)
        context.stroke(mainPath, with: .color(Color.white.opacity(0.95 * intensity)), style: core)
        let coreBranch = StrokeStyle(lineWidth: 0.9 * widthScale + 0.3, lineCap: .round, lineJoin: .round)
        for path in branchPaths {
            context.stroke(path, with: .color(Color.white.opacity(0.95 * intensity)), style: coreBranch)
        }
    }
}
