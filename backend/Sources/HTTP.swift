import Glibc

// MARK: - HTTP Request

struct HTTPRequest {
    enum Method: String {
        case GET, POST, PUT, DELETE, OPTIONS, PATCH
        init?(_ s: String) { self.init(rawValue: s.uppercased()) }
    }

    let method:  Method
    let path:    String
    let query:   String
    let headers: [String: String]
    let body:    String

    var queryParams: [String: String] {
        guard !query.isEmpty else { return [:] }
        var result: [String: String] = [:]
        for part in query.split(separator: "&") {
            let kv = part.split(separator: "=", maxSplits: 1)
            if kv.count == 2 {
                result[urlDecode(String(kv[0]))] = urlDecode(String(kv[1]))
            }
        }
        return result
    }
}

// MARK: - HTTP Response

struct HTTPResponse {
    let status:  Int
    let headers: [(String, String)]
    let body:    String

    static func ok(_ body: String, contentType: String = "application/json") -> HTTPResponse {
        HTTPResponse(status: 200, headers: [("Content-Type", contentType)], body: body)
    }
    static func created(_ body: String) -> HTTPResponse {
        HTTPResponse(status: 201, headers: [("Content-Type", "application/json")], body: body)
    }
    static func noContent() -> HTTPResponse {
        HTTPResponse(status: 204, headers: [], body: "")
    }
    static func error(_ err: AppError) -> HTTPResponse {
        HTTPResponse(status: err.statusCode, headers: [("Content-Type", "application/json")], body: err.errorJSON)
    }
    static func badRequest(_ msg: String)   -> HTTPResponse { error(.badRequest(msg))   }
    static func notFound(_ msg: String)     -> HTTPResponse { error(.notFound(msg))     }
    static func internalError(_ msg: String = "Internal server error") -> HTTPResponse {
        error(.internalError(msg))
    }
    static func serviceUnavailable() -> HTTPResponse {
        HTTPResponse(status: 503, headers: [
            ("Content-Type",  "application/json"),
            ("Retry-After",   "5"),
        ], body: "{\"error\":\"SERVICE_UNAVAILABLE\",\"message\":\"Server at capacity, please retry in a moment\"}")
    }

    func formatted() -> String {
        let text: String
        switch status {
        case 200: text = "OK"
        case 201: text = "Created"
        case 204: text = "No Content"
        case 400: text = "Bad Request"
        case 404: text = "Not Found"
        case 405: text = "Method Not Allowed"
        case 409: text = "Conflict"
        case 422: text = "Unprocessable Entity"
        case 503: text = "Service Unavailable"
        case 500: text = "Internal Server Error"
        default:  text = "Unknown"
        }
        var raw = "HTTP/1.1 \(status) \(text)\r\n"
        raw += "Content-Length: \(body.utf8.count)\r\n"
        raw += "Access-Control-Allow-Origin: *\r\n"
        raw += "Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS, PATCH\r\n"
        raw += "Access-Control-Allow-Headers: Content-Type, Authorization\r\n"
        raw += "Cache-Control: no-store\r\n"
        raw += "X-Content-Type-Options: nosniff\r\n"
        raw += "Connection: close\r\n"
        for (k, v) in headers { raw += "\(k): \(v)\r\n" }
        raw += "\r\n"
        raw += body
        return raw
    }
}

// MARK: - URL decode

func urlDecode(_ s: String) -> String {
    var result = ""
    var i = s.startIndex
    while i < s.endIndex {
        let c = s[i]
        if c == "%" {
            let i1 = s.index(i, offsetBy: 1, limitedBy: s.endIndex) ?? s.endIndex
            let i2 = s.index(i, offsetBy: 2, limitedBy: s.endIndex) ?? s.endIndex
            let i3 = s.index(i, offsetBy: 3, limitedBy: s.endIndex) ?? s.endIndex
            if i1 < s.endIndex && i2 < s.endIndex {
                let hex = String(s[i1...i2])
                if let code = UInt32(hex, radix: 16), let scalar = Unicode.Scalar(code) {
                    result.append(Character(scalar)); i = i3; continue
                }
            }
        } else if c == "+" {
            result.append(" "); i = s.index(after: i); continue
        }
        result.append(c); i = s.index(after: i)
    }
    return result
}

// MARK: - HTTP Parser

func parseHTTPRequest(from raw: String) -> HTTPRequest? {
    let lines = raw.components(separatedBy: "\r\n")
    guard !lines.isEmpty else { return nil }
    let rl = lines[0].split(separator: " ", maxSplits: 2)
    guard rl.count >= 2, let method = HTTPRequest.Method(String(rl[0])) else { return nil }

    let rawPath   = String(rl[1])
    let pp        = rawPath.split(separator: "?", maxSplits: 1)
    let path      = String(pp[0])
    let query     = pp.count > 1 ? String(pp[1]) : ""

    var headers: [String: String] = [:]
    var bodyStart = lines.count
    for i in 1..<lines.count {
        if lines[i].isEmpty { bodyStart = i + 1; break }
        let kv = lines[i].split(separator: ":", maxSplits: 1)
        if kv.count == 2 {
            headers[String(kv[0]).lowercased().trimmingCharacters(in: [" "])] =
                String(kv[1]).trimmingCharacters(in: [" "])
        }
    }
    let body = bodyStart < lines.count ? lines[bodyStart...].joined(separator: "\r\n") : ""
    return HTTPRequest(method: method, path: path, query: query, headers: headers, body: body)
}

// MARK: - Thread context for per-connection pthreads

final class _ConnectionJob {
    let fd:     Int32
    let server: HTTPServer
    init(fd: Int32, server: HTTPServer) { self.fd = fd; self.server = server }
}

// Top-level, non-capturing C-compatible function — required for pthread_create
func _connectionEntry(_ raw: UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer? {
    guard let raw = raw else { return nil }
    let job = Unmanaged<_ConnectionJob>.fromOpaque(raw).takeRetainedValue()
    job.server.handleConnection(fd: job.fd)
    return nil
}

// MARK: - HTTP Server

final class HTTPServer {
    let port:   Int
    var router: Router?

    // Concurrent-connection throttle (mutex-protected)
    private var activeConns = 0
    private let maxConns    = 200
    private var connMutex   = pthread_mutex_t()

    // Request telemetry
    private var totalRequests = 0
    private var reqMutex      = pthread_mutex_t()

    // Server socket (exposed for graceful shutdown)
    private(set) var serverFd: Int32 = -1

    init(port: Int) {
        self.port = port
        pthread_mutex_init(&connMutex, nil)
        pthread_mutex_init(&reqMutex,  nil)
    }

    deinit {
        pthread_mutex_destroy(&connMutex)
        pthread_mutex_destroy(&reqMutex)
    }

    // MARK: Graceful shutdown

    func shutdown() {
        guard serverFd >= 0 else { return }
        Glibc.shutdown(serverFd, Int32(SHUT_RDWR))
        close(serverFd)
        serverFd = -1
    }

    // MARK: Accept loop

    func run() throws {
        let fd = socket(AF_INET, Int32(SOCK_STREAM.rawValue), 0)
        guard fd >= 0 else { throw AppError.internalError("socket() failed") }
        serverFd = fd

        var opt: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &opt, socklen_t(MemoryLayout<Int32>.size))

        var addr        = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port   = in_port_t(UInt16(port).bigEndian)
        addr.sin_addr   = in_addr(s_addr: INADDR_ANY)
        addr.sin_zero   = (0,0,0,0,0,0,0,0)

        let bound = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bound == 0 else { throw AppError.internalError("bind() failed on port \(port)") }
        guard listen(fd, 512) == 0 else { throw AppError.internalError("listen() failed") }

        logger.info("SmartPocket \(APP_VERSION) ready — port \(port) — max \(maxConns) concurrent connections")

        while true {
            var cAddr = sockaddr_in()
            var cLen  = socklen_t(MemoryLayout<sockaddr_in>.size)
            let cFd   = withUnsafeMutablePointer(to: &cAddr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    accept(fd, $0, &cLen)
                }
            }

            if cFd < 0 {
                if errno == EINTR { continue }
                break   // server socket closed → graceful shutdown
            }

            // Throttle check
            pthread_mutex_lock(&connMutex)
            let canServe = activeConns < maxConns
            if canServe { activeConns += 1 }
            pthread_mutex_unlock(&connMutex)

            if !canServe {
                let r = HTTPResponse.serviceUnavailable().formatted()
                r.withCString { _ = send(cFd, $0, strlen($0), 0) }
                close(cFd)
                logger.warn("Connection rejected — at capacity (\(maxConns) active)")
                continue
            }

            // Spawn detached thread per connection
            let job = _ConnectionJob(fd: cFd, server: self)
            let ptr = Unmanaged.passRetained(job).toOpaque()
            var tid: pthread_t = 0
            pthread_create(&tid, nil, _connectionEntry, ptr)
            pthread_detach(tid)
        }
    }

    // MARK: Per-connection handler (runs on worker thread)

    func handleConnection(fd: Int32) {
        defer {
            close(fd)
            pthread_mutex_lock(&connMutex)
            activeConns -= 1
            pthread_mutex_unlock(&connMutex)
        }

        // Socket timeouts — prevent hung connections
        var tv = timeval(tv_sec: 30, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        // Disable Nagle — send response bytes immediately
        var nodelay: Int32 = 1
        setsockopt(fd, Int32(IPPROTO_TCP), TCP_NODELAY, &nodelay, socklen_t(MemoryLayout<Int32>.size))

        guard let rawStr = readRequestBytes(fd: fd),
              let req    = parseHTTPRequest(from: rawStr)
        else { return }

        // Count requests
        pthread_mutex_lock(&reqMutex)
        totalRequests += 1
        pthread_mutex_unlock(&reqMutex)

        let t0 = microtime()

        // CORS preflight — fast path
        if req.method == .OPTIONS {
            let r = HTTPResponse(status: 204, headers: [], body: "").formatted()
            sendAll(fd: fd, text: r)
            return
        }

        let response = router?.handle(req) ?? HTTPResponse.notFound("Route not found: \(req.method.rawValue) \(req.path)")
        let ms = Int((microtime() - t0) / 1000)

        logger.access(method: req.method.rawValue, path: req.path, status: response.status, ms: ms)

        sendAll(fd: fd, text: response.formatted())
    }

    func getStats() -> (requests: Int, activeConns: Int) {
        pthread_mutex_lock(&reqMutex);  let r = totalRequests;  pthread_mutex_unlock(&reqMutex)
        pthread_mutex_lock(&connMutex); let c = activeConns;    pthread_mutex_unlock(&connMutex)
        return (r, c)
    }

    // MARK: Private

    /// Read a complete HTTP request from the socket (headers + declared body).
    private func readRequestBytes(fd: Int32) -> String? {
        let maxSize = 1 * 1024 * 1024   // 1 MB hard limit
        var scratch = [UInt8](repeating: 0, count: 4096)
        var data    = [UInt8]()
        data.reserveCapacity(4096)

        var headerEndIdx  = -1
        var contentLength =  0

        while data.count < maxSize {
            let n = recv(fd, &scratch, scratch.count, 0)
            if n < 0 { if errno == EINTR { continue } else { return nil } }
            if n == 0 { break }
            data.append(contentsOf: scratch[0..<Int(n)])

            // Locate \r\n\r\n (end of headers)
            if headerEndIdx < 0 && data.count >= 4 {
                let top = data.count - 4
                var i = 0
                while i <= top {
                    if data[i] == 13 && data[i+1] == 10 &&
                       data[i+2] == 13 && data[i+3] == 10 {
                        headerEndIdx  = i + 4
                        contentLength = parseContentLength(from: data, end: headerEndIdx)
                        break
                    }
                    i += 1
                }
            }

            if headerEndIdx >= 0 {
                if data.count - headerEndIdx >= contentLength { break }
            }
        }

        guard !data.isEmpty else { return nil }
        data.append(0)   // null-terminate for String(cString:)
        return String(cString: data)
    }

    private func parseContentLength(from data: [UInt8], end: Int) -> Int {
        let hdr = String(decoding: data[0..<end], as: UTF8.self)
        for line in hdr.components(separatedBy: "\r\n") {
            if line.lowercased().hasPrefix("content-length:") {
                let v = String(line.dropFirst(15)).trimmingCharacters(in: [" ", "\t"])
                return Int(v) ?? 0
            }
        }
        return 0
    }

    private func sendAll(fd: Int32, text: String) {
        text.withCString { ptr in
            var remaining = strlen(ptr)
            var offset    = 0
            while remaining > 0 {
                let sent = Glibc.send(fd, ptr + offset, remaining, Int32(MSG_NOSIGNAL))
                if sent <= 0 { break }
                offset    += sent
                remaining -= sent
            }
        }
    }
}

// MARK: - Monotonic microsecond timer

func microtime() -> UInt64 {
    var ts = timespec()
    clock_gettime(CLOCK_MONOTONIC, &ts)
    return UInt64(ts.tv_sec) * 1_000_000 + UInt64(ts.tv_nsec) / 1_000
}

// MARK: - String helpers (no Foundation)

extension String {
    func components(separatedBy separator: String) -> [String] {
        var parts: [String] = []
        var current = ""
        var idx = startIndex
        while idx < endIndex {
            var matched = true
            var si = separator.startIndex
            var ti = idx
            while si < separator.endIndex {
                if ti >= endIndex || self[ti] != separator[si] { matched = false; break }
                ti = index(after: ti)
                si = separator.index(after: si)
            }
            if matched {
                parts.append(current); current = ""; idx = ti
            } else {
                current.append(self[idx]); idx = index(after: idx)
            }
        }
        parts.append(current)
        return parts
    }

    func trimmingCharacters(in set: [Character]) -> String {
        var s = self
        while let f = s.first, set.contains(f) { s.removeFirst() }
        while let l = s.last,  set.contains(l) { s.removeLast()  }
        return s
    }
}
