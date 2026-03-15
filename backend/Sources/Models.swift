import Glibc

// MARK: - Error types

enum AppError: Error {
    case notFound(String)
    case badRequest(String)
    case internalError(String)
    case conflict(String)

    var statusCode: Int {
        switch self {
        case .notFound:      return 404
        case .badRequest:    return 400
        case .internalError: return 500
        case .conflict:      return 409
        }
    }
    var message: String {
        switch self {
        case .notFound(let m):      return m
        case .badRequest(let m):    return m
        case .internalError(let m): return m
        case .conflict(let m):      return m
        }
    }
    var errorJSON: String {
        let code: String
        switch self {
        case .notFound:      code = "NOT_FOUND"
        case .badRequest:    code = "BAD_REQUEST"
        case .internalError: code = "INTERNAL_ERROR"
        case .conflict:      code = "CONFLICT"
        }
        return "{\"error\":\"\(code)\",\"message\":\"\(message.jsonEscaped)\"}"
    }
}

// MARK: - Transaction

enum TransactionType: String {
    case income = "income"
    case expense = "expense"
}

struct Transaction {
    var id: String
    var title: String
    var amount: Double
    var type: TransactionType
    var categoryId: String
    var date: String       // ISO date string YYYY-MM-DD
    var note: String
    var createdAt: Int     // Unix timestamp
    var updatedAt: Int

    static func fromJSON(_ v: JSONValue) -> Transaction? {
        guard let id        = v["id"]?.asString,
              let title     = v["title"]?.asString,
              let amount    = v["amount"]?.asDouble,
              let typeStr   = v["type"]?.asString,
              let txType    = TransactionType(rawValue: typeStr),
              let catId     = v["categoryId"]?.asString,
              let date      = v["date"]?.asString
        else { return nil }
        let note      = v["note"]?.asString      ?? ""
        let createdAt = v["createdAt"]?.asInt    ?? Int(time(nil))
        let updatedAt = v["updatedAt"]?.asInt    ?? Int(time(nil))
        return Transaction(id: id, title: title, amount: amount, type: txType,
                           categoryId: catId, date: date, note: note,
                           createdAt: createdAt, updatedAt: updatedAt)
    }

    func toJSON() -> JSONValue {
        .object([
            (key: "id",         value: .string(id)),
            (key: "title",      value: .string(title)),
            (key: "amount",     value: .double(amount)),
            (key: "type",       value: .string(type.rawValue)),
            (key: "categoryId", value: .string(categoryId)),
            (key: "date",       value: .string(date)),
            (key: "note",       value: .string(note)),
            (key: "createdAt",  value: .integer(createdAt)),
            (key: "updatedAt",  value: .integer(updatedAt))
        ])
    }

    mutating func applyPatch(_ v: JSONValue) {
        if let t = v["title"]?.asString    { title      = t }
        if let a = v["amount"]?.asDouble   { amount     = a }
        if let s = v["type"]?.asString, let tx = TransactionType(rawValue: s) { type = tx }
        if let c = v["categoryId"]?.asString { categoryId = c }
        if let d = v["date"]?.asString     { date       = d }
        if let n = v["note"]?.asString     { note       = n }
        updatedAt = Int(time(nil))
    }

    func validate() throws {
        if title.trimmingCharacters(in: [" "]).isEmpty { throw AppError.badRequest("title is required") }
        if amount < 0 { throw AppError.badRequest("amount must be non-negative") }
        if date.isEmpty { throw AppError.badRequest("date is required") }
    }
}

// MARK: - Category

struct Category {
    var id: String
    var name: String
    var icon: String
    var color: String
    var type: String    // "income" | "expense" | "both"
    var isDefault: Bool
    var createdAt: Int
    var updatedAt: Int

    static func fromJSON(_ v: JSONValue) -> Category? {
        guard let id   = v["id"]?.asString,
              let name = v["name"]?.asString
        else { return nil }
        let icon      = v["icon"]?.asString      ?? "circle"
        let color     = v["color"]?.asString     ?? "#6366f1"
        let type      = v["type"]?.asString      ?? "both"
        let isDefault = v["isDefault"]?.asBool   ?? false
        let createdAt = v["createdAt"]?.asInt    ?? Int(time(nil))
        let updatedAt = v["updatedAt"]?.asInt    ?? Int(time(nil))
        return Category(id: id, name: name, icon: icon, color: color,
                        type: type, isDefault: isDefault,
                        createdAt: createdAt, updatedAt: updatedAt)
    }

    func toJSON() -> JSONValue {
        .object([
            (key: "id",        value: .string(id)),
            (key: "name",      value: .string(name)),
            (key: "icon",      value: .string(icon)),
            (key: "color",     value: .string(color)),
            (key: "type",      value: .string(type)),
            (key: "isDefault", value: .boolean(isDefault)),
            (key: "createdAt", value: .integer(createdAt)),
            (key: "updatedAt", value: .integer(updatedAt))
        ])
    }

    mutating func applyPatch(_ v: JSONValue) {
        if let n = v["name"]?.asString  { name  = n }
        if let i = v["icon"]?.asString  { icon  = i }
        if let c = v["color"]?.asString { color = c }
        if let t = v["type"]?.asString  { type  = t }
        if let d = v["isDefault"]?.asBool { isDefault = d }
        updatedAt = Int(time(nil))
    }

    func validate() throws {
        if name.trimmingCharacters(in: [" "]).isEmpty { throw AppError.badRequest("name is required") }
    }
}

// MARK: - Settings

struct Settings {
    var currency: String
    var currencySymbol: String
    var budgetLimit: Double
    var budgetPeriod: String   // "monthly" | "weekly" | "yearly"
    var theme: String          // "light" | "dark"
    var updatedAt: Int

    static let defaults = Settings(
        currency: "CAD",
        currencySymbol: "$",
        budgetLimit: 2000.0,
        budgetPeriod: "monthly",
        theme: "light",
        updatedAt: Int(time(nil))
    )

    static func fromJSON(_ v: JSONValue) -> Settings? {
        let currency       = v["currency"]?.asString       ?? "CAD"
        let currencySymbol = v["currencySymbol"]?.asString ?? "$"
        let budgetLimit    = v["budgetLimit"]?.asDouble    ?? 2000.0
        let budgetPeriod   = v["budgetPeriod"]?.asString   ?? "monthly"
        let theme          = v["theme"]?.asString          ?? "light"
        let updatedAt      = v["updatedAt"]?.asInt         ?? Int(time(nil))
        return Settings(currency: currency, currencySymbol: currencySymbol,
                        budgetLimit: budgetLimit, budgetPeriod: budgetPeriod,
                        theme: theme, updatedAt: updatedAt)
    }

    func toJSON() -> JSONValue {
        .object([
            (key: "currency",       value: .string(currency)),
            (key: "currencySymbol", value: .string(currencySymbol)),
            (key: "budgetLimit",    value: .double(budgetLimit)),
            (key: "budgetPeriod",   value: .string(budgetPeriod)),
            (key: "theme",          value: .string(theme)),
            (key: "updatedAt",      value: .integer(updatedAt))
        ])
    }

    mutating func applyPatch(_ v: JSONValue) {
        if let c = v["currency"]?.asString       { currency       = c }
        if let s = v["currencySymbol"]?.asString { currencySymbol = s }
        if let b = v["budgetLimit"]?.asDouble    { budgetLimit    = b }
        if let p = v["budgetPeriod"]?.asString   { budgetPeriod   = p }
        if let t = v["theme"]?.asString          { theme          = t }
        updatedAt = Int(time(nil))
    }

    func validate() throws {
        if currency.isEmpty { throw AppError.badRequest("currency is required") }
        let validPeriods = ["monthly", "weekly", "yearly"]
        if !validPeriods.contains(budgetPeriod) {
            throw AppError.badRequest("budgetPeriod must be monthly, weekly, or yearly")
        }
        let validThemes = ["light", "dark"]
        if !validThemes.contains(theme) {
            throw AppError.badRequest("theme must be light or dark")
        }
    }
}

// MARK: - Helpers

func generateID() -> String {
    let ts = Int(time(nil))
    let rnd = Int(random()) & 0xFFFFFF
    return "\(ts)_\(String(rnd, radix: 16))"
}

func currentTimestamp() -> Int { Int(time(nil)) }
