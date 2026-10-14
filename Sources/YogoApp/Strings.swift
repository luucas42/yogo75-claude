import YogoCore

extension ClaudeState {
    var label: String {
        switch self {
        case .idle: return "Boşta"
        case .thinking: return "Düşünüyor"
        case .tool: return "Araç çalıştırıyor"
        case .waiting: return "Onay bekliyor"
        case .done: return "Bitti"
        }
    }
}

extension AppModel.Connection {
    var label: String {
        switch self {
        case .usb: return "USB bağlı"
        case .bluetooth: return "Bluetooth · canlı mod kapalı"
        case .disconnected: return "Bağlı değil"
        case .busy: return "Başka bir program klavyeyi kullanıyor"
        }
    }
}
