import Foundation

/// Maps (scene, time) to the frame to show. Durations snap to the 50 ms tick grid (spec §4).
public enum Player {
    public static let tickMs = 50

    public static func quantize(_ ms: Int) -> Int {
        max(tickMs, Int((Double(ms) / Double(tickMs)).rounded()) * tickMs)
    }

    public static func totalMs(_ a: PixelAnimation) -> Int {
        a.frames.reduce(0) { $0 + quantize($1.durationMs) }
    }

    public static func frame(for scene: ScreenScene, at now: Date) -> Frame? {
        guard case let .play(anim, since, loop) = scene, let last = anim.frames.last else { return nil }
        let total = totalMs(anim)
        var t = max(0, Int(now.timeIntervalSince(since) * 1000))
        if loop {
            t %= total
        } else if t >= total {
            return last.frame
        }
        for f in anim.frames {
            let d = quantize(f.durationMs)
            if t < d { return f.frame }
            t -= d
        }
        return last.frame
    }
}
