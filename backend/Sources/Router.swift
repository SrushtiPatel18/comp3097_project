import Glibc

// MARK: - Route handler type

typealias Handler = (HTTPRequest, [String: String]) throws -> HTTPResponse

// MARK: - Internal route

private struct Route {
    let method:  HTTPRequest.Method
    let pattern: [String]   // segments, e.g. ["transactions", ":id"]
    let handler: Handler
}

// MARK: - Router

final class Router {
    private var routes: [Route] = []

    func add(_ method: HTTPRequest.Method, _ path: String, handler: @escaping Handler) {
        let segments = normalizePath(path).split(separator: "/").map(String.init)
        routes.append(Route(method: method, pattern: segments, handler: handler))
    }

    func get(_ path: String,    handler: @escaping Handler) { add(.GET,    path, handler: handler) }
    func post(_ path: String,   handler: @escaping Handler) { add(.POST,   path, handler: handler) }
    func put(_ path: String,    handler: @escaping Handler) { add(.PUT,    path, handler: handler) }
    func delete(_ path: String, handler: @escaping Handler) { add(.DELETE, path, handler: handler) }
    func patch(_ path: String,  handler: @escaping Handler) { add(.PATCH,  path, handler: handler) }

    func handle(_ req: HTTPRequest) -> HTTPResponse {
        let segments = normalizePath(req.path).split(separator: "/").map(String.init)

        // Try matching route
        for route in routes {
            guard route.method == req.method else { continue }
            guard let params = match(pattern: route.pattern, segments: segments) else { continue }
            do {
                return try route.handler(req, params)
            } catch let e as AppError {
                return HTTPResponse.error(e)
            } catch {
                logger.error("Unhandled error in handler: \(error)")
                return HTTPResponse.internalError()
            }
        }

        // Check if path matches any route with a different method → 405
        for route in routes {
            if match(pattern: route.pattern, segments: segments) != nil {
                return HTTPResponse(
                    status: 405,
                    headers: [("Content-Type", "application/json"),
                              ("Allow", allowedMethods(for: segments))],
                    body: "{\"error\":\"METHOD_NOT_ALLOWED\",\"message\":\"Method not allowed\"}"
                )
            }
        }

        return HTTPResponse.notFound("Route not found: \(req.method.rawValue) \(req.path)")
    }

    // MARK: Private

    private func normalizePath(_ path: String) -> String {
        // Strip trailing slash (except root)
        var p = path
        while p.count > 1 && p.last == "/" { p.removeLast() }
        return p
    }

    private func match(pattern: [String], segments: [String]) -> [String: String]? {
        guard pattern.count == segments.count else { return nil }
        var params: [String: String] = [:]
        for (p, s) in zip(pattern, segments) {
            if p.hasPrefix(":") { params[String(p.dropFirst())] = s }
            else if p != s      { return nil }
        }
        return params
    }

    private func allowedMethods(for segments: [String]) -> String {
        var methods: [String] = []
        for route in routes {
            if match(pattern: route.pattern, segments: segments) != nil {
                methods.append(route.method.rawValue)
            }
        }
        if !methods.contains("OPTIONS") { methods.append("OPTIONS") }
        return methods.joined(separator: ", ")
    }
}

// MARK: - Error helpers

extension Error {
    var localizedDescription: String { "\(self)" }
}
