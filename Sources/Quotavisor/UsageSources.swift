import Foundation

enum Provider: String, CaseIterable, Identifiable {
    case claude, codex
    var id: String { rawValue }
    var name: String { self == .claude ? "Claude Code" : "Codex" }
}

struct LimitWindow: Equatable {
    var percent: Double
    var resetsAt: Date?

    /// Si la ventana ya se reinició desde la última lectura, el uso real es 0.
    func percent(at now: Date) -> Double {
        if let r = resetsAt, r < now { return 0 }
        return min(max(percent, 0), 100)
    }
}

struct UsageSnapshot: Equatable {
    var session: LimitWindow?   // ventana de 5 h
    var weekly: LimitWindow?    // ventana semanal
    var lastActive: Date?
    var updatedAt: Date = .now
    var error: String?

    var hasData: Bool { session != nil || weekly != nil }
}

private let home = FileManager.default.homeDirectoryForCurrentUser

private func modificationDate(_ url: URL) -> Date? {
    (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
}

// MARK: - Claude Code

/// Lee el % de los límites desde el endpoint de uso de Anthropic usando la sesión
/// OAuth que Claude Code guarda en el Llavero. Nunca refresca ni modifica el token.
actor ClaudeSource {
    private var token: String?
    private var tokenExpiry: Date = .distantPast
    private let http = URLSession(configuration: .ephemeral)
    private let defaults = UserDefaults.standard

    /// Anthropic limita este endpoint: como mucho una consulta cada 3 min,
    /// y tras un 429 se espera lo que pida (Retry-After) o con espera creciente.
    private let minInterval: TimeInterval = 180
    private var backoff: TimeInterval = 300

    private var nextAllowed: Date {
        get { defaults.object(forKey: "claude.nextAllowed") as? Date ?? .distantPast }
        set { defaults.set(newValue, forKey: "claude.nextAllowed") }
    }

    /// Última lectura buena, guardada para no perderla entre reinicios.
    private var cached: UsageSnapshot? {
        get {
            guard let d = defaults.dictionary(forKey: "claude.cache") else { return nil }
            func w(_ k: String) -> LimitWindow? {
                guard let p = d[k + ".p"] as? Double else { return nil }
                return LimitWindow(percent: p, resetsAt: d[k + ".r"] as? Date)
            }
            var s = UsageSnapshot()
            s.session = w("s"); s.weekly = w("w")
            s.updatedAt = d["t"] as? Date ?? .distantPast
            return s.hasData ? s : nil
        }
        set {
            guard let n = newValue else { defaults.removeObject(forKey: "claude.cache"); return }
            var d: [String: Any] = ["t": n.updatedAt]
            if let x = n.session { d["s.p"] = x.percent; d["s.r"] = x.resetsAt }
            if let x = n.weekly { d["w.p"] = x.percent; d["w.r"] = x.resetsAt }
            defaults.set(d, forKey: "claude.cache")
        }
    }

    func fetch() async -> UsageSnapshot {
        let lastActive = modificationDate(home.appending(path: ".claude/history.jsonl"))

        // Demasiado pronto para volver a preguntar: devuelve lo último bueno.
        if Date.now < nextAllowed {
            var s = cached ?? UsageSnapshot()
            s.lastActive = lastActive
            if !s.hasData || defaults.bool(forKey: "claude.limited") {
                let mins = max(1, Int(nextAllowed.timeIntervalSinceNow / 60) + 1)
                s.error = L("Anthropic limita las consultas · reintento en %@ min", "\(mins)")
            }
            return s
        }

        var snap = await request()
        // Sesión caducada: Claude Code la renueva al arrancar. Lo lanzamos en
        // segundo plano (una petición mínima con Haiku) y reintentamos.
        if snap.error?.hasPrefix(L("Sesión caducada")) == true, await autoRenew() {
            token = nil
            nextAllowed = .distantPast
            snap = await request()
        }
        snap.lastActive = lastActive
        return snap
    }

    private var lastRenew: Date {
        get { defaults.object(forKey: "claude.lastRenew") as? Date ?? .distantPast }
        set { defaults.set(newValue, forKey: "claude.lastRenew") }
    }

    /// Ejecuta `claude -p` con Haiku para que Claude Code renueve su sesión
    /// en el Llavero. Como mucho una vez cada 20 min. Devuelve true si terminó bien.
    private func autoRenew() async -> Bool {
        guard Date.now.timeIntervalSince(lastRenew) > 20 * 60 else { return false }
        lastRenew = .now
        return await Task.detached(priority: .utility) { () -> Bool in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/bin/zsh")
            p.arguments = ["-lc", "claude -p 'Responde solo: ok' --model haiku"]
            p.currentDirectoryURL = FileManager.default.temporaryDirectory
            p.standardOutput = FileHandle.nullDevice
            p.standardError = FileHandle.nullDevice
            do { try p.run() } catch { return false }
            let deadline = Date.now.addingTimeInterval(90)
            while p.isRunning && Date.now < deadline { try? await Task.sleep(for: .milliseconds(300)) }
            if p.isRunning { p.terminate(); return false }
            return p.terminationStatus == 0
        }.value
    }

    private func request() async -> UsageSnapshot {
        var snap = UsageSnapshot()

        guard let tok = loadToken() else {
            snap.error = L("Inicia sesión en Claude Code")
            return snap
        }

        var req = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        req.timeoutInterval = 15
        req.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
        req.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, resp) = try await http.data(for: req)
            let http = resp as? HTTPURLResponse
            let code = http?.statusCode ?? 0
            if code != 200 { Self.log(code: code, http: http, data: data) }
            if code == 429 {
                let wait = (http?.value(forHTTPHeaderField: "Retry-After")).flatMap(TimeInterval.init) ?? backoff
                backoff = min(backoff * 2, 1800)
                nextAllowed = .now.addingTimeInterval(max(wait, minInterval))
                defaults.set(true, forKey: "claude.limited")
                var s = cached ?? snap
                let mins = max(1, Int(max(wait, minInterval) / 60))
                s.error = L("Anthropic limita las consultas · reintento en %@ min", "\(mins)")
                return s
            }
            if code == 401 || code == 403 {
                token = nil
                defaults.set(false, forKey: "claude.limited")
                nextAllowed = .now.addingTimeInterval(60)
                var s = cached ?? snap
                s.error = L("Sesión caducada · pulsa para renovar")
                return s
            }
            guard code == 200,
                  let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
                snap.error = L("Error %@ al consultar uso", "\(code)")
                return snap
            }
            snap.session = window(obj["five_hour"])
            snap.weekly = window(obj["seven_day"])
            backoff = 300
            nextAllowed = .now.addingTimeInterval(minInterval)
            defaults.set(false, forKey: "claude.limited")
            if snap.hasData { cached = snap }
        } catch {
            snap.error = L("Sin conexión")
        }
        return snap
    }

    /// Diagnóstico: registra respuestas no-200 (sin credenciales) en ~/Library/Logs/Quotavisor.log
    private static func log(code: Int, http: HTTPURLResponse?, data: Data) {
        let url = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Logs/Quotavisor.log")
        let headers = ["Retry-After", "anthropic-ratelimit-unified-reset", "x-should-retry", "request-id"]
            .compactMap { h in http?.value(forHTTPHeaderField: h).map { "\(h)=\($0)" } }
            .joined(separator: " ")
        let body = String(data: data.prefix(400), encoding: .utf8) ?? ""
        let line = "\(ISO8601DateFormatter().string(from: .now)) claude \(code) \(headers) \(body)\n"
        if let h = try? FileHandle(forWritingTo: url) {
            h.seekToEndOfFile(); h.write(Data(line.utf8)); try? h.close()
        } else {
            try? Data(line.utf8).write(to: url)
        }
    }

    private func window(_ any: Any?) -> LimitWindow? {
        guard let d = any as? [String: Any],
              let u = (d["utilization"] as? NSNumber)?.doubleValue else { return nil }
        return LimitWindow(percent: u, resetsAt: parseISO(d["resets_at"] as? String))
    }

    private func loadToken() -> String? {
        if let token, tokenExpiry > .now.addingTimeInterval(60) { return token }
        guard let raw = keychainCredentials() ?? fileCredentials(),
              let obj = try? JSONSerialization.jsonObject(with: raw) as? [String: Any],
              let oauth = obj["claudeAiOauth"] as? [String: Any],
              let access = oauth["accessToken"] as? String
        else { return nil }
        token = access
        if let ms = (oauth["expiresAt"] as? NSNumber)?.doubleValue {
            tokenExpiry = Date(timeIntervalSince1970: ms / 1000)
        } else {
            tokenExpiry = .now.addingTimeInterval(3600)
        }
        return access
    }

    /// Usa /usr/bin/security (el mismo binario con el que Claude Code escribe la entrada),
    /// así macOS normalmente no vuelve a pedir permiso.
    private func keychainCredentials() -> Data? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        p.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]
        let out = Pipe()
        p.standardOutput = out
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return nil }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return p.terminationStatus == 0 && !data.isEmpty ? data : nil
    }

    private func fileCredentials() -> Data? {
        try? Data(contentsOf: home.appending(path: ".claude/.credentials.json"))
    }
}

private func parseISO(_ s: String?) -> Date? {
    guard let s else { return nil }
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = f.date(from: s) { return d }
    f.formatOptions = [.withInternetDateTime]
    return f.date(from: s)
}

// MARK: - Codex

/// Codex escribe los límites (`rate_limits`) en sus logs de sesión locales.
/// Solo se lee la cola del archivo más reciente: sin red, casi sin coste.
struct CodexSource {
    func fetch() -> UsageSnapshot {
        var snap = UsageSnapshot()
        let files = recentSessionFiles()
        snap.lastActive = files.first?.1

        for (url, mtime) in files.prefix(6) {
            guard let rl = lastRateLimits(in: url) else { continue }
            for key in ["primary", "secondary"] {
                guard let d = rl[key] as? [String: Any],
                      let used = (d["used_percent"] as? NSNumber)?.doubleValue else { continue }
                var reset: Date?
                if let at = (d["resets_at"] as? NSNumber)?.doubleValue {
                    reset = Date(timeIntervalSince1970: at)
                } else if let secs = (d["resets_in_seconds"] as? NSNumber)?.doubleValue {
                    reset = mtime.addingTimeInterval(secs)
                }
                let w = LimitWindow(percent: used, resetsAt: reset)
                let minutes = (d["window_minutes"] as? NSNumber)?.intValue ?? (key == "primary" ? 300 : 10080)
                if minutes <= 24 * 60 { snap.session = w } else { snap.weekly = w }
            }
            if snap.hasData { snap.updatedAt = .now; return snap }
        }
        snap.error = files.isEmpty ? L("Sin sesiones de Codex") : L("Sin datos de límites aún")
        return snap
    }

    private func recentSessionFiles() -> [(URL, Date)] {
        let root = home.appending(path: ".codex/sessions")
        let fm = FileManager.default
        let cal = Calendar.current
        var out: [(URL, Date)] = []
        for back in 0..<10 {
            guard let day = cal.date(byAdding: .day, value: -back, to: .now) else { continue }
            let c = cal.dateComponents([.year, .month, .day], from: day)
            let dir = root.appending(path: String(format: "%04d/%02d/%02d", c.year!, c.month!, c.day!))
            guard let items = try? fm.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: [.contentModificationDateKey]) else { continue }
            for f in items where f.pathExtension == "jsonl" {
                if let m = modificationDate(f) { out.append((f, m)) }
            }
            if out.count >= 6 { break }
        }
        return out.sorted { $0.1 > $1.1 }
    }

    private func lastRateLimits(in url: URL) -> [String: Any]? {
        guard let fh = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? fh.close() }
        let size = (try? fh.seekToEnd()) ?? 0
        let chunk: UInt64 = 512 * 1024
        try? fh.seek(toOffset: size > chunk ? size - chunk : 0)
        guard let data = try? fh.readToEnd(), let text = String(data: data, encoding: .utf8) else { return nil }

        for line in text.split(separator: "\n").reversed() where line.contains("\"rate_limits\"") {
            guard let obj = try? JSONSerialization.jsonObject(with: Data(line.utf8)),
                  let rl = find("rate_limits", in: obj) as? [String: Any],
                  rl["primary"] is [String: Any] || rl["secondary"] is [String: Any]
            else { continue }
            return rl
        }
        return nil
    }

    private func find(_ key: String, in any: Any) -> Any? {
        if let d = any as? [String: Any] {
            if let v = d[key], !(v is NSNull) { return v }
            for v in d.values { if let r = find(key, in: v) { return r } }
        } else if let a = any as? [Any] {
            for v in a { if let r = find(key, in: v) { return r } }
        }
        return nil
    }
}
