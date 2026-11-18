import AppKit
import ServiceManagement
import SwiftUI

struct NotchGeometry: Equatable {
    var notchWidth: CGFloat = 185
    var notchHeight: CGFloat = 32
    var hasNotch = false
}

@MainActor
final class UsageStore: ObservableObject {
    @Published var snapshots: [Provider: UsageSnapshot] = [:]
    @Published var isExpanded = false
    @Published var isRefreshing = false
    @Published var geometry = NotchGeometry()

    @Published var pinned: Provider? {
        didSet { UserDefaults.standard.set(pinned?.rawValue, forKey: "pinned") }
    }
    @Published var refreshMinutes: Int {
        didSet {
            UserDefaults.standard.set(refreshMinutes, forKey: "refreshMinutes")
            scheduleTimer()
        }
    }

    // Apariencia (persistida)
    @Published var claudeColor: Color { didSet { defaults.set(claudeColor.hex, forKey: "claudeColor") } }
    @Published var codexColor: Color { didSet { defaults.set(codexColor.hex, forKey: "codexColor") } }
    @Published var warnAt: Double { didSet { defaults.set(warnAt, forKey: "warnAt"); if critAt < warnAt { critAt = warnAt } } }
    @Published var critAt: Double { didSet { defaults.set(critAt, forKey: "critAt"); if warnAt > critAt { warnAt = critAt } } }
    @Published var showPercentSign: Bool { didSet { defaults.set(showPercentSign, forKey: "showPercentSign") } }
    @Published var enabled: Set<Provider> {
        didSet {
            defaults.set(enabled.map(\.rawValue), forKey: "enabled")
            if let p = pinned, !enabled.contains(p) { pinned = nil }
        }
    }

    /// La pone AppDelegate: abre la ventana de ajustes.
    var openSettings: (() -> Void)?

    private let defaults = UserDefaults.standard
    private let claude = ClaudeSource()
    private var timer: Timer?

    // Medidas del diseño
    /// Ancho de cada lado de la isla junto al notch (personalizable).
    @Published var sideWidth: CGFloat {
        didSet { UserDefaults.standard.set(Double(sideWidth), forKey: "sideWidth") }
    }
    let earRadius: CGFloat = 6       // curva cóncava superior
    let rowHeight: CGFloat = 56

    init() {
        pinned = UserDefaults.standard.string(forKey: "pinned").flatMap(Provider.init(rawValue:))
        let m = UserDefaults.standard.integer(forKey: "refreshMinutes")
        refreshMinutes = m > 0 ? m : 5

        let d = UserDefaults.standard
        let sw = d.double(forKey: "sideWidth")
        sideWidth = sw > 0 ? CGFloat(sw) : 36
        claudeColor = d.string(forKey: "claudeColor").flatMap(Color.init(hex:)) ?? Palette.claude
        codexColor = d.string(forKey: "codexColor").flatMap(Color.init(hex:)) ?? Palette.codex
        warnAt = d.object(forKey: "warnAt") as? Double ?? 80
        critAt = d.object(forKey: "critAt") as? Double ?? 95
        showPercentSign = d.object(forKey: "showPercentSign") as? Bool ?? true
        let saved = (d.stringArray(forKey: "enabled") ?? []).compactMap(Provider.init(rawValue:))
        enabled = saved.isEmpty ? Set(Provider.allCases) : Set(saved)
    }

    // MARK: Apariencia

    var enabledProviders: [Provider] { Provider.allCases.filter(enabled.contains) }

    func baseColor(_ p: Provider) -> Color { p == .claude ? claudeColor : codexColor }

    func tint(_ p: Provider, percent: Double?) -> Color {
        guard let percent else { return baseColor(p) }
        if percent >= critAt { return Palette.crit }
        if percent >= warnAt { return Palette.warn }
        return baseColor(p)
    }

    func setEnabled(_ p: Provider, _ on: Bool) {
        var s = enabled
        if on { s.insert(p) } else { s.remove(p) }
        guard !s.isEmpty else { NSSound.beep(); return }   // siempre queda al menos uno
        enabled = s
    }

    func resetAppearance() {
        claudeColor = Palette.claude
        codexColor = Palette.codex
        warnAt = 80
        critAt = 95
        showPercentSign = true
        sideWidth = 36
    }

    // MARK: Tamaños

    var collapsedSize: CGSize {
        CGSize(width: geometry.notchWidth + sideWidth * 2 + earRadius * 2, height: geometry.notchHeight)
    }

    var expandedSize: CGSize {
        CGSize(width: max(collapsedSize.width + 110, 380),
               height: geometry.notchHeight + rowHeight * CGFloat(max(enabled.count, 1)) + 26)
    }

    // MARK: Proveedor destacado

    /// Fijado por el usuario, o el que se usó más recientemente.
    var featured: Provider {
        if let pinned, enabled.contains(pinned) { return pinned }
        if enabled.count == 1, let only = enabled.first { return only }
        let c = snapshots[.claude], x = snapshots[.codex]
        if c?.hasData != true, x?.hasData == true { return .codex }
        if x?.hasData != true { return .claude }
        return (x?.lastActive ?? .distantPast) > (c?.lastActive ?? .distantPast) ? .codex : .claude
    }

    func toggle(_ p: Provider) {
        withAnimation(.smooth(duration: 0.35)) { pinned = (pinned == p) ? nil : p }
    }

    // MARK: Refresco

    func start() {
        scheduleTimer()
        refreshNow()
    }

    func refreshIfStale() {
        let oldest = Provider.allCases.compactMap { snapshots[$0]?.updatedAt }.min() ?? .distantPast
        if Date.now.timeIntervalSince(oldest) > 60 { refreshNow() }
    }

    func refreshNow() {
        guard !isRefreshing else { return }
        isRefreshing = true
        Task {
            async let c = claude.fetch()
            async let x = Task.detached(priority: .utility) { CodexSource().fetch() }.value
            let (cs, xs) = await (c, x)
            withAnimation(.smooth(duration: 0.6)) {
                snapshots[.claude] = merge(cs, old: snapshots[.claude])
                snapshots[.codex] = merge(xs, old: snapshots[.codex])
            }
            isRefreshing = false
        }
    }

    /// Si una consulta falla, conserva los últimos valores buenos y muestra el error.
    private func merge(_ new: UsageSnapshot, old: UsageSnapshot?) -> UsageSnapshot {
        guard !new.hasData, let old, old.hasData else { return new }
        var s = old
        s.error = new.error
        s.lastActive = new.lastActive ?? old.lastActive
        return s
    }

    private func scheduleTimer() {
        timer?.invalidate()
        let interval = TimeInterval(refreshMinutes * 60)
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshNow() }
        }
        t.tolerance = interval * 0.2   // deja que macOS agrupe despertares
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    // MARK: Sesión de Claude

    var claudeSessionExpired: Bool {
        snapshots[.claude]?.error?.hasPrefix("Sesión caducada") == true
    }

    /// Abre Terminal con `claude`: al arrancar, Claude Code renueva su sesión
    /// en el Llavero y Quotavisor la recoge en la siguiente lectura.
    func renewClaudeSession() {
        let url = FileManager.default.temporaryDirectory.appending(path: "quotavisor-renovar.command")
        let script = """
        #!/bin/zsh -l
        clear
        echo "Quotavisor: renovando la sesión de Claude Code…"
        echo "Cuando Claude Code arranque, ya puedes salir con /exit."
        echo
        claude
        """
        do {
            try script.write(to: url, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
            NSWorkspace.shared.open(url)
        } catch { NSSound.beep() }
        // Vuelve a leer en cuanto Claude Code haya tenido tiempo de renovar.
        for delay in [20.0, 75.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.refreshNow() }
        }
    }

    // MARK: Inicio de sesión

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch { NSSound.beep() }
            objectWillChange.send()
        }
    }
}
