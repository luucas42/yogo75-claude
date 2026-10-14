import SwiftUI
import YogoCore

struct EditorView: View {
    @EnvironmentObject var app: AppModel
    @StateObject private var model = EditorModel(app: AppModel.shared)

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                SidebarView(model: model).frame(width: 210)
                Divider()
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Animasyon adı", text: Binding(get: { model.doc.animation.name },
                                                             set: { name in model.edit { $0.rename(name) } }))
                        .textFieldStyle(.roundedBorder)
                        .font(.title3)
                    if model.isBuiltin {
                        Text("Hazır animasyon. İlk değişiklikte bir kopyası oluşturulur ve atamaları kopyaya taşınır.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Picker("", selection: $model.tool) {
                            Label("Kalem", systemImage: "pencil").tag(EditorDocument.Tool.pencil)
                            Label("Silgi", systemImage: "eraser").tag(EditorDocument.Tool.eraser)
                            Label("Doldur", systemImage: "drop.fill").tag(EditorDocument.Tool.fill)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 260)
                        Button { model.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                            .keyboardShortcut("z")
                            .disabled(!model.doc.canUndo)
                        Button { model.redo() } label: { Image(systemName: "arrow.uturn.forward") }
                            .keyboardShortcut("z", modifiers: [.command, .shift])
                            .disabled(!model.doc.canRedo)
                    }
                    CanvasView(model: model)
                    Spacer(minLength: 0)
                }
                .padding(16)
                .frame(minWidth: 380)
                Divider()
                PaletteView(model: model).frame(width: 160)
            }
        }
        .frame(minWidth: 760, minHeight: 420)
        .onDisappear { model.windowClosed() }
    }
}
