import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = UsageStore()
    private var panel: NotchPanel?
    private var bag = Set<AnyCancellable>()
    private lazy var settings = SettingsWindowController(store: store)

    func applicationDidFinishLaunching(_ notification: Notification) {
        store.openSettings = { [weak self] in
            guard let self else { return }
            self.panel?.collapseNow()
            self.settings.show()
        }
        if let i = CommandLine.arguments.firstIndex(of: "--snapshot"), i + 1 < CommandLine.arguments.count {
            store.start()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [store] in
                SettingsSnapshot.run(store: store, to: URL(fileURLWithPath: CommandLine.arguments[i + 1]))
            }
            return
        }
        let panel = NotchPanel(store: store)
        self.panel = panel
        panel.place()
        store.$sideWidth.dropFirst().removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.panel?.place(force: true) }
            .store(in: &bag)
        store.start()

        // Primera vez desde /Applications: se activa el arranque al iniciar sesión.
        let d = UserDefaults.standard
        if !d.bool(forKey: "loginSetupDone"), Bundle.main.bundlePath.hasPrefix("/Applications") {
            store.launchAtLogin = true
            d.set(true, forKey: "loginSetupDone")
        }

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.panel?.place() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.store.refreshNow() }
        }
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
