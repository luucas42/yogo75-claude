import SwiftUI
import YogoCore

struct CanvasView: View {
    @ObservedObject var model: EditorModel
    @State private var stroking = false
    @State private var lastCell: Int?

    static let cell: CGFloat = 40
    static let gap: CGFloat = 5

    var body: some View {
        TimelineView(.animation(paused: !model.playing)) { context in
            grid(displayed(at: context.date))
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(white: 0.04)))
    }

    private func displayed(at date: Date) -> Frame {
        guard model.playing else { return model.doc.currentFrame }
        return Player.frame(for: .play(model.doc.animation, since: model.playStart, loop: true), at: date) ?? model.doc.currentFrame
    }

    private func grid(_ frame: Frame) -> some View {
        VStack(spacing: Self.gap) {
            ForEach(0..<Frame.height, id: \.self) { y in
                HStack(spacing: Self.gap) {
                    ForEach(0..<Frame.width, id: \.self) { x in
                        RoundedRectangle(cornerRadius: 6)
                            .fill(frame[x, y].color)
                            .frame(width: Self.cell, height: Self.cell)
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    guard !model.playing else { return }
                    let step = Self.cell + Self.gap
                    let x = Int((value.location.x / step).rounded(.down))
                    let y = Int((value.location.y / step).rounded(.down))
                    guard (0..<Frame.width).contains(x), (0..<Frame.height).contains(y) else { return }
                    if !stroking {
                        stroking = true
                        lastCell = nil
                        model.beginStroke()
                    }
                    let index = y * Frame.width + x
                    guard index != lastCell else { return }
                    lastCell = index
                    model.paint(x: x, y: y)
                }
                .onEnded { _ in
                    guard stroking else { return }
                    stroking = false
                    model.endStroke()
                }
        )
    }
}
