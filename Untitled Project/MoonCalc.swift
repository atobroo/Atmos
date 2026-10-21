//
//  MoonCalc.swift
//  Atmos
//

import Foundation

struct MoonPass {
    let riseTime: Date?
    let setTime: Date?
    let isUp: Bool
    /// 0...1 прогресс луны по её дуге, только если она сейчас над горизонтом
    let progress: Double?
}

/// Фаза и положение луны считаются на телефоне, без интернета
enum MoonCalc {
    private static let rad: Double = Double.pi / 180
    private static let tilt: Double = 23.4397 * Double.pi / 180

    private static func days(_ date: Date) -> Double {
        return date.timeIntervalSince1970 / 86400.0 - 0.5 + 2440588.0 - 2451545.0
    }

    private static func rightAscension(_ l: Double, _ b: Double) -> Double {
        return atan2(sin(l) * cos(tilt) - tan(b) * sin(tilt), cos(l))
    }

    private static func declination(_ l: Double, _ b: Double) -> Double {
        return asin(sin(b) * cos(tilt) + cos(b) * sin(tilt) * sin(l))
    }

    private static func refraction(_ h: Double) -> Double {
        let clamped: Double = max(h, 0)
        return 0.0002967 / tan(clamped + 0.00312536 / (clamped + 0.08901179))
    }

    private static func sunCoords(_ d: Double) -> (dec: Double, ra: Double) {
        let m: Double = rad * (357.5291 + 0.98560028 * d)
        let c: Double = rad * (1.9148 * sin(m) + 0.02 * sin(2 * m) + 0.0003 * sin(3 * m))
        let l: Double = m + c + rad * 102.9372 + Double.pi
        return (declination(l, 0), rightAscension(l, 0))
    }

    private static func moonCoords(_ d: Double) -> (ra: Double, dec: Double, dist: Double) {
        let l0: Double = rad * (218.316 + 13.176396 * d)
        let m: Double = rad * (134.963 + 13.064993 * d)
        let f: Double = rad * (93.272 + 13.229350 * d)
        let l: Double = l0 + rad * 6.289 * sin(m)
        let b: Double = rad * 5.128 * sin(f)
        let dist: Double = 385001 - 20905 * cos(m)
        return (rightAscension(l, b), declination(l, b), dist)
    }

    /// Высота луны над горизонтом в радианах
    static func altitude(at date: Date, latitude: Double, longitude: Double) -> Double {
        let lw: Double = rad * -longitude
        let phi: Double = rad * latitude
        let d: Double = days(date)
        let moon = moonCoords(d)
        let sidereal: Double = rad * (280.16 + 360.9856235 * d) - lw
        let hourAngle: Double = sidereal - moon.ra
        let sinH: Double = sin(phi) * sin(moon.dec) + cos(phi) * cos(moon.dec) * cos(hourAngle)
        let h: Double = asin(min(1, max(-1, sinH)))
        return h + refraction(h)
    }

    /// fraction: доля освещённого диска 0...1. phase: 0 новолуние, 0.25 первая четверть, 0.5 полнолуние, 0.75 последняя четверть
    static func illumination(at date: Date) -> (fraction: Double, phase: Double) {
        let d: Double = days(date)
        let sun = sunCoords(d)
        let moon = moonCoords(d)
        let sunDistance: Double = 149598000
        let cosPhi: Double = sin(sun.dec) * sin(moon.dec) + cos(sun.dec) * cos(moon.dec) * cos(sun.ra - moon.ra)
        let phi: Double = acos(min(1, max(-1, cosPhi)))
        let inc: Double = atan2(sunDistance * sin(phi), moon.dist - sunDistance * cos(phi))
        let angleY: Double = cos(sun.dec) * sin(sun.ra - moon.ra)
        let angleX: Double = sin(sun.dec) * cos(moon.dec) - cos(sun.dec) * sin(moon.dec) * cos(sun.ra - moon.ra)
        let angle: Double = atan2(angleY, angleX)
        let sign: Double = angle < 0 ? -1 : 1
        let fraction: Double = (1 + cos(inc)) / 2
        let phase: Double = 0.5 + 0.5 * inc * sign / Double.pi
        return (fraction, phase)
    }

    /// Текущий «проход» луны: если она над горизонтом, то последний восход и ближайший заход. Если под горизонтом, то следующие восход и заход
    static func pass(now: Date, latitude: Double, longitude: Double) -> MoonPass {
        let step: TimeInterval = 600
        let threshold: Double = rad * 0.133
        var rises: [Date] = []
        var sets: [Date] = []

        var t: Date = now.addingTimeInterval(-20 * 3600)
        let end: Date = now.addingTimeInterval(32 * 3600)
        var prevT: Date = t
        var prevH: Double = altitude(at: t, latitude: latitude, longitude: longitude) - threshold
        t = t.addingTimeInterval(step)

        while t <= end {
            let h: Double = altitude(at: t, latitude: latitude, longitude: longitude) - threshold
            if prevH < 0 && h >= 0 {
                let f: Double = -prevH / (h - prevH)
                rises.append(prevT.addingTimeInterval(step * f))
            } else if prevH >= 0 && h < 0 {
                let f: Double = prevH / (prevH - h)
                sets.append(prevT.addingTimeInterval(step * f))
            }
            prevT = t
            prevH = h
            t = t.addingTimeInterval(step)
        }

        let isUp: Bool = altitude(at: now, latitude: latitude, longitude: longitude) - threshold >= 0

        if isUp {
            let lastRise: Date? = rises.last(where: { $0 <= now })
            let nextSet: Date? = sets.first(where: { $0 > now })
            var progress: Double? = nil
            if let r = lastRise, let s = nextSet {
                progress = now.timeIntervalSince(r) / s.timeIntervalSince(r)
            }
            return MoonPass(riseTime: lastRise, setTime: nextSet, isUp: true, progress: progress)
        } else {
            let nextRise: Date? = rises.first(where: { $0 > now })
            var nextSet: Date? = nil
            if let r = nextRise {
                nextSet = sets.first(where: { $0 > r })
            }
            return MoonPass(riseTime: nextRise, setTime: nextSet, isUp: false, progress: nil)
        }
    }
}
