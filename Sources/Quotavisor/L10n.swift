import Foundation

/// Idioma de la interfaz: el primero del Mac que sea inglés, español o francés; si no, inglés.
enum AppLanguage: String {
    case en, es, fr

    static let current: AppLanguage = {
        for id in Locale.preferredLanguages {
            if let l = AppLanguage(rawValue: String(id.prefix(2))) { return l }
        }
        return .en
    }()
}

/// Traduce un texto escrito en español (la clave) al idioma de la interfaz.
func L(_ es: String) -> String {
    switch AppLanguage.current {
    case .es: return es
    case .en: return translations[es]?[0] ?? es
    case .fr: return translations[es]?[1] ?? es
    }
}

/// Igual, con huecos `%@` que se rellenan en orden.
func L(_ es: String, _ args: String...) -> String {
    String(format: L(es), arguments: args)
}

private let translations: [String: [String]] = [
    "Ajustes…": ["Settings…", "Réglages…"],
    "Renovar sesión de Claude…": ["Renew Claude session…", "Renouveler la session Claude…"],
    "Actualizar ahora": ["Refresh now", "Actualiser maintenant"],
    "Mostrar en el notch": ["Show in the notch", "Afficher dans l’encoche"],
    "Automático (el último usado)": ["Automatic (last used)", "Automatique (le dernier utilisé)"],
    "Actualizar cada": ["Refresh every", "Actualiser toutes les"],
    "Abrir al iniciar sesión": ["Open at login", "Ouvrir à la connexion"],
    "Salir de Quotavisor": ["Quit Quotavisor", "Quitter Quotavisor"],
    "Anthropic limita las consultas · reintento en %@ min": ["Anthropic is rate-limiting · retrying in %@ min", "Anthropic limite les requêtes · nouvel essai dans %@ min"],
    "Sesión caducada": ["Session expired", "Session expirée"],
    "Inicia sesión en Claude Code": ["Sign in to Claude Code", "Connectez-vous à Claude Code"],
    "Sesión caducada · pulsa para renovar": ["Session expired · click to renew", "Session expirée · cliquez pour renouveler"],
    "Error %@ al consultar uso": ["Error %@ fetching usage", "Erreur %@ en lisant l’usage"],
    "Sin conexión": ["Offline", "Hors ligne"],
    "Sin sesiones de Codex": ["No Codex sessions", "Aucune session Codex"],
    "Sin datos de límites aún": ["No limit data yet", "Pas encore de données de limites"],
    "General": ["General", "Général"],
    "Apariencia": ["Appearance", "Apparence"],
    "Proveedores": ["Providers", "Fournisseurs"],
    "Acerca de": ["About", "À propos"],
    "Qué aparece en el notch y cada cuánto se actualiza.": ["What shows in the notch and how often it refreshes.", "Ce qui s’affiche dans l’encoche et à quelle fréquence."],
    "Colores y umbrales de la isla. Los cambios se ven al momento.": ["Island colors and thresholds. Changes show instantly.", "Couleurs et seuils de l’île. Les changements sont immédiats."],
    "Las cuentas de las que Quotavisor lee tu uso.": ["The accounts Quotavisor reads your usage from.", "Les comptes depuis lesquels Quotavisor lit votre usage."],
    "Tu cuota de IA, en el notch": ["Your AI quota, in the notch", "Votre quota d’IA, dans l’encoche"],
    "En el notch": ["In the notch", "Dans l’encoche"],
    "Automático": ["Automatic", "Automatique"],
    "El último que uses": ["Whichever you used last", "Le dernier utilisé"],
    "Siempre este": ["Always this one", "Toujours celui-ci"],
    "Actualización": ["Refresh", "Actualisation"],
    "Minutos entre lecturas": ["Minutes between reads", "Minutes entre deux lectures"],
    "Última lectura": ["Last read", "Dernière lecture"],
    "Sistema": ["System", "Système"],
    "Quotavisor se abre solo, sin icono en el Dock.": ["Quotavisor opens by itself, with no Dock icon.", "Quotavisor s’ouvre tout seul, sans icône dans le Dock."],
    "Cargando…": ["Loading…", "Chargement…"],
    "Hace un momento": ["Just now", "À l’instant"],
    "Hace %@ min": ["%@ min ago", "Il y a %@ min"],
    "Colores": ["Colors", "Couleurs"],
    "Umbrales": ["Thresholds", "Seuils"],
    "Aviso": ["Warning", "Alerte"],
    "El anillo pasa a ámbar.": ["The ring turns amber.", "L’anneau passe à l’ambre."],
    "Crítico": ["Critical", "Critique"],
    "El anillo pasa a rojo.": ["The ring turns red.", "L’anneau passe au rouge."],
    "Ancho de la isla": ["Island width", "Largeur de l’île"],
    "Más estrecha pisa menos la barra de menús.": ["Narrower covers less of the menu bar.", "Plus étroite, elle empiète moins sur la barre des menus."],
    "Mostrar el símbolo %": ["Show the % sign", "Afficher le symbole %"],
    "Restablecer apariencia": ["Reset appearance", "Réinitialiser l’apparence"],
    "Vuelve a los colores y umbrales originales.": ["Back to the original colors and thresholds.", "Revenir aux couleurs et seuils d’origine."],
    "Restablecer": ["Reset", "Réinitialiser"],
    "Archivo": ["File", "Fichier"],
    "Edición": ["Edit", "Édition"],
    "Simular uso": ["Simulate usage", "Simuler l’usage"],
    "Últimas 5 horas": ["Last 5 hours", "5 dernières heures"],
    "Esta semana": ["This week", "Cette semaine"],
    "Abre Claude Code un momento para renovarla. Tus datos vuelven solos.": ["Open Claude Code for a moment to renew it. Your data comes back on its own.", "Ouvrez Claude Code un instant pour la renouveler. Vos données reviennent toutes seules."],
    "Renovar sesión": ["Renew session", "Renouveler la session"],
    "Fuente": ["Source", "Source"],
    "Tu sesión de Claude Code (Llavero de macOS). Solo lectura.": ["Your Claude Code session (macOS Keychain). Read-only.", "Votre session Claude Code (Trousseau macOS). Lecture seule."],
    "Registros locales de Codex en ~/.codex. Sin conexión.": ["Local Codex logs in ~/.codex. Offline.", "Journaux locaux de Codex dans ~/.codex. Hors ligne."],
    "Se reinicia en %@": ["Resets in %@", "Réinitialisation dans %@"],
    "Conectado": ["Connected", "Connecté"],
    "Sin datos todavía": ["No data yet", "Pas encore de données"],
    "Versión %@": ["Version %@", "Version %@"],
    "Tu cuota de Claude Code y Codex,\nsiempre a la vista en el notch.": ["Your Claude Code and Codex quota,\nalways in sight in the notch.", "Votre quota Claude Code et Codex,\ntoujours sous les yeux dans l’encoche."],
    "Hecho por @humbergarc": ["Made by @humbergarc", "Fait par @humbergarc"],
    "Ajustes": ["Settings", "Réglages"],
    "Al día": ["Up to date", "À jour"],
    "Semana ": ["Week ", "Semaine "],
    "se reinicia en %@": ["resets in %@", "réinit. dans %@"],
    "Ventana de 5 h libre": ["5 h window free", "Fenêtre de 5 h libre"],
    "5 h · se reinicia en %@": ["5 h · resets in %@", "5 h · réinit. dans %@"],
    "Quotavisor: renovando la sesión de Claude Code…": ["Quotavisor: renewing your Claude Code session…", "Quotavisor : renouvellement de la session Claude Code…"],
    "Cuando Claude Code arranque, ya puedes salir con /exit.": ["Once Claude Code starts, you can quit with /exit.", "Une fois Claude Code lancé, vous pouvez quitter avec /exit."],
]
