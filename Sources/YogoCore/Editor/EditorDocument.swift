/// Pure editing model behind the editor window (spec §9): tools, frames, undo/redo.
/// UI calls `checkpoint()` once per gesture; frame operations checkpoint themselves.
public struct EditorDocument: Equatable {
    public enum Tool: String, CaseIterable, Sendable {
        case pencil, eraser, fill
    }

    public static let undoLimit = 100

    public private(set) var animation: PixelAnimation
    public private(set) var selected = 0
    private var undoStack: [PixelAnimation] = []
    private var redoStack: [PixelAnimation] = []

    public init(animation: PixelAnimation) { self.animation = animation }

    public var currentFrame: Frame { animation.frames[selected].frame }
    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }

    public mutating func checkpoint() {
        undoStack.append(animation)
        if undoStack.count > Self.undoLimit { undoStack.removeFirst() }
        redoStack.removeAll()
    }

    /// Applies `tool` at (x, y) on the selected frame. Does not checkpoint.
    public mutating func paint(_ tool: Tool, x: Int, y: Int, color: RGB) {
        guard (0..<Frame.width).contains(x), (0..<Frame.height).contains(y) else { return }
        var f = currentFrame
        switch tool {
        case .pencil: f[x, y] = color
        case .eraser: f[x, y] = .off
        case .fill: f = Self.flood(f, x: x, y: y, with: color)
        }
        animation.frames[selected].pixels = f.pixels
    }

    static func flood(_ frame: Frame, x: Int, y: Int, with color: RGB) -> Frame {
        let target = frame[x, y]
        guard target != color else { return frame }
        var f = frame
        var stack = [(x, y)]
        while let p = stack.popLast() {
            let (cx, cy) = p
            guard (0..<Frame.width).contains(cx), (0..<Frame.height).contains(cy), f[cx, cy] == target else { continue }
            f[cx, cy] = color
            stack += [(cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)]
        }
        return f
    }

    public mutating func select(_ index: Int) {
        selected = min(max(index, 0), animation.frames.count - 1)
    }

    /// Inserts a blank frame after the selected one, with the same duration. No-op at the 20-frame limit.
    public mutating func addFrame() {
        guard animation.frames.count < PixelAnimation.maxFrames else { return }
        checkpoint()
        animation.frames.insert(AnimationFrame(durationMs: animation.frames[selected].durationMs, frame: .blank), at: selected + 1)
        selected += 1
    }

    public mutating func duplicateFrame() {
        guard animation.frames.count < PixelAnimation.maxFrames else { return }
        checkpoint()
        animation.frames.insert(animation.frames[selected], at: selected + 1)
        selected += 1
    }

    /// Removes the selected frame; an animation always keeps at least one.
    public mutating func deleteFrame() {
        guard animation.frames.count > 1 else { return }
        checkpoint()
        animation.frames.remove(at: selected)
        selected = min(selected, animation.frames.count - 1)
    }

    public mutating func setDuration(_ ms: Int) {
        let v = PixelAnimation.clampDuration(ms)
        guard v != animation.frames[selected].durationMs else { return }
        checkpoint()
        animation.frames[selected].durationMs = v
    }

    public mutating func setLoop(_ loop: Bool) {
        guard loop != animation.loop else { return }
        checkpoint()
        animation.loop = loop
    }

    /// Renaming is not an undo step (it is typed character by character).
    public mutating func rename(_ name: String) { animation.name = name }

    public mutating func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(animation)
        animation = previous
        select(selected)
    }

    public mutating func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(animation)
        animation = next
        select(selected)
    }

    /// Gives the document a new identity (used when a built-in is forked) across the whole history,
    /// so undo can never bring back a built-in id.
    public mutating func adopt(id: String, name: String) {
        func renamed(_ a: PixelAnimation) -> PixelAnimation {
            var a = a
            a.id = id
            a.name = name
            return a
        }
        animation = renamed(animation)
        undoStack = undoStack.map(renamed)
        redoStack = redoStack.map(renamed)
    }
}
