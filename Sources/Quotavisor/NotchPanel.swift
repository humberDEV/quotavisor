import AppKit
import SwiftUI

/// Ventana sin bordes pegada al notch. Su tamaño sigue al estado (recogida/expandida)
/// para no robar clics a la barra de menús cuando está recogida.
@MainActor
final class NotchPanel: NSPanel {
    private let store: UsageStore
    private var pendingCollapse: DispatchWorkItem?
    private var pendingShrink: DispatchWorkItem?
    /// Hueco transparente alrededor de la isla abierta para que la sombra no se corte.
    private let shadowMargin: CGFloat = 64
    private let openAnim = Animation.spring(response: 0.4, dampingFraction: 0.9)
    /// Cierre sin rebote: amortiguamiento crítico, nunca sobrepasa el tamaño del notch.
    private let closeAnim = Animation.spring(response: 0.34, dampingFraction: 1.0)

    init(store: UsageStore) {
        self.store = store
        super.init(contentRect: .zero,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        colorSpace = .sRGB
        isMovable = false
        hidesOnDeactivate = false
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]

        let host = HoverHostingView(rootView: AnyView(IslandView().environmentObject(store)))
        host.onHover = { [weak self] inside in self?.hoverChanged(inside) }
        host.menuProvider = { [weak self] in self?.makeMenu() }
        contentView = host
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    // MARK: Posición

    private var targetScreen: NSScreen {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main ?? NSScreen.screens[0]
    }

    /// `force`: recoloca aunque el notch no haya cambiado (p. ej. al cambiar el ancho).
    func place(force: Bool = false) {
        let s = targetScreen
        var g = NotchGeometry()
        if s.safeAreaInsets.top > 0, let l = s.auxiliaryTopLeftArea, let r = s.auxiliaryTopRightArea {
            g.notchWidth = s.frame.width - l.width - r.width
            // La barra de menús puede medir 1 px más que el notch: cubrimos ambas
            // para que no asome una línea gris bajo la isla.
            g.notchHeight = max(s.safeAreaInsets.top, s.frame.maxY - s.visibleFrame.maxY)
            g.hasNotch = true
        } else {
            // Sin notch (pantalla externa): una píldora bajo la barra de menús.
            g.notchWidth = 120
            g.notchHeight = max(NSStatusBar.system.thickness, 24)
        }
        // Al entrar o salir de pantalla completa macOS avisa de «cambio de pantalla»
        // aunque el notch sea el mismo: si no cambió nada, no tocamos la ventana
        // (redimensionarla a mitad de la animación era lo que daba tirones).
        if force || g != store.geometry || frame.isEmpty {
            store.geometry = g
            applyFrame(expanded: store.isExpanded)
        }
        orderFrontRegardless()
    }

    private func applyFrame(expanded: Bool) {
        let s = targetScreen
        let size = expanded ? store.expandedSize : store.collapsedSize
        let margin = expanded ? shadowMargin : 0
        let w = size.width + margin * 2
        let h = size.height + margin
        let midX: CGFloat
        if let l = s.auxiliaryTopLeftArea, store.geometry.hasNotch {
            midX = s.frame.minX + l.width + store.geometry.notchWidth / 2
        } else {
            midX = s.frame.midX
        }
        (contentView as? HoverHostingView)?.hoverMargin = margin
        setFrame(NSRect(x: midX - w / 2, y: s.frame.maxY - h, width: w, height: h), display: true)
    }

    // MARK: Hover

    private func hoverChanged(_ inside: Bool) {
        if inside {
            pendingCollapse?.cancel()
            pendingShrink?.cancel()
            guard !store.isExpanded else { return }
            applyFrame(expanded: true)
            withAnimation(openAnim) { store.isExpanded = true }
            // La lectura (y su animación de números) espera a que termine de abrirse.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in self?.store.refreshIfStale() }
        } else {
            let work = DispatchWorkItem { [weak self] in self?.collapse() }
            pendingCollapse = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
        }
    }

    func collapseNow() {
        pendingCollapse?.cancel()
        collapse()
    }

    private func collapse() {
        guard store.isExpanded else { return }
        withAnimation(closeAnim) { store.isExpanded = false }
        let shrink = DispatchWorkItem { [weak self] in
            guard let self, !self.store.isExpanded else { return }
            self.applyFrame(expanded: false)
        }
        pendingShrink = shrink
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: shrink)
    }

    // MARK: Menú (clic derecho)

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(ActionItem(L("Ajustes…")) { [weak self] in self?.store.openSettings?() })
        if store.claudeSessionExpired {
            menu.addItem(ActionItem(L("Renovar sesión de Claude…")) { [weak self] in self?.store.renewClaudeSession() })
        }
        menu.addItem(ActionItem(L("Actualizar ahora")) { [weak self] in self?.store.refreshNow() })
        menu.addItem(.separator())

        let show = NSMenuItem(title: L("Mostrar en el notch"), action: nil, keyEquivalent: "")
        let showMenu = NSMenu()
        let auto = ActionItem(L("Automático (el último usado)")) { [weak self] in self?.store.pinned = nil }
        auto.state = store.pinned == nil ? .on : .off
        showMenu.addItem(auto)
        for p in Provider.allCases {
            let item = ActionItem(p.name) { [weak self] in self?.store.pinned = p }
            item.state = store.pinned == p ? .on : .off
            showMenu.addItem(item)
        }
        show.submenu = showMenu
        menu.addItem(show)

        let every = NSMenuItem(title: L("Actualizar cada"), action: nil, keyEquivalent: "")
        let everyMenu = NSMenu()
        for m in [1, 2, 5, 10, 15, 30] {
            let item = ActionItem("\(m) min") { [weak self] in self?.store.refreshMinutes = m }
            item.state = store.refreshMinutes == m ? .on : .off
            everyMenu.addItem(item)
        }
        every.submenu = everyMenu
        menu.addItem(every)

        menu.addItem(.separator())
        let login = ActionItem(L("Abrir al iniciar sesión")) { [weak self] in
            guard let self else { return }
            self.store.launchAtLogin.toggle()
        }
        login.state = store.launchAtLogin ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())
        menu.addItem(ActionItem(L("Salir de Quotavisor")) { NSApp.terminate(nil) })
        return menu
    }
}

final class ActionItem: NSMenuItem {
    private let handler: () -> Void
    init(_ title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(fire), keyEquivalent: "")
        target = self
    }
    required init(coder: NSCoder) { fatalError() }
    @objc private func fire() { handler() }
}

/// Hosting view con tracking area propia: funciona aunque la app no esté activa.
final class HoverHostingView: NSHostingView<AnyView> {
    var onHover: ((Bool) -> Void)?
    var menuProvider: (() -> NSMenu?)?
    private var area: NSTrackingArea?
    /// Margen de sombra: el hover cuenta solo sobre la isla, no sobre la sombra.
    var hoverMargin: CGFloat = 0 { didSet { if hoverMargin != oldValue { updateTrackingAreas() } } }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let area { removeTrackingArea(area) }
        let m = hoverMargin
        let rect = NSRect(x: m, y: isFlipped ? 0 : m,
                          width: max(0, bounds.width - m * 2), height: max(0, bounds.height - m))
        let a = NSTrackingArea(rect: rect,
                               options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                               owner: self)
        addTrackingArea(a)
        area = a
    }

    override func mouseEntered(with event: NSEvent) { onHover?(true) }
    override func mouseExited(with event: NSEvent) { onHover?(false) }
    override func menu(for event: NSEvent) -> NSMenu? { menuProvider?() }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
