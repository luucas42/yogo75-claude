import Foundation

public struct AnimationFrame: Codable, Hashable, Sendable {
    public var durationMs: Int
    public var pixels: [RGB]

    public init(durationMs: Int, frame: Frame) {
        self.durationMs = durationMs
        self.pixels = frame.pixels
    }

    /// Only valid after `PixelAnimation.validate()` has passed (36 pixels).
    public var frame: Frame { Frame(pixels: pixels) }
}

/// A 6×6 animation, stored as `<id>.json` (spec §7). Named PixelAnimation to avoid SwiftUI.Animation.
public struct PixelAnimation: Codable, Hashable, Identifiable, Sendable {
    public static let formatVersion = 1
    public static let maxFrames = 20
    public static let durationRange = 50...5000

    public var version: Int
    public var id: String
    public var name: String
    public var loop: Bool
    public var frames: [AnimationFrame]

    public init(id: String, name: String, loop: Bool, frames: [AnimationFrame]) {
        self.version = PixelAnimation.formatVersion
        self.id = id
        self.name = name
        self.loop = loop
        self.frames = frames
    }

    public enum ValidationError: Error, Equatable {
        case unsupportedVersion(Int)
        case emptyID
        case noFrames
        case tooManyFrames(Int)
        case badPixelCount(frame: Int, count: Int)
        case badDuration(frame: Int, ms: Int)
    }

    public func validate() throws {
        guard version == PixelAnimation.formatVersion else { throw ValidationError.unsupportedVersion(version) }
        guard !id.isEmpty else { throw ValidationError.emptyID }
        guard !frames.isEmpty else { throw ValidationError.noFrames }
        guard frames.count <= PixelAnimation.maxFrames else { throw ValidationError.tooManyFrames(frames.count) }
        for (i, f) in frames.enumerated() {
            guard f.pixels.count == Frame.pixelCount else {
                throw ValidationError.badPixelCount(frame: i, count: f.pixels.count)
            }
            guard PixelAnimation.durationRange.contains(f.durationMs) else {
                throw ValidationError.badDuration(frame: i, ms: f.durationMs)
            }
        }
    }

    public static func clampDuration(_ ms: Int) -> Int {
        min(max(ms, durationRange.lowerBound), durationRange.upperBound)
    }

    public static func decode(_ data: Data) throws -> PixelAnimation {
        let a = try JSONDecoder().decode(PixelAnimation.self, from: data)
        try a.validate()
        return a
    }

    public func encoded() throws -> Data {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try e.encode(self)
    }
}
