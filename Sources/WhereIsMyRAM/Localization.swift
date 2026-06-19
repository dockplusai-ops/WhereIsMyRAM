import Foundation

/// Localização simples baseada no idioma preferido do sistema (PT/ES/EN).
enum L {
    /// Idioma ativo: "pt", "es" ou "en" (fallback).
    static let lang: String = {
        let code = String(Locale.preferredLanguages.first?.prefix(2) ?? "en").lowercased()
        return ["pt", "es"].contains(code) ? code : "en"
    }()

    private static let table: [String: [String: String]] = [
        "cpu":         ["en": "CPU",          "pt": "CPU",            "es": "CPU"],
        "memory":      ["en": "Memory",       "pt": "Memória",        "es": "Memoria"],
        "disk":        ["en": "Disk",         "pt": "Disco",          "es": "Disco"],
        "network":     ["en": "Network",      "pt": "Rede",           "es": "Red"],
        "free":        ["en": "free",         "pt": "livres",         "es": "libres"],
        "topMemory":   ["en": "Top memory",   "pt": "Top memória",    "es": "Top memoria"],
        "openAtLogin": ["en": "Open at login", "pt": "Abrir no login", "es": "Abrir al iniciar"],
        "quit":        ["en": "Quit",         "pt": "Sair",           "es": "Salir"],
        "kill":        ["en": "Quit",         "pt": "Encerrar",       "es": "Cerrar"],
        "cancel":      ["en": "Cancel",       "pt": "Cancelar",       "es": "Cancelar"],
        "killTitle":   ["en": "Quit %@?",     "pt": "Encerrar %@?",   "es": "¿Cerrar %@?"],
        "killBody":    ["en": "The processes will be terminated. You may lose unsaved data.",
                        "pt": "Os processos serão encerrados. Você pode perder dados não salvos.",
                        "es": "Se cerrarán los procesos. Podrías perder datos no guardados."],
    ]

    /// Texto localizado para a chave; cai para inglês e depois para a própria chave.
    static func t(_ key: String) -> String {
        table[key]?[lang] ?? table[key]?["en"] ?? key
    }
}
