import SwiftUI

@main
struct YogoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel.shared

    var body: some Scene {
        MenuBarExtra {
            MenuView().environmentObject(model)
        } label: {
            Text("✻")
        }
        .menuBarExtraStyle(.menu)

        Window("Yogo Editör", id: "editor") {
            EditorView().environmentObject(model)
        }
        .defaultLaunchBehavior(.suppressed)
        .windowResizability(.contentMinSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) { AppModel.shared.start() }
    func applicationWillTerminate(_ notification: Notification) { AppModel.shared.shutdown() }
}
