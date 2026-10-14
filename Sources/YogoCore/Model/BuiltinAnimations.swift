/// The spark set approved in brainstorming (spec §7). Defined in code, not as bundle resources,
/// so a hand-assembled .app can never lose them.
public enum BuiltinAnimations {
    static let palette: [Character: RGB] = [
        "O": RGB(hex: "e2794f")!, "o": RGB(hex: "7a3f2a")!, "W": RGB(hex: "ffd9c4")!,
        "G": RGB(hex: "4fd27a")!, "g": RGB(hex: "2a6b3f")!, ".": .off,
    ]

    /// Six 6-character rows, top to bottom. `letter` recolours every "O".
    static func shape(_ rows: [String], as letter: Character = "O") -> Frame {
        precondition(rows.count == Frame.height && rows.allSatisfy { $0.count == Frame.width })
        return Frame(pixels: rows.joined().map { palette[$0 == "O" ? letter : $0]! })
    }

    static let sparkRows = ["O.OO.O", ".OOOO.", "OOOOOO", "OOOOOO", ".OOOO.", "O.OO.O"]
    static let ringRows = [".OOOO.", "O....O", "O....O", "O....O", "O....O", ".OOOO."]

    static let dot = shape(["......", "......", "..OO..", "..OO..", "......", "......"])
    static let cross = shape(["......", "..OO..", ".OOOO.", ".OOOO.", "..OO..", "......"])
    static let plus = shape(["..OO..", "..OO..", "OOOOOO", "OOOOOO", "..OO..", "..OO.."])
    static let xray = shape(["O....O", ".O..O.", "..OO..", "..OO..", ".O..O.", "O....O"])
    static let spark = shape(sparkRows)
    static let sparkW = shape(sparkRows, as: "W")
    static let sparkD = shape(sparkRows, as: "o")
    static let ringG = shape(ringRows, as: "G")
    static let ringg = shape(ringRows, as: "g")
    static let off = Frame.blank

    static func make(_ id: String, _ name: String, loop: Bool, _ seq: [(Frame, Int)]) -> PixelAnimation {
        PixelAnimation(id: id, name: name, loop: loop,
                       frames: seq.map { AnimationFrame(durationMs: $0.1, frame: $0.0) })
    }

    public static let thinking = make("builtin.thinking", "Düşünüyor", loop: true, [
        (dot, 160), (cross, 160), (plus, 160), (spark, 260), (plus, 160), (cross, 160), (dot, 160), (off, 120),
    ])
    public static let tool = make("builtin.tool", "Araç çalıştırıyor", loop: true, [(plus, 260), (xray, 260)])
    public static let waiting = make("builtin.waiting", "Onay bekliyor", loop: true, [
        (sparkW, 140), (off, 110), (sparkW, 140), (off, 110), (sparkD, 700),
    ])
    public static let done = make("builtin.done", "Bitti", loop: false, [
        (dot, 90), (cross, 90), (spark, 140), (ringG, 700), (ringg, 300),
    ])

    public static let all: [PixelAnimation] = [thinking, tool, waiting, done]
}
