import Glibc

// MARK: - Log levels

enum LogLevel: Int {
    case debug = 0, info = 1, warn = 2, error = 3

    var label: String {
        switch self {
        case .debug: return "DEBUG"
        case .info:  return "INFO "
        case .warn:  return "WARN "
        case .error: return "ERROR"
        }
    }
}

// MARK: - Logger

final class Logger {
    private var mutex = pthread_mutex_t()

    init() {
        pthread_mutex_init(&mutex, nil)
    }

    deinit {
        pthread_mutex_destroy(&mutex)
    }

    func log(_ level: LogLevel, _ message: String) {
        let line = "[\(logTimestamp())] [\(level.label)] \(message)\n"
        pthread_mutex_lock(&mutex)
        defer { pthread_mutex_unlock(&mutex) }
        if level == .error {
            fputs(line, stderr)
        } else {
            fputs(line, stdout)
            fflush(stdout)
        }
    }

    func debug(_ msg: String) { log(.debug, msg) }
    func info(_ msg: String)  { log(.info,  msg) }
    func warn(_ msg: String)  { log(.warn,  msg) }
    func error(_ msg: String) { log(.error, msg) }

    func access(method: String, path: String, status: Int, ms: Int) {
        let statusLabel: String
        switch status {
        case 200...299: statusLabel = "\(status)"
        case 300...399: statusLabel = "\(status)"
        case 400...499: statusLabel = "\(status)"
        default:        statusLabel = "\(status)"
        }
        let line = "[\(logTimestamp())] \(method) \(path) → \(statusLabel) (\(ms)ms)\n"
        pthread_mutex_lock(&mutex)
        defer { pthread_mutex_unlock(&mutex) }
        fputs(line, stdout)
        fflush(stdout)
    }
}

// MARK: - Timestamp helper (no Foundation)

func logTimestamp() -> String {
    var t = time(nil)
    var tm_val = tm()
    localtime_r(&t, &tm_val)
    let y  = Int(tm_val.tm_year) + 1900
    let mo = Int(tm_val.tm_mon)  + 1
    let d  = Int(tm_val.tm_mday)
    let h  = Int(tm_val.tm_hour)
    let mi = Int(tm_val.tm_min)
    let s  = Int(tm_val.tm_sec)
    func pad(_ n: Int) -> String { n < 10 ? "0\(n)" : "\(n)" }
    return "\(y)-\(pad(mo))-\(pad(d)) \(pad(h)):\(pad(mi)):\(pad(s))"
}

// MARK: - Global singleton

let logger = Logger()
