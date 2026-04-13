import Glibc

// MARK: - Server start time (for uptime tracking)

let SERVER_START_TIME = currentTimestamp()

// MARK: - Seed PRNG

srandom(UInt32(time(nil)))

// MARK: - CLI argument parsing

var port    = 8080
var dataDir = "./data"

var i = 1
while i < CommandLine.arguments.count {
    switch CommandLine.arguments[i] {
    case "--port":
        i += 1
        if i < CommandLine.arguments.count, let p = Int(CommandLine.arguments[i]) { port = p }
    case "--data-dir":
        i += 1
        if i < CommandLine.arguments.count { dataDir = CommandLine.arguments[i] }
    default:
        break
    }
    i += 1
}

// MARK: - Bootstrap

logger.info("Starting SmartPocket \(APP_VERSION)")
logger.info("Data directory: \(dataDir)")

let storage = Storage(dataDir: dataDir)
storage.load()

let router = Router()
let server = HTTPServer(port: port)
server.router = router

// Register all routes (pass server ref + start time for /health)
registerRoutes(router: router, storage: storage, server: server, startTime: SERVER_START_TIME)

// MARK: - Signal handlers (graceful shutdown)

// Global server reference accessible from C-compatible signal handlers
var g_server: UnsafeMutableRawPointer? = Unmanaged.passUnretained(server).toOpaque()

func handleShutdown(_ sig: Int32) {
    let msg: StaticString = "\n[SmartPocket] Shutting down gracefully...\n"
    msg.withUTF8Buffer { buf in
        _ = Glibc.write(STDOUT_FILENO, buf.baseAddress, buf.count)
    }
    if let ptr = g_server {
        let srv = Unmanaged<HTTPServer>.fromOpaque(ptr).takeUnretainedValue()
        srv.shutdown()
    }
    Glibc.exit(0)
}

signal(SIGTERM, handleShutdown)
signal(SIGINT,  handleShutdown)
signal(SIGPIPE, SIG_IGN)   // ignore broken pipe (client disconnect mid-send)

// MARK: - Run

do {
    try server.run()
    logger.info("Server stopped.")
} catch let e as AppError {
    logger.error(e.message)
    exit(1)
} catch {
    logger.error("\(error)")
    exit(1)
}
