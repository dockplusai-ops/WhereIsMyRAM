import Foundation
import Darwin

/// Lê métricas do sistema (CPU, memória e disco) via APIs do kernel Mach.
enum Metrics {

    // MARK: - CPU

    /// Mantém o snapshot anterior de ticks da CPU para calcular o uso no intervalo.
    private static var previousCPUTicks: (user: UInt32, system: UInt32, idle: UInt32, nice: UInt32)?

    /// Uso de CPU em porcentagem (0–100) desde a última chamada.
    static func cpuUsage() -> Double {
        var cpuLoad = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride)

        let result = withUnsafeMutablePointer(to: &cpuLoad) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return 0 }

        let user = cpuLoad.cpu_ticks.0
        let system = cpuLoad.cpu_ticks.1
        let idle = cpuLoad.cpu_ticks.2
        let nice = cpuLoad.cpu_ticks.3

        defer { previousCPUTicks = (user, system, idle, nice) }

        guard let prev = previousCPUTicks else { return 0 }

        let userDiff = Double(user &- prev.user)
        let systemDiff = Double(system &- prev.system)
        let idleDiff = Double(idle &- prev.idle)
        let niceDiff = Double(nice &- prev.nice)

        let totalDiff = userDiff + systemDiff + idleDiff + niceDiff
        guard totalDiff > 0 else { return 0 }

        let usage = (userDiff + systemDiff + niceDiff) / totalDiff * 100
        return usage
    }

    // MARK: - Memória

    /// Memória em uso (em bytes) e total físico.
    static func memory() -> (used: UInt64, total: UInt64) {
        let total = ProcessInfo.processInfo.physicalMemory

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)

        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return (0, total) }

        let pageSize = UInt64(vm_kernel_page_size)
        // Aproxima o "Memória usada" do Monitor de Atividade: ativa + wired + comprimida.
        let active = UInt64(stats.active_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize

        let used = active + wired + compressed
        return (used, total)
    }

    // MARK: - Disco

    /// Espaço livre e total do volume raiz (em bytes).
    static func disk() -> (free: UInt64, total: UInt64) {
        let url = URL(fileURLWithPath: "/")
        guard let values = try? url.resourceValues(forKeys: [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeTotalCapacityKey
        ]) else {
            return (0, 0)
        }

        let free = UInt64(values.volumeAvailableCapacityForImportantUsage ?? 0)
        let total = UInt64(values.volumeTotalCapacity ?? 0)
        return (free, total)
    }

    // MARK: - Rede

    /// Total acumulado de bytes recebidos/enviados em todas as interfaces (exceto loopback).
    static func networkBytes() -> (received: UInt64, sent: UInt64) {
        var rx: UInt64 = 0, tx: UInt64 = 0
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0 else { return (0, 0) }
        defer { freeifaddrs(ifaddrPtr) }

        var ptr = ifaddrPtr
        while let cur = ptr {
            let ifa = cur.pointee
            if let addr = ifa.ifa_addr, addr.pointee.sa_family == UInt8(AF_LINK) {
                let name = String(cString: ifa.ifa_name)
                if !name.hasPrefix("lo"), let dataPtr = ifa.ifa_data {
                    let data = dataPtr.assumingMemoryBound(to: if_data.self).pointee
                    rx += UInt64(data.ifi_ibytes)
                    tx += UInt64(data.ifi_obytes)
                }
            }
            ptr = ifa.ifa_next
        }
        return (rx, tx)
    }

    // MARK: - Formatação

    static func formatGB(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_000_000_000
        return String(format: "%.0fGB", gb)
    }

    /// Formata uma taxa em bytes/s (ex.: "1.2 MB/s", "320 KB/s").
    static func formatRate(_ bytesPerSec: Double) -> String {
        if bytesPerSec >= 1_000_000 { return String(format: "%.1f MB/s", bytesPerSec / 1_000_000) }
        if bytesPerSec >= 1_000 { return String(format: "%.0f KB/s", bytesPerSec / 1_000) }
        return String(format: "%.0f B/s", bytesPerSec)
    }

    // MARK: - Top processos por memória

    /// Os `count` apps que mais consomem RAM, agregando helpers (e seus PIDs)
    /// sob o app principal.
    static func topMemoryProcesses(count: Int = 5) -> [(name: String, bytes: UInt64, path: String, pids: [pid_t])] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,rss=,comm=", "-m"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return []
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard let output = String(data: data, encoding: .utf8) else { return [] }

        var totals: [String: UInt64] = [:]
        var pidsByName: [String: [pid_t]] = [:]
        var pathByName: [String: String] = [:]

        for line in output.split(separator: "\n") {
            // Campos: <pid> <rss(KB)> <caminho do executável>
            let t1 = line.drop(while: { $0 == " " })
            guard let s1 = t1.firstIndex(of: " ") else { continue }
            let pid = pid_t(t1[..<s1]) ?? -1

            let t2 = t1[t1.index(after: s1)...].drop(while: { $0 == " " })
            guard let s2 = t2.firstIndex(of: " ") else { continue }
            let rssKB = UInt64(t2[..<s2]) ?? 0

            let path = String(t2[t2.index(after: s2)...]).trimmingCharacters(in: .whitespaces)
            guard pid > 0, rssKB > 0, !path.isEmpty else { continue }

            let name = friendlyName(path)
            totals[name, default: 0] += rssKB * 1024
            pidsByName[name, default: []].append(pid)
            if pathByName[name] == nil { pathByName[name] = bundlePath(path) }
        }

        return totals
            .sorted { $0.value > $1.value }
            .prefix(count)
            .map { (name: $0.key, bytes: $0.value,
                    path: pathByName[$0.key] ?? "", pids: pidsByName[$0.key] ?? []) }
    }

    /// Caminho do bundle .app (para buscar o ícone), ou o próprio executável.
    private static func bundlePath(_ path: String) -> String {
        if let range = path.range(of: ".app/") {
            return String(path[..<range.lowerBound]) + ".app"
        }
        return path
    }

    /// Envia SIGTERM aos processos (encerramento gracioso). Falha silenciosa em
    /// processos de outros donos (ex.: do sistema) — comportamento desejado.
    static func terminate(pids: [pid_t]) {
        for pid in pids where pid > 0 {
            kill(pid, SIGTERM)
        }
    }

    /// Deriva um nome amigável: o app (.app) de mais alto nível, ou o basename.
    private static func friendlyName(_ path: String) -> String {
        if let range = path.range(of: ".app/") {
            let appPath = String(path[..<range.lowerBound]) // até antes de ".app/"
            return (appPath as NSString).lastPathComponent
        }
        if path.hasSuffix(".app") {
            return ((path as NSString).lastPathComponent as NSString).deletingPathExtension
        }
        return (path as NSString).lastPathComponent
    }

    /// Barra de progresso em texto, ex.: ▕███████░░░░▏ para uma fração 0–1.
    static func bar(_ fraction: Double, width: Int = 12) -> String {
        let clamped = min(max(fraction, 0), 1)
        let filled = Int((clamped * Double(width)).rounded())
        let empty = width - filled
        return "▕" + String(repeating: "█", count: filled) + String(repeating: "░", count: empty) + "▏"
    }
}
