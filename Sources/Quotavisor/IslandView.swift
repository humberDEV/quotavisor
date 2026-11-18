import SwiftUI

// MARK: - Paleta

enum Palette {
    static let claude = Color(red: 0.85, green: 0.47, blue: 0.34)   // arcilla (por defecto)
    static let codex  = Color(red: 0.42, green: 0.84, blue: 0.74)   // menta fría (por defecto)
    static let warn   = Color(red: 1.00, green: 0.71, blue: 0.26)
    static let crit   = Color(red: 1.00, green: 0.38, blue: 0.33)
    static let text2  = Color.white.opacity(0.56)
    static let text3  = Color.white.opacity(0.38)
    /// Negro absoluto (0,0,0) en sRGB, igual que el notch físico.
    static let notch  = Color(.sRGB, red: 0, green: 0, blue: 0, opacity: 1)
}

extension Color {
    init?(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(.sRGB,
                  red: Double((v >> 16) & 0xFF) / 255,
                  green: Double((v >> 8) & 0xFF) / 255,
                  blue: Double(v & 0xFF) / 255)
    }

    var hex: String {
        let c = NSColor(self).usingColorSpace(.sRGB) ?? .white
        return String(format: "%02X%02X%02X",
                      Int((c.redComponent * 255).rounded()),
                      Int((c.greenComponent * 255).rounded()),
                      Int((c.blueComponent * 255).rounded()))
    }
}

// MARK: - Isla

struct IslandView: View {
    @EnvironmentObject var store: UsageStore

    var body: some View {
        let exp = store.isExpanded
        let size = exp ? store.expandedSize : store.collapsedSize

        ZStack(alignment: .top) {
            NotchShape(earRadius: store.earRadius, bottomRadius: exp ? 24 : 10, minSize: store.collapsedSize)
                .fill(Palette.notch)
                .frame(width: size.width, height: size.height)
                .background(alignment: .top) {
                    // Sombra solo por debajo de la barra de menús: así el borde
                    // superior y las orejas se funden limpios con el notch físico.
                    // Va siempre al tamaño final (no se recalcula en cada fotograma del
                    // muelle) y aparece cuando la isla ya casi ha crecido: abrir no cuesta
                    // nada aunque el Mac vaya cargado. Dos capas para que se difumine suave.
                    let full = store.expandedSize
                    let top = store.geometry.notchHeight + 16
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Palette.notch)
                        .frame(width: max(0, full.width - store.earRadius * 2 - 40),
                               height: max(0, full.height - top - 14))
                        .offset(y: top)
                        .shadow(color: .black.opacity(0.22), radius: 10, y: 6)
                        .shadow(color: .black.opacity(0.30), radius: 30, y: 18)
                        .opacity(exp ? 1 : 0)
                        // Al cerrar, la sombra desaparece al instante: sin estela.
                        .animation(exp ? .easeOut(duration: 0.22).delay(0.26) : nil, value: exp)
                }

            Group {
                if exp {
                    ExpandedContent().transition(.asymmetric(
                        insertion: .riseFade,
                        removal: .opacity.animation(.easeOut(duration: 0.09))))
                } else {
                    CollapsedContent().transition(.asymmetric(
                        insertion: .opacity.animation(.easeOut(duration: 0.2).delay(0.12)),
                        removal: .opacity.animation(.easeOut(duration: 0.08))))
                }
            }
            .padding(.horizontal, store.earRadius)
            .frame(width: size.width, height: size.height, alignment: .top)
            .clipShape(NotchShape(earRadius: store.earRadius, bottomRadius: exp ? 24 : 10, minSize: store.collapsedSize))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .environment(\.colorScheme, .dark)
    }
}

// MARK: - Recogida: un proveedor, anillo + %

struct CollapsedContent: View {
    @EnvironmentObject var store: UsageStore

    var body: some View {
        let p = store.featured
        let snap = store.snapshots[p]
        let pct = snap?.session?.percent(at: .now)
        let ringSize = min(16, store.geometry.notchHeight - 14)

        HStack(spacing: 0) {
            RingGauge(value: pct ?? 0, tint: store.tint(p, percent: pct), lineWidth: 2.6)
                .frame(width: ringSize, height: ringSize)
                .opacity(snap?.hasData == true ? 1 : 0.4)
                .frame(width: store.sideWidth)

            Spacer(minLength: store.geometry.notchWidth)

            PercentLabel(value: pct, size: 11,
                         tint: pct.map { $0 >= store.warnAt ? store.tint(p, percent: $0) : .white } ?? Palette.text3,
                         showSign: store.showPercentSign)
                .frame(width: store.sideWidth)
                .offset(x: -1)
        }
        .frame(height: store.geometry.notchHeight)
        .id(p)   // al cambiar de proveedor, cruza con el blur
        .transition(.blurFade)
        .animation(.smooth(duration: 0.4), value: p)
    }
}

// MARK: - Expandida

struct ExpandedContent: View {
    @EnvironmentObject var store: UsageStore

    var body: some View {
        VStack(spacing: 4) {
            header
            ForEach(store.enabledProviders) { p in
                ProviderRow(provider: p,
                            snapshot: store.snapshots[p],
                            isFeatured: store.featured == p,
                            isPinned: store.pinned == p)
                    .frame(height: store.rowHeight)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if p == .claude && store.claudeSessionExpired { store.renewClaudeSession() } else { store.toggle(p) }
                    }
            }
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 12)
    }

    /// Ocupa la franja del notch: estado a la izquierda, refrescar a la derecha.
    private var header: some View {
        HStack {
            TimelineView(.periodic(from: .now, by: 30)) { ctx in
                Text(updatedText(now: ctx.date))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Palette.text3)
            }
            Spacer(minLength: store.geometry.notchWidth)
            Button { store.openSettings?() } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Palette.text2)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Ajustes")
            Button { store.refreshNow() } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Palette.text2)
                    .rotationEffect(.degrees(store.isRefreshing ? 360 : 0))
                    .animation(store.isRefreshing ? .linear(duration: 0.9).repeatForever(autoreverses: false) : .default,
                               value: store.isRefreshing)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Actualizar ahora")
        }
        .padding(.horizontal, 8)
        .frame(height: store.geometry.notchHeight)
    }

    private func updatedText(now: Date) -> String {
        guard let d = Provider.allCases.compactMap({ store.snapshots[$0]?.updatedAt }).min() else {
            return "Cargando…"
        }
        let s = Int(now.timeIntervalSince(d))
        if s < 60 { return "Al día" }
        return "Hace \(s / 60) min"
    }
}

struct ProviderRow: View {
    let provider: Provider
    let snapshot: UsageSnapshot?
    let isFeatured: Bool
    let isPinned: Bool
    @EnvironmentObject var store: UsageStore
    @State private var hovering = false

    var body: some View {
        let now = Date.now
        let pct = snapshot?.session?.percent(at: now)
        let week = snapshot?.weekly?.percent(at: now)
        let tint = store.tint(provider, percent: pct)

        HStack(spacing: 12) {
            ZStack {
                RingGauge(value: pct ?? 0, tint: tint, lineWidth: 4)
                PercentLabel(value: pct, size: 11, tint: .white, showSign: false)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(provider.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    if isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Palette.text3)
                            .rotationEffect(.degrees(40))
                    }
                }
                Text(subtitle(now: now))
                    .font(.system(size: 11))
                    .foregroundStyle(snapshot?.error != nil && snapshot?.hasData != true ? Palette.warn : Palette.text2)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 5) {
                HStack(spacing: 0) {
                    Text("Semana ")
                        .foregroundStyle(Palette.text3)
                    Text(week.map { "\(Int($0.rounded()))%" } ?? "–")
                        .foregroundStyle(Palette.text2)
                        .monospacedDigit()
                        .contentTransition(.numericText(value: week ?? 0))
                }
                .font(.system(size: 11, weight: .medium))
                LinearMeter(value: week ?? 0, tint: store.tint(provider, percent: week))
                    .frame(width: 76, height: 4)
                if let left = weeklyReset(now: now) {
                    Text(left)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(Palette.text3)
                        .monospacedDigit()
                        .lineLimit(1)
                        .fixedSize()
                }
            }
        }
        .padding(.horizontal, 10)
        .frame(maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(isFeatured ? 0.075 : (hovering ? 0.04 : 0)))
        )
        .onHover { hovering = $0 }
        .animation(.smooth(duration: 0.25), value: hovering)
        .animation(.smooth(duration: 0.35), value: isFeatured)
    }

    /// «se reinicia en 3 d 4 h» para la ventana semanal; nada si no hay fecha.
    private func weeklyReset(now: Date) -> String? {
        guard let reset = snapshot?.weekly?.resetsAt, reset > now else { return nil }
        let mins = Int(reset.timeIntervalSince(now) / 60)
        let d = mins / 1440, h = (mins % 1440) / 60, m = mins % 60
        let left = d > 0 ? "\(d) d \(h) h" : h > 0 ? "\(h) h \(m) min" : "\(max(m, 1)) min"
        return "se reinicia en \(left)"
    }

    private func subtitle(now: Date) -> String {
        guard let snapshot else { return "Cargando…" }
        if !snapshot.hasData { return snapshot.error ?? "Sin datos todavía" }
        guard let reset = snapshot.session?.resetsAt, reset > now else { return "Ventana de 5 h libre" }
        let mins = Int(reset.timeIntervalSince(now) / 60)
        let left = mins >= 60 ? "\(mins / 60) h \(mins % 60) min" : "\(max(mins, 1)) min"
        if let e = snapshot.error { return "\(e) · \(left)" }
        return "5 h · se reinicia en \(left)"
    }
}

// MARK: - Piezas

struct RingGauge: View {
    var value: Double        // 0…100
    var tint: Color
    var lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle().stroke(tint.opacity(0.22), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(value, 100) / 100))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(lineWidth / 2)
        .animation(.smooth(duration: 0.7), value: value)
        .animation(.smooth(duration: 0.4), value: tint)
    }
}

struct LinearMeter: View {
    var value: Double
    var tint: Color
    var track: Color = Color.white.opacity(0.1)

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule().fill(tint)
                    .frame(width: max(4, g.size.width * min(value, 100) / 100))
            }
        }
        .animation(.smooth(duration: 0.7), value: value)
    }
}

struct PercentLabel: View {
    var value: Double?
    var size: CGFloat
    var tint: Color
    var showSign = true

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0.5) {
            Text(value.map { "\(Int($0.rounded()))" } ?? "–")
                .font(.system(size: size, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(value: value ?? 0))
            if showSign && value != nil {
                Text("%")
                    .font(.system(size: size * 0.72, weight: .semibold, design: .rounded))
                    .opacity(0.6)
            }
        }
        .foregroundStyle(tint)
        .lineLimit(1)
        .fixedSize()
        .animation(.smooth(duration: 0.6), value: value)
    }
}

/// Silueta del notch: orejas cóncavas arriba que se funden con el borde
/// de la pantalla y esquinas redondeadas abajo. Anima sus radios.
struct NotchShape: Shape {
    var earRadius: CGFloat
    var bottomRadius: CGFloat
    /// Nunca se dibuja más pequeña que la isla recogida: al cerrar no "rebota"
    /// por dentro del notch ni deja ver el borde.
    var minSize: CGSize = .zero

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { .init(earRadius, bottomRadius) }
        set { earRadius = newValue.first; bottomRadius = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        let w = max(rect.width, minSize.width), h = max(rect.height, minSize.height)
        let r = CGRect(x: rect.midX - w / 2, y: rect.minY, width: w, height: h)
        let e = earRadius
        let b = min(bottomRadius, (r.height - e) / 2, (r.width - 2 * e) / 2)
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.minX + e, y: r.minY + e), control: CGPoint(x: r.minX + e, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX + e, y: r.maxY - b))
        p.addQuadCurve(to: CGPoint(x: r.minX + e + b, y: r.maxY), control: CGPoint(x: r.minX + e, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX - e - b, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.maxX - e, y: r.maxY - b), control: CGPoint(x: r.maxX - e, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX - e, y: r.minY + e))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY), control: CGPoint(x: r.maxX - e, y: r.minY))
        p.closeSubpath()
        return p
    }
}

private struct BlurFade: ViewModifier {
    let radius: CGFloat
    let opacity: Double
    let scale: CGFloat
    func body(content: Content) -> some View {
        content.blur(radius: radius).opacity(opacity).scaleEffect(scale, anchor: .top)
    }
}

/// Como BlurFade pero sin desenfoque: el desenfoque de toda la vista en cada
/// fotograma era lo que hacía ir a tirones la apertura con el Mac ocupado.
private struct RiseFade: ViewModifier {
    let opacity: Double
    let y: CGFloat
    func body(content: Content) -> some View {
        content.opacity(opacity).offset(y: y)
    }
}

extension AnyTransition {
    static var riseFade: AnyTransition {
        .modifier(active: RiseFade(opacity: 0, y: -6), identity: RiseFade(opacity: 1, y: 0))
            .animation(.easeOut(duration: 0.22).delay(0.06))
    }

    static var blurFade: AnyTransition {
        .modifier(active: BlurFade(radius: 6, opacity: 0, scale: 0.96),
                  identity: BlurFade(radius: 0, opacity: 1, scale: 1))
    }
}
