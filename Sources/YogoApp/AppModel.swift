import AppKit
import IOKit.hid
import ServiceManagement
import YogoCore

/// Owns the whole pipeline (spec §4). Everything runs on the main thread: the 20 Hz timer,
/// IOKit callbacks (main run loop) and the socket handler (main queue).
final class AppModel: ObservableObject {
    static let shared = AppModel()

    enum Connection: String {
        case usb, bluetooth, disconnected, busy
    }

    @Published private(set) var connection: Connection = .disconnected
    @Published private(set) var claudeState: ClaudeState = .idle
    @Published private(set) var sessionCount = 0
    @Published private(set) var animations: [PixelAnimation] = BuiltinAnimations.all
    @Published private(set) var hooksInstalled = false
    @Published var settings = AppSettings.load() {
        didSet {
            settings.save()
            settingsChanged()
        }
    }
    /// Set by the editor while "Klavyede canlı önizle" is on (spec §6, rule 1).
    @Published var previewAnimation: PixelAnimation?

    let tracker = ClaudeTracker()
    let store = AnimationStore(directory: YogoPaths.animationsDir)
    private let driver = ScreenDriver()
    private var selector = SceneSelector()
    private var rejections = RejectionGuard()
    private(set) var assignments = BuiltinAnimations.defaultAssignments
    private var pinned: PixelAnimation?

    private let monitor = HIDMonitor()
    private var device: HIDScreenDevice?
    private var deviceRef: IOHIDDevice?
    private var server: SocketServer?
    private var frameTimer: Timer?
    private var statusTimer: Timer?
    private let log = Log.shared

    // MARK: lifecycle

    func start() {
        store.reload()
        if !store.skippedFiles.isEmpty { log.warn("skipped animation files: \(store.skippedFiles)") }
        animations = store.all
        settingsChanged()
        startServer()
        monitor.onMatch = { [weak self] ref in
            self?.deviceRef = ref
            self?.openDevice()
        }
        monitor.onRemove = { [weak self] ref in self?.deviceRemoved(ref) }
        monitor.onReport = { [weak self] report in self?.handleReply(report) }
        monitor.start()
        observeSleep()
        frameTimer = repeating(Double(Player.tickMs) / 1000) { [weak self] in self?.tick() }
        statusTimer = repeating(5) { [weak self] in self?.periodicCheck() }
        periodicCheck()
        log.info("started")
    }

    func shutdown() {
        frameTimer?.invalidate()
        statusTimer?.invalidate()
        driver.release()
        closeDevice()
        server?.stop()
        log.info("quit")
        log.flush()
    }

    private func repeating(_ interval: TimeInterval, _ body: @escaping () -> Void) -> Timer {
        let t = Timer(timeInterval: interval, repeats: true) { _ in body() }
        RunLoop.main.add(t, forMode: .common)   // keeps running while the menu is open
        return t
    }

    private func startServer() {
        let s = SocketServer(path: YogoPaths.socket, handlerQueue: .main) { [weak self] line in
            guard let self else { return nil }
            return IPCDispatch.handle(line,
                                      onSignal: { self.tracker.apply($0, at: Date()) },
                                      status: { StatusReply(connection: self.connection.rawValue,
                                                            state: self.tracker.state(at: Date()),
                                                            sessions: self.tracker.sessionCount) })
        }
        do {
            try s.start()
            server = s
        } catch SocketServer.ServerError.alreadyRunning {
            let a = NSAlert()
            a.messageText = "Yogo zaten çalışıyor"
            a.informativeText = "Klavyeyi başka bir Yogo örneği kullanıyor. Bu örnek kapanacak."
            a.runModal()
            NSApp.terminate(nil)
        } catch {
            log.warn("socket server failed: \(error)")
        }
    }

    // MARK: device

    private func openDevice() {
        guard device == nil, let ref = deviceRef else {
            refreshConnection()
            return
        }
        let d = HIDScreenDevice(ref: ref)
        let r = d.open()
        if r == kIOReturnSuccess {
            device = d
            driver.attach(d)
            log.info("keyboard opened")
        } else {
            log.warn("keyboard open failed: 0x\(String(UInt32(bitPattern: r), radix: 16))")
        }
        refreshConnection()
    }

    private func closeDevice() {
        driver.attach(nil)
        device?.close()
        device = nil
    }

    private func deviceRemoved(_ ref: IOHIDDevice) {
        guard let current = deviceRef, CFEqual(current, ref) else { return }
        closeDevice()
        deviceRef = nil
        log.info("keyboard removed")
        refreshConnection()
    }

    private func refreshConnection() {
        let c: Connection
        if device != nil {
            c = .usb
        } else if deviceRef != nil {
            c = .busy
        } else if BluetoothProbe.isPresent() {
            c = .bluetooth
        } else {
            c = .disconnected
        }
        if c != connection {
            connection = c
            log.info("connection: \(c.rawValue)")
        }
    }

    /// Every 5 s: retry a busy device, re-check Bluetooth presence and the hooks file.
    private func periodicCheck() {
        if device == nil, deviceRef != nil { openDevice() } else { refreshConnection() }
        let installed = HooksSetup.isInstalled()
        if installed != hooksInstalled { hooksInstalled = installed }
    }

    private func handleReply(_ reply: [UInt8]) {
        let now = Date()
        let wasPaused = rejections.isPaused(at: now)
        rejections.record(reply: reply, at: now)
        if Packet.isRejection(reply) {
            log.warn("rejected: " + reply.prefix(8).map { String(format: "%02x", $0) }.joined(separator: " "))
        }
        if !wasPaused, rejections.isPaused(at: now) { log.warn("5 rejections in a row: live mode paused for 30 s") }
    }

    private func observeSleep() {
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            self?.log.info("sleep")
            self?.driver.release()
            self?.closeDevice()
        }
        nc.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.log.info("wake")
            self?.openDevice()
        }
    }

    // MARK: 20 Hz loop

    private func tick() {
        let now = Date()
        let state = tracker.state(at: now)
        if state != claudeState { claudeState = state }
        if tracker.sessionCount != sessionCount { sessionCount = tracker.sessionCount }
        let inputs = SceneInputs(preview: previewAnimation,
                                 claudeModeEnabled: settings.claudeModeEnabled,
                                 claudeState: state,
                                 assignments: assignments,
                                 pinned: settings.idleBehavior == .pinned ? pinned : nil)
        let scene = selector.select(inputs, at: now)
        let frame = rejections.isPaused(at: now) ? nil : Player.frame(for: scene, at: now)
        driver.tick(frame: frame, at: now)
        if driver.consecutiveErrors >= 5 {
            log.warn("5 send errors in a row: reopening keyboard")
            closeDevice()
            openDevice()
        }
    }

    // MARK: animations and settings

    private func settingsChanged() {
        assignments = Assignments.resolve(settings.assignments, lookup: store.get)
        pinned = settings.pinnedAnimationID.flatMap(store.get)
        tracker.config.staleTimeout = TimeInterval(settings.staleTimeoutMinutes * 60)
        tracker.config.waitingTimeout = TimeInterval(settings.waitingTimeoutMinutes * 60)
        tracker.config.doneDuration = Double(Player.totalMs(assignedAnimation(for: .done))) / 1000
    }

    func assignedAnimation(for state: ClaudeState) -> PixelAnimation {
        assignments[state] ?? BuiltinAnimations.defaultAssignments[state] ?? BuiltinAnimations.thinking
    }

    func saveAnimation(_ a: PixelAnimation) {
        do {
            try store.save(a)
        } catch {
            log.warn("save \(a.id) failed: \(error)")
            return
        }
        animations = store.all
        settingsChanged()
    }

    func deleteAnimation(_ id: String) {
        var s = settings
        s.assignments = s.assignments.filter { $0.value != id }
        if s.pinnedAnimationID == id {
            s.pinnedAnimationID = nil
            s.idleBehavior = .keyboard
        }
        try? store.delete(id)
        animations = store.all
        settings = s
    }

    func assign(_ id: String?, to state: ClaudeState) { settings.assignments[state.rawValue] = id }

    func pin(_ id: String) {
        var s = settings
        s.pinnedAnimationID = id
        s.idleBehavior = .pinned
        settings = s
    }

    /// Spec §7: when a built-in is forked, every state (and the pin) that showed it follows the copy.
    func moveAssignments(from old: String, to new: String) {
        var s = settings
        for state in [ClaudeState.thinking, .tool, .waiting, .done]
        where (s.assignments[state.rawValue] ?? BuiltinAnimations.defaultAssignments[state]?.id) == old {
            s.assignments[state.rawValue] = new
        }
        if s.pinnedAnimationID == old { s.pinnedAnimationID = new }
        settings = s
    }

    var pinnedName: String? { pinned?.name }

    // MARK: menu actions

    func resetClaude() {
        tracker.reset()
        log.info("claude state reset")
    }

    func toggleHooks() { hooksInstalled = HooksSetup.toggle() }

    var launchAtLogin: Bool { SMAppService.mainApp.status == .enabled }

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            log.warn("login item: \(error)")
        }
        objectWillChange.send()
    }
}
