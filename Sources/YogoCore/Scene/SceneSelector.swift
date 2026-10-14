import Foundation

/// What the screen should do right now. Named ScreenScene to avoid SwiftUI.Scene.
public enum ScreenScene: Equatable {
    case play(PixelAnimation, since: Date, loop: Bool)
    case release
}

public struct SceneInputs {
    public var preview: PixelAnimation?
    public var claudeModeEnabled: Bool
    public var claudeState: ClaudeState
    public var assignments: [ClaudeState: PixelAnimation]
    public var pinned: PixelAnimation?

    public init(preview: PixelAnimation? = nil, claudeModeEnabled: Bool = true, claudeState: ClaudeState = .idle,
                assignments: [ClaudeState: PixelAnimation] = BuiltinAnimations.defaultAssignments,
                pinned: PixelAnimation? = nil) {
        self.preview = preview
        self.claudeModeEnabled = claudeModeEnabled
        self.claudeState = claudeState
        self.assignments = assignments
        self.pinned = pinned
    }
}

/// Spec §6: preview > Claude (non-idle) > pinned > release. The start time resets only when the source
/// changes, so editing a playing animation or the same state repeating never restarts it.
public struct SceneSelector {
    private var current: (key: String, since: Date)?

    public init() {}

    public mutating func select(_ i: SceneInputs, at now: Date) -> ScreenScene {
        let pick: (key: String, anim: PixelAnimation, loop: Bool)?
        if let p = i.preview {
            pick = ("preview:\(p.id)", p, true)
        } else if i.claudeModeEnabled, i.claudeState != .idle, let a = i.assignments[i.claudeState] {
            pick = ("claude:\(i.claudeState.rawValue)", a, a.loop)
        } else if let p = i.pinned {
            pick = ("pinned:\(p.id)", p, true)
        } else {
            pick = nil
        }
        guard let pick else {
            current = nil
            return .release
        }
        if current?.key != pick.key { current = (pick.key, now) }
        return .play(pick.anim, since: current?.since ?? now, loop: pick.loop)
    }
}

extension BuiltinAnimations {
    public static let defaultAssignments: [ClaudeState: PixelAnimation] = [
        .thinking: thinking, .tool: tool, .waiting: waiting, .done: done,
    ]
}
