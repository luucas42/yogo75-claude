import AppKit
import SwiftUI
import UniformTypeIdentifiers
import YogoCore

final class EditorModel: ObservableObject {
    @Published var doc: EditorDocument
    @Published var tool: EditorDocument.Tool = .pencil
    @Published var color = RGB(hex: "e2794f")!
    @Published var livePreview = false {
        didSet { pushPreview() }
    }
    @Published private(set) var playing = false
    @Published private(set) var playStart = Date()

    private let app: AppModel

    init(app: AppModel) {
        self.app = app
        doc = EditorDocument(animation: app.assignedAnimation(for: .thinking))
    }

    var isBuiltin: Bool { AnimationStore.isBuiltin(doc.animation.id) }

    func open(_ a: PixelAnimation) {
        doc = EditorDocument(animation: a)
        playing = false
        pushPreview()
    }

    func select(_ index: Int) { doc.select(index) }

    // MARK: painting: one drag is one undo step

    func beginStroke() {
        forkIfBuiltin()
        doc.checkpoint()
    }

    func paint(x: Int, y: Int) {
        doc.paint(tool, x: x, y: y, color: color)
        pushPreview()
    }

    func endStroke() { save() }

    /// Structural edits (frames, durations, loop, name) all go through here.
    func edit(_ change: (inout EditorDocument) -> Void) {
        forkIfBuiltin()
        change(&doc)
        save()
        pushPreview()
    }

    func undo() { doc.undo(); save(); pushPreview() }
    func redo() { doc.redo(); save(); pushPreview() }

    func togglePlay() {
        playStart = Date()
        playing.toggle()
    }

    func importImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .gif, .jpeg]
        panel.allowsMultipleSelection = false
        NSApp.activate()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let a = try ImageImporter.importAnimation(from: url, name: url.deletingPathExtension().lastPathComponent)
            app.saveAnimation(a)
            open(a)
        } catch {
            let alert = NSAlert()
            alert.messageText = "Görsel içe aktarılamadı"
            alert.informativeText = "\(error)"
            alert.runModal()
        }
    }

    func windowClosed() {
        save()
        livePreview = false
        playing = false
        app.previewAnimation = nil
    }

    /// Spec §7: the first edit of a built-in creates a user copy and moves its assignments/pin to it.
    /// Must run before `checkpoint()` so the undo history never holds a built-in id.
    private func forkIfBuiltin() {
        guard isBuiltin else { return }
        let original = doc.animation.id
        let copy = AnimationStore.copy(of: doc.animation)
        doc.adopt(id: copy.id, name: copy.name)
        app.saveAnimation(doc.animation)
        app.moveAssignments(from: original, to: copy.id)
    }

    private func save() {
        if !isBuiltin { app.saveAnimation(doc.animation) }
    }

    private func pushPreview() {
        app.previewAnimation = livePreview ? doc.animation : nil
    }
}
