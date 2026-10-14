import SwiftUI
import YogoCore

struct FrameStripView: View {
    @ObservedObject var model: EditorModel
    @EnvironmentObject var app: AppModel
    private let states: [ClaudeState] = [.thinking, .tool, .waiting, .done]

    var body: some View {
        let frames = model.doc.animation.frames
        let selected = model.doc.selected
        VStack(spacing: 8) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(Array(frames.enumerated()), id: \.offset) { i, f in
                        VStack(spacing: 3) {
                            thumbnail(f.frame)
                                .overlay(RoundedRectangle(cornerRadius: 5)
                                    .stroke(i == selected ? Color.orange : Color.gray.opacity(0.3), lineWidth: i == selected ? 2 : 1))
                            Text("\(i + 1) · \(f.durationMs)").font(.caption2).foregroundStyle(.secondary).monospacedDigit()
                        }
                        .onTapGesture { model.select(i) }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
            }
            HStack(spacing: 10) {
                Button("+ Kare") { model.edit { $0.addFrame() } }
                    .disabled(frames.count >= PixelAnimation.maxFrames)
                Button("⧉ Çoğalt") { model.edit { $0.duplicateFrame() } }
                    .disabled(frames.count >= PixelAnimation.maxFrames)
                Button("Sil") { model.edit { $0.deleteFrame() } }
                    .disabled(frames.count <= 1)
                Stepper(value: Binding(get: { model.doc.animation.frames[model.doc.selected].durationMs },
                                       set: { v in model.edit { $0.setDuration(v) } }),
                        in: PixelAnimation.durationRange, step: 10) {
                    Text("\(frames[selected].durationMs) ms").monospacedDigit()
                }
                Toggle("Döngü", isOn: Binding(get: { model.doc.animation.loop }, set: { v in model.edit { $0.setLoop(v) } }))
                Spacer()
                Toggle("Klavyede canlı önizle", isOn: $model.livePreview).toggleStyle(.switch)
                Button(model.playing ? "⏸ Durdur" : "▶ Oynat") { model.togglePlay() }
                Menu("Duruma ata") {
                    ForEach(states, id: \.self) { s in
                        Button(s.label) { app.assign(model.doc.animation.id, to: s) }
                    }
                    Divider()
                    Menu("Varsayılana dön") {
                        ForEach(states, id: \.self) { s in
                            Button(s.label) { app.assign(nil, to: s) }
                        }
                    }
                }
                .fixedSize()
                Button("📌 Ekrana sabitle") { app.pin(model.doc.animation.id) }
                    .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
        }
    }

    private func thumbnail(_ f: Frame) -> some View {
        VStack(spacing: 1) {
            ForEach(0..<Frame.height, id: \.self) { y in
                HStack(spacing: 1) {
                    ForEach(0..<Frame.width, id: \.self) { x in
                        Rectangle().fill(f[x, y].color).frame(width: 7, height: 7)
                    }
                }
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 5).fill(Color(white: 0.04)))
    }
}
