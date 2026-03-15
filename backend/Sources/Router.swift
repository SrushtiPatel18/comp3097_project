import Glibc

// MARK: - Route handler type

typealias Handler = (HTTPRequest, [String: String]) throws -> HTTPResponse

// MARK: - Route

private struct Route {
    let method:   HTTPRequest.Method
    let pattern:  [String]   // path segments, e.g. ["transactions", ":id"]
    let handler:  Handler
}

// MARK: - Router

final class Router {
    private var routes: [Route] = []

    func add(_ method: HTTPRequest.Method, _ path: String, handler: @escaping Handler) {
        let segments = path.split(separator: "/").map(String.init)
        routes.append(Route(method: method, pattern: segments, handler: handler))
    }

    func get(_ path: String,    handler: @escaping Handler) { add(.GET,    path, handler: handler) }
    func post(_ path: String,   handler: @escaping Handler) { add(.POST,   path, handler: handler) }
    func put(_ path: String,    handler: @escaping Handler) { add(.PUT,    path, handler: handler) }
    func delete(_ path: String, handler: @escaping Handler) { add(.DELETE, path, handler: handler) }
    func patch(_ path: String,  handler: @escaping Handler) { add(.PATCH,  path, handler: handler) }

    func handle(_ req: HTTPRequest) -> HTTPResponse {
        let segments = req.path.split(separator: "/").map(String.init)
        for route in routes {
            guard route.method == req.method else { continue }
            guard let params = match(pattern: route.pattern, segments: segments) else { continue }
            do {
                return try route.handler(req, params)
            } catch let e as AppError {
                return HTTPResponse.error(e)
            } catch {
                return HTTPResponse.internalError(error.localizedDescription)
            }
        }
        // 405 if path matches but wrong method
        for route in routes {
            if let _ = match(pattern: route.pattern, segments: segments) {
                return HTTPResponse(status: 405, headers: [], body: "{\"error\":\"Method Not Allowed\"}")
            }
        }
        return HTTPResponse.notFound("Route not found: \(req.method.rawValue) \(req.path)")
    }

    private func match(pattern: [String], segments: [String]) -> [String: String]? {
        guard pattern.count == segments.count else { return nil }
        var params: [String: String] = [:]
        for (p, s) in zip(pattern, segments) {
            if p.hasPrefix(":") {
                params[String(p.dropFirst())] = s
            } else if p != s {
                return nil
            }
        }
        return params
    }
}

extension Error {
    var localizedDescription: String { "\(self)" }
}
