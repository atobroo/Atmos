//
//  FrostLayer.swift
//  Atmos
//

import SwiftUI

private struct FrostRandom {
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

/// Иней по краям экрана и мерцающие блёстки. level: 0 ... 1
struct FrostLayer: View {
    let level: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Canvas { context, size in
                drawFrost(context: &context, size: size)
            }
            if !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    Canvas { context, size in
                        let t: Double = timeline.date.timeIntervalSinceReferenceDate
                        drawSparkles(context: &context, size: size, time: t)
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: Иней

    private func crystal(_ context: inout GraphicsContext, x: CGFloat, y: CGFloat, angle: Double, length: CGFloat, alpha: Double, lineWidth: CGFloat) {
        var path = Path()
        path.move(to: CGPoint(x: x, y: y))
        path.addLine(to: CGPoint(x: x + CGFloat(cos(angle)) * length, y: y + CGFloat(sin(angle)) * length))
        for fraction in [0.4, 0.7] {
            let bx: CGFloat = x + CGFloat(cos(angle)) * length * CGFloat(fraction)
            let by: CGFloat = y + CGFloat(sin(angle)) * length * CGFloat(fraction)
            let branchLength: CGFloat = length * CGFloat(fraction == 0.4 ? 0.45 : 0.3)
            for side in [-1.0, 1.0] {
                let branchAngle: Double = angle + side * 0.95
                path.move(to: CGPoint(x: bx, y: by))
                path.addLine(to: CGPoint(x: bx + CGFloat(cos(branchAngle)) * branchLength, y: by + CGFloat(sin(branchAngle)) * branchLength))
            }
        }
        context.stroke(path, with: .color(Color.white.opacity(alpha)), lineWidth: lineWidth)
    }

    private func drawFrost(context: inout GraphicsContext, size: CGSize) {
        let w: CGFloat = size.width
        let h: CGFloat = size.height
        let m: CGFloat = min(w, h)
        let lvl: CGFloat = CGFloat(level)
        let scale: CGFloat = w / 220
        var rng = FrostRandom(seed: 4242)

        // Матовая изморозь вдоль краёв
        let fog: CGFloat = m * (0.14 + 0.34 * lvl)
        let tint: Color = Color(red: 0.94, green: 0.98, blue: 1.0)
        let strong: Color = tint.opacity(0.12 + 0.42 * level)
        let none: Color = tint.opacity(0)
        let gradient = Gradient(colors: [strong, none])

        context.fill(
            Path(CGRect(x: 0, y: 0, width: w, height: fog)),
            with: .linearGradient(gradient, startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: fog))
        )
        context.fill(
            Path(CGRect(x: 0, y: h - fog, width: w, height: fog)),
            with: .linearGradient(gradient, startPoint: CGPoint(x: 0, y: h), endPoint: CGPoint(x: 0, y: h - fog))
        )
        context.fill(
            Path(CGRect(x: 0, y: 0, width: fog, height: h)),
            with: .linearGradient(gradient, startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: fog, y: 0))
        )
        context.fill(
            Path(CGRect(x: w - fog, y: 0, width: fog, height: h)),
            with: .linearGradient(gradient, startPoint: CGPoint(x: w, y: 0), endPoint: CGPoint(x: w - fog, y: 0))
        )

        // Кристаллы вдоль краёв
        let maxDepth: CGFloat = m * (0.16 + 0.34 * lvl)
        let edgeCount: Int = Int(50 + 300 * level)
        for _ in 0..<edgeCount {
            let side: Int = Int(rng.next() * 4)
            let depth: CGFloat = CGFloat(pow(rng.next(), 2.2)) * maxDepth
            var x: CGFloat = 0
            var y: CGFloat = 0
            var angle: Double = 0
            switch side {
            case 0: x = CGFloat(rng.next()) * w; y = depth; angle = Double.pi / 2
            case 1: x = CGFloat(rng.next()) * w; y = h - depth; angle = -Double.pi / 2
            case 2: x = depth; y = CGFloat(rng.next()) * h; angle = 0
            default: x = w - depth; y = CGFloat(rng.next()) * h; angle = Double.pi
            }
            angle += (rng.next() - 0.5) * 1.4
            let length: CGFloat = (7 + CGFloat(rng.next()) * (14 + 14 * lvl)) * scale
            crystal(&context, x: x, y: y, angle: angle, length: length, alpha: 0.3 + rng.next() * 0.5, lineWidth: 0.5 + CGFloat(rng.next()) * 0.6)
        }

        // Углы гуще
        let cornerCount: Int = Int(30 + 120 * level)
        for _ in 0..<cornerCount {
            let left: Bool = rng.next() < 0.5
            let top: Bool = rng.next() < 0.5
            let dx: CGFloat = CGFloat(pow(rng.next(), 2)) * maxDepth * 1.5
            let dy: CGFloat = CGFloat(pow(rng.next(), 2)) * maxDepth * 1.5
            let x: CGFloat = left ? dx : w - dx
            let y: CGFloat = top ? dy : h - dy
            let angle: Double = Double(atan2(h / 2 - y, w / 2 - x)) + (rng.next() - 0.5) * 1.2
            let length: CGFloat = (8 + CGFloat(rng.next()) * 18) * scale
            crystal(&context, x: x, y: y, angle: angle, length: length, alpha: 0.35 + rng.next() * 0.5, lineWidth: 0.6 + CGFloat(rng.next()) * 0.6)
        }

        // Мелкая ледяная крошка
        let dotCount: Int = Int(60 + 300 * level)
        for _ in 0..<dotCount {
            let side: Int = Int(rng.next() * 4)
            let depth: CGFloat = CGFloat(pow(rng.next(), 2)) * maxDepth * 1.2
            var x: CGFloat = 0
            var y: CGFloat = 0
            switch side {
            case 0: x = CGFloat(rng.next()) * w; y = depth
            case 1: x = CGFloat(rng.next()) * w; y = h - depth
            case 2: x = depth; y = CGFloat(rng.next()) * h
            default: x = w - depth; y = CGFloat(rng.next()) * h
            }
            let radius: CGFloat = (0.4 + CGFloat(rng.next()) * 0.9) * max(1, scale * 0.8)
            context.fill(
                Path(ellipseIn: CGRect(x: x, y: y, width: radius, height: radius)),
                with: .color(Color.white.opacity(0.5))
            )
        }
    }

    // MARK: Блёстки

    private func drawSparkles(context: inout GraphicsContext, size: CGSize, time: Double) {
        var rng = FrostRandom(seed: 999)
        let count: Int = Int(8 + 16 * level)
        let scale: CGFloat = size.width / 220
        for _ in 0..<count {
            let x: CGFloat = CGFloat(rng.next()) * size.width
            let y: CGFloat = CGFloat(rng.next()) * size.height
            let phase: Double = rng.next() * 6.28
            let speed: Double = 0.8 + rng.next() * 1.2
            let sparkSize: CGFloat = (2 + CGFloat(rng.next()) * 3.5) * scale

            let wave: Double = sin(time * speed + phase)
            let v: Double = wave > 0 ? pow(wave, 3) : 0
            if v < 0.02 { continue }

            let half: CGFloat = sparkSize * CGFloat(0.6 + 0.6 * v)
            var path = Path()
            path.move(to: CGPoint(x: x - half, y: y))
            path.addLine(to: CGPoint(x: x + half, y: y))
            path.move(to: CGPoint(x: x, y: y - half))
            path.addLine(to: CGPoint(x: x, y: y + half))
            context.stroke(path, with: .color(Color.white.opacity(0.9 * v)), lineWidth: 1)
        }
    }
}
