import Glibc

// Seed random
srandom(UInt32(time(nil)))

// Parse CLI args for port and data-dir
var port    = 8080
var dataDir = "./data"

let args = CommandLine.arguments
var i = 1
while i < args.count {
    switch args[i] {
    case "--port":
        i += 1
        if i < args.count, let p = Int(args[i]) { port = p }
    case "--data-dir":
        i += 1
        if i < args.count { dataDir = args[i] }
    default: break
    }
    i += 1
}

// Boot storage
let storage = Storage(dataDir: dataDir)
storage.load()

// Build router
let router = Router()
registerRoutes(router: router, storage: storage)

// Start server
let server = HTTPServer(port: port)
server.router = router

do {
    try server.run()
} catch let e as AppError {
    fputs("[ERROR] \(e.message)\n", stderr)
    exit(1)
} catch {
    fputs("[ERROR] \(error)\n", stderr)
    exit(1)
}
