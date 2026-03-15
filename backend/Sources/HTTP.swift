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
                let k = urlDecode(String(kv[0]))
                let v = urlDecode(String(kv[1]))
                result[k] = v
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
    static func badRequest(_ msg: String) -> HTTPResponse {
        error(AppError.badRequest(msg))
    }
    static func notFound(_ msg: String) -> HTTPResponse {
        error(AppError.notFound(msg))
    }
    static func internalError(_ msg: String = "Internal server error") -> HTTPResponse {
        error(AppError.internalError(msg))
    }

    func formatted(keepAlive: Bool = false) -> String {
        let statusText: String
        switch status {
        case 200: statusText = "OK"
        case 201: statusText = "Created"
        case 204: statusText = "No Content"
        case 400: statusText = "Bad Request"
        case 404: statusText = "Not Found"
        case 405: statusText = "Method Not Allowed"
        case 409: statusText = "Conflict"
        case 500: statusText = "Internal Server Error"
        default:  statusText = "Unknown"
        }
        var lines = "HTTP/1.1 \(status) \(statusText)\r\n"
        lines += "Content-Length: \(body.utf8.count)\r\n"
        lines += "Access-Control-Allow-Origin: *\r\n"
        lines += "Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS, PATCH\r\n"
        lines += "Access-Control-Allow-Headers: Content-Type, Authorization\r\n"
        lines += "Connection: \(keepAlive ? "keep-alive" : "close")\r\n"
        for (k, v) in headers { lines += "\(k): \(v)\r\n" }
        lines += "\r\n"
        lines += body
        return lines
    }
}

// MARK: - URL helpers

func urlDecode(_ s: String) -> String {
    var result = ""
    var i = s.startIndex
    while i < s.endIndex {
        let c = s[i]
        if c == "%" {
            let next = s.index(i, offsetBy: 1, limitedBy: s.endIndex) ?? s.endIndex
            let next2 = s.index(i, offsetBy: 2, limitedBy: s.endIndex) ?? s.endIndex
            let next3 = s.index(i, offsetBy: 3, limitedBy: s.endIndex) ?? s.endIndex
            if next < s.endIndex && next2 < s.endIndex {
                let hexStr = String(s[next...next2])
                if let code = UInt32(hexStr, radix: 16), let scalar = Unicode.Scalar(code) {
                    result.append(Character(scalar))
                    i = next3
                    continue
                }
            }
        } else if c == "+" {
            result.append(" ")
            i = s.index(after: i)
            continue
        }
        result.append(c)
        i = s.index(after: i)
    }
    return result
}

// MARK: - HTTP Parser

func parseHTTPRequest(from raw: String) -> HTTPRequest? {
    let lines = raw.components(separatedBy: "\r\n")
    guard !lines.isEmpty else { return nil }

    let requestLine = lines[0].split(separator: " ", maxSplits: 2)
    guard requestLine.count >= 2,
          let method = HTTPRequest.Method(String(requestLine[0]))
    else { return nil }

    let rawPath = requestLine.count > 1 ? String(requestLine[1]) : "/"
    let pathParts = rawPath.split(separator: "?", maxSplits: 1)
    let path  = String(pathParts[0])
    let query = pathParts.count > 1 ? String(pathParts[1]) : ""

    var headers: [String: String] = [:]
    var bodyStart = 1
    for i in 1..<lines.count {
        if lines[i].isEmpty { bodyStart = i + 1; break }
        let kv = lines[i].split(separator: ":", maxSplits: 1)
        if kv.count == 2 {
            let k = String(kv[0]).lowercased().trimmingCharacters(in: [" "])
            let v = String(kv[1]).trimmingCharacters(in: [" "])
            headers[k] = v
        }
    }

    let body = bodyStart < lines.count ? lines[bodyStart...].joined(separator: "\r\n") : ""
    return HTTPRequest(method: method, path: path, query: query, headers: headers, body: body)
}

// MARK: - Socket Server

final class HTTPServer {
    let port: Int
    var router: Router?

    init(port: Int) { self.port = port }

    func run() throws {
        let serverFd = socket(AF_INET, Int32(SOCK_STREAM.rawValue), 0)
        guard serverFd >= 0 else { throw AppError.internalError("socket() failed") }

        var optval: Int32 = 1
        setsockopt(serverFd, SOL_SOCKET, SO_REUSEADDR, &optval, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_family      = sa_family_t(AF_INET)
        addr.sin_port        = in_port_t(UInt16(port).bigEndian)
        addr.sin_addr        = in_addr(s_addr: INADDR_ANY)
        addr.sin_zero        = (0,0,0,0,0,0,0,0)

        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(serverFd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else { throw AppError.internalError("bind() failed on port \(port)") }

        guard listen(serverFd, 128) == 0 else { throw AppError.internalError("listen() failed") }
        print("[SmartPocket] Swift backend listening on port \(port)")

        while true {
            var clientAddr  = sockaddr_in()
            var clientLen   = socklen_t(MemoryLayout<sockaddr_in>.size)
            let clientFd    = withUnsafeMutablePointer(to: &clientAddr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    accept(serverFd, $0, &clientLen)
                }
            }
            guard clientFd >= 0 else { continue }
            handleConnection(fd: clientFd)
        }
    }

    private func handleConnection(fd: Int32) {
        defer { close(fd) }
        var buf = [CChar](repeating: 0, count: 65536)
        let n   = recv(fd, &buf, buf.count - 1, 0)
        guard n > 0 else { return }

        let raw = String(cString: buf)
        guard let req = parseHTTPRequest(from: raw) else {
            let resp = HTTPResponse(status: 400, headers: [], body: "Bad Request").formatted()
            _ = resp.withCString { send(fd, $0, strlen($0), 0) }
            return
        }

        // CORS preflight
        if req.method == .OPTIONS {
            let resp = HTTPResponse(status: 204, headers: [], body: "").formatted()
            _ = resp.withCString { send(fd, $0, strlen($0), 0) }
            return
        }

        let response = router?.handle(req) ?? HTTPResponse.notFound("Route not found")
        let formatted = response.formatted()
        formatted.withCString { ptr in
            var remaining = strlen(ptr)
            var offset    = 0
            while remaining > 0 {
                let sent = Glibc.send(fd, ptr + offset, remaining, 0)
                if sent <= 0 { break }
                offset    += sent
                remaining -= sent
            }
        }
    }
}

// MARK: - String helpers

extension String {
    func components(separatedBy separator: String) -> [String] {
        var parts: [String] = []
        var current = ""
        var idx = startIndex
        while idx < endIndex {
            var matched = true
            var sepIdx  = separator.startIndex
            var tmpIdx  = idx
            while sepIdx < separator.endIndex {
                if tmpIdx >= endIndex || self[tmpIdx] != separator[sepIdx] { matched = false; break }
                tmpIdx  = index(after: tmpIdx)
                sepIdx  = separator.index(after: sepIdx)
            }
            if matched {
                parts.append(current)
                current = ""
                idx     = tmpIdx
            } else {
                current.append(self[idx])
                idx = index(after: idx)
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
