import SwiftUI
import YogoCore

struct PaletteView: View {
    @ObservedObject var model: EditorModel

    static let swatches = ["e2794f", "ffd9c4", "7a3f2a", "4fd27a", "2a6b3f", "ff4d4d", "4d8bff", "f1c46b", "ffffff", "000000"]
        .compactMap(RGB.init(hex:))

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PALET").font(.caption2).foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(28), spacing: 6), count: 4), spacing: 6) {
                ForEach(Self.swatches, id: \.self) { c in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(c.color)
                        .frame(width: 28, height: 28)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(model.color == c ? Color.accentColor : .clear, lineWidth: 2))
                        .onTapGesture {
                            model.color = c
                            if model.tool == .eraser { model.tool = .pencil }
                        }
                }
            }
            Text("ÖZEL RENK").font(.caption2).foregroundStyle(.secondary)
            ColorPicker("", selection: Binding(get: { model.color.color }, set: { model.color = RGB($0) }), supportsOpacity: false)
                .labelsHidden()
            Spacer()
        }
        .padding(12)
    }
}
