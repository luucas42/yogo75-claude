import SwiftUI
import YogoCore

struct MenuView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text("✻ Yogo · \(model.connection.label)")
        Text("Claude: \(model.claudeState.label)" + (model.sessionCount > 0 ? " · \(model.sessionCount) oturum" : ""))
        Divider()
        Toggle("Claude modu", isOn: $model.settings.claudeModeEnabled)
        Picker("Boştayken", selection: $model.settings.idleBehavior) {
            Text("Klavyenin kendi efekti").tag(AppSettings.IdleBehavior.keyboard)
            Text("Sabitlenmiş animasyon (\(model.pinnedName ?? "yok"))").tag(AppSettings.IdleBehavior.pinned)
        }
        Divider()
        Button("Editörü aç…") {
            openWindow(id: "editor")
            NSApp.activate()
        }
        .keyboardShortcut("e")
        Button(model.hooksInstalled ? "Claude Code hook'larını kaldır… (kurulu ✓)" : "Claude Code hook'larını kur…") {
            model.toggleHooks()
        }
        Toggle("Oturum açılınca başlat", isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
        Button("Claude durumunu sıfırla") { model.resetClaude() }
        Divider()
        Button("Çıkış") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }
}
