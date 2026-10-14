import SwiftUI
import YogoCore

struct SidebarView: View {
    @ObservedObject var model: EditorModel
    @EnvironmentObject var app: AppModel
    private let states: [ClaudeState] = [.thinking, .tool, .waiting, .done]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    header("CLAUDE DURUMLARI")
                    ForEach(states, id: \.self) { state in
                        let a = app.assignedAnimation(for: state)
                        row(state.label, detail: AnimationStore.isBuiltin(a.id) ? "varsayılan" : a.name, id: a.id) { model.open(a) }
                    }
                    header("BENİM ANİMASYONLARIM")
                    ForEach(app.animations.filter { !AnimationStore.isBuiltin($0.id) }) { a in
                        row(a.name, detail: app.settings.pinnedAnimationID == a.id ? "📌 sabit" : nil, id: a.id) { model.open(a) }
                            .contextMenu {
                                Button("Sil", role: .destructive) {
                                    if model.doc.animation.id == a.id { model.open(app.assignedAnimation(for: .thinking)) }
                                    app.deleteAnimation(a.id)
                                }
                            }
                    }
                }
                .padding(8)
            }
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                Button("+ Yeni animasyon") {
                    let a = AnimationStore.newBlank()
                    app.saveAnimation(a)
                    model.open(a)
                }
                Button("⇪ PNG/GIF içe aktar…") { model.importImage() }
            }
            .buttonStyle(.link)
            .padding(10)
        }
    }

    private func header(_ text: String) -> some View {
        Text(text).font(.caption2).foregroundStyle(.secondary).padding(.top, 10).padding(.horizontal, 8)
    }

    private func row(_ title: String, detail: String?, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).lineLimit(1)
                Spacer()
                if let detail { Text(detail).font(.caption).foregroundStyle(.orange).lineLimit(1) }
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
            .background(RoundedRectangle(cornerRadius: 6).fill(model.doc.animation.id == id ? Color.orange.opacity(0.18) : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
