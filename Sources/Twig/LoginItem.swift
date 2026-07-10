import ServiceManagement

/// "Açılışta başlat" — SMAppService.mainApp sarmalayıcı. Durum sistemce tutulur
/// (config'e yazılmaz); toggle her görünümde canlı okur.
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("LoginItem toggle failed: \(error)")
        }
    }
}
