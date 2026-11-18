import AppKit
import SwiftUI

// MARK: - Ventana

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let store: UsageStore
    private var window: NSWindow?

    init(store: UsageStore) { self.store = store }

    func show() {
        if window == nil {
            let host = NSHostingController(rootView: SettingsView().environmentObject(store))
            host.sizingOptions = []
            let w = NSWindow(contentViewController: host)
            w.title = "Quotavisor"
            w.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.isMovableByWindowBackground = true
            w.isReleasedWhenClosed = false
            w.delegate = self
            w.setContentSize(NSSize(width: Brand.windowSize.width, height: Brand.windowSize.height))
            w.center()
            window = w
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

// MARK: - Sistema visual

enum Brand {
    static let windowSize = CGSize(width: 780, height: 560)
    static let accent = Color(red: 0.91, green: 0.50, blue: 0.35)
    static let accentGradient = LinearGradient(colors: [Color(red: 0.79, green: 0.37, blue: 0.28),
                                                        Color(red: 1.0, green: 0.66, blue: 0.38)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing)
    static let surface = Color(nsColor: .controlBackgroundColor)
    static let hairline = Color.primary.opacity(0.08)
    static let ok = Color(red: 0.30, green: 0.78, blue: 0.47)
}

private struct VisualEffect: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = .behindWindow
        v.state = .followsWindowActiveState
        return v
    }
    func updateNSView(_ v: NSVisualEffectView, context: Context) { v.material = material }
}

// MARK: - Secciones

enum SettingsPane: String, CaseIterable, Identifiable {
    case general, appearance, providers, about
    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: L("General")
        case .appearance: L("Apariencia")
        case .providers: L("Proveedores")
        case .about: L("Acerca de")
        }
    }

    var subtitle: String {
        switch self {
        case .general: L("Qué aparece en el notch y cada cuánto se actualiza.")
        case .appearance: L("Colores y umbrales de la isla. Los cambios se ven al momento.")
        case .providers: L("Las cuentas de las que Quotavisor lee tu uso.")
        case .about: ""
        }
    }

    var symbol: String {
        switch self {
        case .general: "slider.horizontal.3"
        case .appearance: "paintpalette"
        case .providers: "point.3.connected.trianglepath.dotted"
        case .about: "info.circle"
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var store: UsageStore
    @State private var pane: SettingsPane

    init(initial: SettingsPane = .general) { _pane = State(initialValue: initial) }

    var body: some View {
        HStack(spacing: 0) {
            Sidebar(pane: $pane)
                .frame(width: 228)
            Divider()
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .tint(Brand.accent)
    }

    @ViewBuilder private var detail: some View {
        if pane == .about {
            AboutPane()
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(pane.title)
                            .font(.system(size: 28, weight: .bold))
                            .tracking(-0.6)
                        Text(pane.subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    switch pane {
                    case .general: GeneralPane()
                    case .appearance: AppearancePane()
                    case .providers: ProvidersPane()
                    case .about: EmptyView()
                    }
                }
                .padding(.horizontal, 40)
                .padding(.top, 52)
                .padding(.bottom, 36)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.never)
            .id(pane)
            .transition(.opacity)
        }
    }
}

// MARK: - Barra lateral

private struct Sidebar: View {
    @EnvironmentObject var store: UsageStore
    @Binding var pane: SettingsPane

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 11) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 38, height: 38)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Quotavisor")
                        .font(.system(size: 15, weight: .semibold))
                    Text(L("Tu cuota de IA, en el notch"))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 56)
            .padding(.bottom, 22)

            VStack(spacing: 2) {
                ForEach(SettingsPane.allCases) { p in
                    SidebarItem(pane: p, selected: pane == p) {
                        withAnimation(.smooth(duration: 0.22)) { pane = p }
                    }
                }
            }
            .padding(.horizontal, 10)

            Spacer()

            LiveStatus()
                .padding(.horizontal, 12)
                .padding(.bottom, 14)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(VisualEffect(material: .sidebar))
    }
}

private struct SidebarItem: View {
    let pane: SettingsPane
    let selected: Bool
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: pane.symbol)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(selected ? Brand.accent : .secondary)
                    .frame(width: 20)
                Text(pane.title)
                    .font(.system(size: 13, weight: selected ? .semibold : .regular))
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.primary.opacity(selected ? 0.085 : (hover ? 0.045 : 0)))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .animation(.smooth(duration: 0.15), value: hover)
    }
}

/// Uso en vivo al pie de la barra lateral.
private struct LiveStatus: View {
    @EnvironmentObject var store: UsageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(store.enabledProviders) { p in
                let pct = store.snapshots[p]?.session?.percent(at: .now)
                HStack(spacing: 10) {
                    RingGauge(value: pct ?? 0, tint: store.tint(p, percent: pct), lineWidth: 3)
                        .frame(width: 18, height: 18)
                    Text(p.name)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(pct.map { "\(Int($0.rounded()))%" } ?? "—")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: pct ?? 0))
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.045))
        )
    }
}

// MARK: - Piezas de formulario

private struct FormGroup<Content: View>: View {
    var title: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }
            VStack(spacing: 0) { content }
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Brand.surface))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Brand.hairline))
        }
    }
}

private struct Row<Trailing: View>: View {
    let title: String
    var detail: String? = nil
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13))
                if let detail {
                    Text(detail).font(.system(size: 11.5)).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 12)
            trailing
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

private struct RowDivider: View {
    var body: some View { Rectangle().fill(Brand.hairline).frame(height: 1).padding(.leading, 16) }
}

/// Selector en píldoras, más ligero que un segmented clásico.
private struct Chips<T: Hashable>: View {
    let options: [T]
    @Binding var selection: T
    let label: (T) -> String

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { o in
                let on = o == selection
                Text(label(o))
                    .font(.system(size: 12, weight: on ? .semibold : .regular))
                    .monospacedDigit()
                    .foregroundStyle(on ? Color.white : Color.primary.opacity(0.75))
                    .fixedSize()
                    .frame(minWidth: 34)
                    .frame(height: 26)
                    .background(Capsule().fill(on ? AnyShapeStyle(Brand.accentGradient) : AnyShapeStyle(Color.clear)))
                    .contentShape(Capsule())
                    .onTapGesture { withAnimation(.smooth(duration: 0.2)) { selection = o } }
            }
        }
        .padding(3)
        .background(Capsule().fill(Color.primary.opacity(0.06)))
    }
}

/// Isla recogida en miniatura.
private struct MiniIsland: View {
    @EnvironmentObject var store: UsageStore
    let provider: Provider
    let percent: Double
    var width: CGFloat = 150

    var body: some View {
        HStack(spacing: 0) {
            RingGauge(value: percent, tint: store.tint(provider, percent: percent), lineWidth: 2.6)
                .frame(width: 15, height: 15)
                .frame(width: 30)
            Spacer(minLength: 0)
            PercentLabel(value: percent, size: 11,
                         tint: percent >= store.warnAt ? store.tint(provider, percent: percent) : .white,
                         showSign: store.showPercentSign)
                .frame(width: 34)
        }
        .padding(.horizontal, 6)
        .frame(width: width, height: 30)
        .background(NotchShape(earRadius: 6, bottomRadius: 10).fill(Palette.notch))
        .environment(\.colorScheme, .dark)
    }
}

/// Fondo de escritorio para las vistas previas.
private let wallpaper = LinearGradient(colors: [Color(red: 0.20, green: 0.24, blue: 0.40),
                                                Color(red: 0.55, green: 0.38, blue: 0.48),
                                                Color(red: 0.93, green: 0.62, blue: 0.48)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)

// MARK: - General

private struct GeneralPane: View {
    @EnvironmentObject var store: UsageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            FormGroup(title: L("En el notch")) {
                HStack(spacing: 12) {
                    ChoiceTile(title: L("Automático"), detail: L("El último que uses"),
                               selected: store.pinned == nil, action: { store.pinned = nil }) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                            .frame(width: 130, height: 30)
                            .background(NotchShape(earRadius: 6, bottomRadius: 10).fill(Palette.notch))
                    }

                    ForEach(store.enabledProviders) { p in
                        let pct = store.snapshots[p]?.session?.percent(at: .now) ?? 0
                        ChoiceTile(title: p.name, detail: L("Siempre este"),
                                   selected: store.pinned == p, action: { store.pinned = p }) {
                            MiniIsland(provider: p, percent: pct, width: 130)
                        }
                    }
                }
                .padding(14)
            }

            FormGroup(title: L("Actualización")) {
                Row(title: L("Actualizar cada"), detail: L("Minutos entre lecturas")) {
                    Chips(options: [1, 2, 5, 10, 15, 30], selection: $store.refreshMinutes) { "\($0)" }
                }
                RowDivider()
                Row(title: L("Última lectura"), detail: lastUpdated) {
                    Button {
                        store.refreshNow()
                    } label: {
                        Label(L("Actualizar ahora"), systemImage: "arrow.clockwise")
                    }
                    .disabled(store.isRefreshing)
                }
            }

            FormGroup(title: L("Sistema")) {
                Row(title: L("Abrir al iniciar sesión"),
                    detail: L("Quotavisor se abre solo, sin icono en el Dock.")) {
                    Toggle("", isOn: $store.launchAtLogin).toggleStyle(.switch).labelsHidden()
                }
            }
        }
    }

    private var lastUpdated: String {
        guard let d = Provider.allCases.compactMap({ store.snapshots[$0]?.updatedAt }).min() else { return L("Cargando…") }
        let s = Int(Date.now.timeIntervalSince(d))
        return s < 60 ? L("Hace un momento") : L("Hace %@ min", "\(s / 60)")
    }
}

private struct ChoiceTile<Preview: View>: View {
    let title: String
    let detail: String
    let selected: Bool
    let action: () -> Void
    @ViewBuilder var preview: Preview
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(wallpaper)
                    preview
                }
                .frame(height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(spacing: 1) {
                    Text(title).font(.system(size: 12.5, weight: .semibold))
                    Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.primary.opacity(hover && !selected ? 0.04 : 0))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(selected ? Brand.accent : Brand.hairline, lineWidth: selected ? 2 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .animation(.smooth(duration: 0.2), value: selected)
    }
}

// MARK: - Apariencia

private struct AppearancePane: View {
    @EnvironmentObject var store: UsageStore
    @State private var simulated: Double = 42
    @State private var previewProvider: Provider = .claude

    private let swatches: [Color] = [
        Palette.claude, Palette.codex,
        Color(red: 0.55, green: 0.55, blue: 1.0), Color(red: 0.98, green: 0.45, blue: 0.62),
        Color(red: 0.40, green: 0.74, blue: 1.0), Color(red: 0.95, green: 0.82, blue: 0.35),
        Color(white: 0.92),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            preview

            FormGroup(title: L("Colores")) {
                ForEach(Array(Provider.allCases.enumerated()), id: \.element) { i, p in
                    if i > 0 { RowDivider() }
                    Row(title: p.name) {
                        SwatchPicker(selection: p == .claude ? $store.claudeColor : $store.codexColor,
                                     swatches: swatches)
                    }
                }
            }

            FormGroup(title: L("Umbrales")) {
                ZoneBar(warn: store.warnAt, crit: store.critAt, base: store.baseColor(previewProvider))
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 4)
                Row(title: L("Aviso"), detail: L("El anillo pasa a ámbar.")) {
                    ValueSlider(value: $store.warnAt, range: 50...95)
                }
                RowDivider()
                Row(title: L("Crítico"), detail: L("El anillo pasa a rojo.")) {
                    ValueSlider(value: $store.critAt, range: 60...100)
                }
            }

            FormGroup {
                Row(title: L("Ancho de la isla"), detail: L("Más estrecha pisa menos la barra de menús.")) {
                    HStack(spacing: 12) {
                        Slider(value: $store.sideWidth, in: 28...48, step: 2).frame(width: 190)
                        Text("\(Int(store.sideWidth)) pt")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .frame(width: 38, alignment: .trailing)
                    }
                }
                RowDivider()
                Row(title: L("Mostrar el símbolo %")) {
                    Toggle("", isOn: $store.showPercentSign).toggleStyle(.switch).labelsHidden()
                }
                RowDivider()
                Row(title: L("Restablecer apariencia"), detail: L("Vuelve a los colores y umbrales originales.")) {
                    Button(L("Restablecer")) { withAnimation(.smooth) { store.resetAppearance() } }
                }
            }
        }
    }

    /// Escritorio en miniatura con barra de menús y la isla real.
    private var preview: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                wallpaper
                Rectangle()
                    .fill(.white.opacity(0.16))
                    .frame(height: 30)
                    .overlay(alignment: .leading) {
                        HStack(spacing: 14) {
                            Image(systemName: "apple.logo").font(.system(size: 12, weight: .semibold))
                            Text("Finder").font(.system(size: 12, weight: .semibold))
                            Text(L("Archivo")).font(.system(size: 12))
                            Text(L("Edición")).font(.system(size: 12))
                        }
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.leading, 14)
                    }
                    .overlay(alignment: .trailing) {
                        HStack(spacing: 12) {
                            Image(systemName: "wifi")
                            Image(systemName: "battery.75percent")
                            Text("10:41")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.trailing, 14)
                    }
                MiniIsland(provider: previewProvider, percent: simulated, width: 200)
            }
            .frame(height: 150)

            HStack(spacing: 14) {
                Picker("", selection: $previewProvider) {
                    ForEach(Provider.allCases) { Text($0.name).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 190)
                Text(L("Simular uso"))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Slider(value: $simulated, in: 0...100)
                Text("\(Int(simulated))%")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .frame(width: 36, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .frame(height: 50)
            .background(Brand.surface)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Brand.hairline))
        .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
    }
}

private struct SwatchPicker: View {
    @Binding var selection: Color
    let swatches: [Color]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(swatches.enumerated()), id: \.offset) { _, c in
                let on = c.hex == selection.hex
                Circle()
                    .fill(c)
                    .frame(width: 18, height: 18)
                    .overlay(Circle().strokeBorder(Color.primary.opacity(0.12)))
                    .padding(3)
                    .overlay(Circle().strokeBorder(on ? c : .clear, lineWidth: 2))
                    .contentShape(Circle())
                    .onTapGesture { withAnimation(.smooth(duration: 0.2)) { selection = c } }
            }
            ColorPicker("", selection: $selection, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 28)
        }
    }
}

private struct ValueSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        HStack(spacing: 12) {
            Slider(value: $value, in: range, step: 5).frame(width: 190)
            Text("\(Int(value))%")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .frame(width: 38, alignment: .trailing)
        }
    }
}

/// Barra 0–100 % con las tres zonas de color.
private struct ZoneBar: View {
    let warn: Double
    let crit: Double
    let base: Color

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { g in
                let w = g.size.width
                HStack(spacing: 2) {
                    Capsule().fill(base).frame(width: max(0, w * warn / 100 - 2))
                    Capsule().fill(Palette.warn).frame(width: max(0, w * (crit - warn) / 100 - 2))
                    Capsule().fill(Palette.crit)
                }
            }
            .frame(height: 8)
            .animation(.smooth(duration: 0.25), value: warn)
            .animation(.smooth(duration: 0.25), value: crit)

            HStack {
                Text("0%")
                Spacer()
                Text("100%")
            }
            .font(.system(size: 10.5, design: .rounded))
            .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Proveedores

private struct ProvidersPane: View {
    @EnvironmentObject var store: UsageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(Provider.allCases) { p in
                ProviderCard(provider: p)
            }
        }
    }
}

private struct ProviderCard: View {
    @EnvironmentObject var store: UsageStore
    let provider: Provider

    var body: some View {
        let p = provider
        let snap = store.snapshots[p]
        let on = store.enabled.contains(p)
        let now = Date.now
        let pct = snap?.session?.percent(at: now)
        let week = snap?.weekly?.percent(at: now)

        FormGroup {
            HStack(spacing: 14) {
                ZStack {
                    RingGauge(value: pct ?? 0, tint: store.tint(p, percent: pct), lineWidth: 5)
                    Text(pct.map { "\(Int($0.rounded()))" } ?? "—")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }
                .frame(width: 48, height: 48)
                .opacity(on ? 1 : 0.35)

                VStack(alignment: .leading, spacing: 3) {
                    Text(p.name).font(.system(size: 15, weight: .semibold))
                    HStack(spacing: 6) {
                        Circle().fill(statusColor(snap)).frame(width: 7, height: 7)
                        Text(status(snap))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Toggle("", isOn: Binding(get: { on }, set: { store.setEnabled(p, $0) }))
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            .padding(16)

            if on, let snap, snap.hasData {
                RowDivider()
                Row(title: L("Últimas 5 horas"), detail: resetText(snap.session?.resetsAt, now: now)) {
                    Text(pctText(pct))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }
                RowDivider()
                Row(title: L("Esta semana"), detail: resetText(snap.weekly?.resetsAt, now: now)) {
                    HStack(spacing: 10) {
                        LinearMeter(value: week ?? 0, tint: store.tint(p, percent: week), track: Color.primary.opacity(0.1))
                            .frame(width: 90, height: 5)
                        Text(pctText(week))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }
            if p == .claude && store.claudeSessionExpired {
                RowDivider()
                Row(title: L("Sesión caducada"),
                    detail: L("Abre Claude Code un momento para renovarla. Tus datos vuelven solos.")) {
                    Button(L("Renovar sesión")) { store.renewClaudeSession() }
                        .buttonStyle(.borderedProminent)
                }
            }
            RowDivider()
            Row(title: L("Fuente"),
                detail: p == .claude ? L("Tu sesión de Claude Code (Llavero de macOS). Solo lectura.")
                                     : L("Registros locales de Codex en ~/.codex. Sin conexión.")) {
                EmptyView()
            }
        }
    }

    private func pctText(_ v: Double?) -> String { v.map { "\(Int($0.rounded()))%" } ?? "—" }

    private func resetText(_ d: Date?, now: Date) -> String? {
        guard let d, d > now else { return nil }
        let m = Int(d.timeIntervalSince(now) / 60)
        if m >= 24 * 60 { return L("Se reinicia en %@", "\(m / 1440) d \((m % 1440) / 60) h") }
        if m >= 60 { return L("Se reinicia en %@", "\(m / 60) h \(m % 60) min") }
        return L("Se reinicia en %@", "\(max(m, 1)) min")
    }

    private func status(_ s: UsageSnapshot?) -> String {
        guard let s else { return L("Cargando…") }
        if let e = s.error { return e }
        return s.hasData ? L("Conectado") : L("Sin datos todavía")
    }

    private func statusColor(_ s: UsageSnapshot?) -> Color {
        guard let s else { return .secondary }
        if s.error != nil { return Palette.warn }
        return s.hasData ? Brand.ok : .secondary
    }
}

// MARK: - Acerca de

private struct AboutPane: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 132, height: 132)
                .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
            Text("Quotavisor")
                .font(.system(size: 30, weight: .bold))
                .tracking(-0.6)
                .padding(.top, 14)
            Text(L("Versión %@", Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            Text(L("Tu cuota de Claude Code y Codex,\nsiempre a la vista en el notch."))
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.top, 14)

            HStack(spacing: 10) {
                SocialLink(title: "X", handle: "@humbergarc", url: "https://x.com/humbergarc")
                SocialLink(title: "Instagram", handle: "@humbergarc", url: "https://instagram.com/humbergarc")
            }
            .padding(.top, 28)

            Spacer()
            Text(L("Hecho por @humbergarc"))
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .padding(.bottom, 22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SocialLink: View {
    let title: String
    let handle: String
    let url: String
    @State private var hover = false

    var body: some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(.primary)
                    Text(handle).font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 10)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(hover ? Brand.accent : .secondary)
            }
            .padding(.horizontal, 14)
            .frame(width: 170, height: 50)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Brand.surface))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(hover ? Brand.accent.opacity(0.6) : Brand.hairline))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .animation(.smooth(duration: 0.15), value: hover)
    }
}

// MARK: - Capturas (desarrollo):  Quotavisor --snapshot <carpeta>

@MainActor
enum SettingsSnapshot {
    static func run(store: UsageStore, to dir: URL) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var queue: [(SettingsPane, NSAppearance.Name)] = []
        for a in [NSAppearance.Name.aqua, .darkAqua] { for p in SettingsPane.allCases { queue.append((p, a)) } }
        func next() {
            guard !queue.isEmpty else { NSApp.terminate(nil); return }
            let (pane, look) = queue.removeFirst()
            let host = NSHostingController(rootView: SettingsView(initial: pane).environmentObject(store))
            let w = NSWindow(contentViewController: host)
            w.styleMask = [.titled, .fullSizeContentView]
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.appearance = NSAppearance(named: look)
            w.setContentSize(Brand.windowSize)
            w.setFrameOrigin(NSPoint(x: -4000, y: 0))
            w.orderFront(nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                let v = w.contentView!
                if let rep = v.bitmapImageRepForCachingDisplay(in: v.bounds) {
                    v.cacheDisplay(in: v.bounds, to: rep)
                    let name = "\(pane.rawValue)-\(look == .darkAqua ? "dark" : "light").png"
                    try? rep.representation(using: .png, properties: [:])?.write(to: dir.appending(path: name))
                }
                w.close()
                next()
            }
        }
        next()
    }
}
