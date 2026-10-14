import AppKit
import YogoCore

/// Menu flow around HooksInstaller (spec §10): confirm, back up, merge. Only the user triggers this.
enum HooksSetup {
    static var cliPath: String { Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/yogo").path }

    static func isInstalled() -> Bool {
        guard let data = try? Data(contentsOf: YogoPaths.claudeSettings.resolvingSymlinksInPath()) else { return false }
        return HooksInstaller.isInstalled(data)
    }

    /// Shows a confirmation, then installs or removes. Returns the resulting installed state.
    static func toggle() -> Bool {
        let installing = !isInstalled()
        let alert = NSAlert()
        if installing {
            alert.messageText = "Claude Code hook'ları kurulsun mu?"
            alert.informativeText = """
            ~/.claude/settings.json dosyasına şu olaylar için arka planda (async) çalışan bir hook eklenecek:
            \(HooksInstaller.events.joined(separator: ", "))

            Komut: \(HooksInstaller.command(cliPath: cliPath))

            Önce zaman damgalı bir yedek alınır. Diğer ayarların ve hook'ların korunur, ama dosya yeniden biçimlendirilir.
            Açık Claude Code oturumları yeni hook'ları ancak yeniden başlatıldıklarında yükler.
            """
            alert.addButton(withTitle: "Kur")
        } else {
            alert.messageText = "Claude Code hook'ları kaldırılsın mı?"
            alert.informativeText = "Yalnızca Yogo'nun eklediği girdiler silinir. Önce yedek alınır."
            alert.addButton(withTitle: "Kaldır")
        }
        alert.addButton(withTitle: "Vazgeç")
        NSApp.activate()
        guard alert.runModal() == .alertFirstButtonReturn else { return !installing }
        do {
            let backup = try HooksInstaller.apply(to: YogoPaths.claudeSettings) { data in
                if installing { return try HooksInstaller.install(into: data, cliPath: cliPath) }
                return try HooksInstaller.uninstall(from: data)
            }
            Log.shared.info("\(installing ? "hooks installed" : "hooks removed"); backup: \(backup?.path ?? "none")")
            return installing
        } catch {
            let e = NSAlert()
            e.messageText = "settings.json güncellenemedi"
            e.informativeText = "Dosyaya dokunulmadı.\n\n\(error)"
            e.runModal()
            return !installing
        }
    }
}
