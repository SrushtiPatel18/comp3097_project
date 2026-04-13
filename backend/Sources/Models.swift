import Glibc

// MARK: - App version (single source of truth)

let APP_VERSION = "2.0.0"

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
        case .notFound(let m),
             .badRequest(let m),
             .internalError(let m),
             .conflict(let m): return m
        }
    }
    var code: String {
        switch self {
        case .notFound:      return "NOT_FOUND"
        case .badRequest:    return "BAD_REQUEST"
        case .internalError: return "INTERNAL_ERROR"
        case .conflict:      return "CONFLICT"
        }
    }
    var errorJSON: String {
        "{\"error\":\"\(code)\",\"message\":\"\(message.jsonEscaped)\"}"
    }
}

// MARK: - Transaction

enum TransactionType: String {
    case income  = "income"
    case expense = "expense"
}

struct Transaction {
    var id:         String
    var title:      String
    var amount:     Double
    var type:       TransactionType
    var categoryId: String
    var date:       String        // YYYY-MM-DD
    var note:       String
    var createdAt:  Int           // Unix timestamp
    var updatedAt:  Int

    static func fromJSON(_ v: JSONValue) -> Transaction? {
        guard let id     = v["id"]?.asString,
              let title  = v["title"]?.asString,
              let amount = v["amount"]?.asDouble,
              let ts     = v["type"]?.asString,
              let txType = TransactionType(rawValue: ts),
              let catId  = v["categoryId"]?.asString,
              let date   = v["date"]?.asString
        else { return nil }
        let note      = v["note"]?.asString   ?? ""
        let createdAt = v["createdAt"]?.asInt ?? currentTimestamp()
        let updatedAt = v["updatedAt"]?.asInt ?? currentTimestamp()
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
            (key: "updatedAt",  value: .integer(updatedAt)),
        ])
    }

    mutating func applyPatch(_ v: JSONValue) {
        if let t = v["title"]?.asString       { title      = t }
        if let a = v["amount"]?.asDouble      { amount     = a }
        if let s = v["type"]?.asString,
           let tx = TransactionType(rawValue: s) { type    = tx }
        if let c = v["categoryId"]?.asString  { categoryId = c }
        if let d = v["date"]?.asString        { date       = d }
        if let n = v["note"]?.asString        { note       = n }
        updatedAt = currentTimestamp()
    }

    func validate() throws {
        let trimTitle = title.trimmingCharacters(in: [" ", "\t"])
        if trimTitle.isEmpty { throw AppError.badRequest("'title' must not be empty") }
        if trimTitle.count > 200 { throw AppError.badRequest("'title' exceeds 200 characters") }
        if amount < 0        { throw AppError.badRequest("'amount' must be non-negative") }
        if amount > 1_000_000_000 { throw AppError.badRequest("'amount' exceeds maximum allowed value") }
        if !isValidDate(date) { throw AppError.badRequest("'date' must be in YYYY-MM-DD format") }
    }
}

// MARK: - Category

struct Category {
    var id:        String
    var name:      String
    var icon:      String
    var color:     String
    var type:      String    // "income" | "expense" | "both"
    var isDefault: Bool
    var createdAt: Int
    var updatedAt: Int

    static func fromJSON(_ v: JSONValue) -> Category? {
        guard let id   = v["id"]?.asString,
              let name = v["name"]?.asString
        else { return nil }
        let icon      = v["icon"]?.asString    ?? "circle"
        let color     = v["color"]?.asString   ?? "#6366f1"
        let type      = v["type"]?.asString    ?? "both"
        let isDefault = v["isDefault"]?.asBool ?? false
        let createdAt = v["createdAt"]?.asInt  ?? currentTimestamp()
        let updatedAt = v["updatedAt"]?.asInt  ?? currentTimestamp()
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
            (key: "updatedAt", value: .integer(updatedAt)),
        ])
    }

    mutating func applyPatch(_ v: JSONValue) {
        if let n = v["name"]?.asString    { name  = n }
        if let i = v["icon"]?.asString    { icon  = i }
        if let c = v["color"]?.asString   { color = c }
        if let t = v["type"]?.asString    { type  = t }
        if let d = v["isDefault"]?.asBool { isDefault = d }
        updatedAt = currentTimestamp()
    }

    func validate() throws {
        let trimName = name.trimmingCharacters(in: [" ", "\t"])
        if trimName.isEmpty          { throw AppError.badRequest("'name' must not be empty") }
        if trimName.count > 100      { throw AppError.badRequest("'name' exceeds 100 characters") }
        let validTypes = ["income", "expense", "both"]
        if !validTypes.contains(type) {
            throw AppError.badRequest("'type' must be one of: income, expense, both")
        }
        if !color.isEmpty && !color.hasPrefix("#") {
            throw AppError.badRequest("'color' must be a hex colour starting with #")
        }
    }
}

// MARK: - Settings

struct Settings {
    var currency:       String
    var currencySymbol: String
    var budgetLimit:    Double
    var budgetPeriod:   String   // "monthly" | "weekly" | "yearly"
    var theme:          String   // "light" | "dark"
    var updatedAt:      Int

    static let defaults = Settings(
        currency: "CAD", currencySymbol: "$",
        budgetLimit: 2000.0, budgetPeriod: "monthly",
        theme: "light", updatedAt: currentTimestamp()
    )

    static func fromJSON(_ v: JSONValue) -> Settings? {
        let currency       = v["currency"]?.asString       ?? "CAD"
        let currencySymbol = v["currencySymbol"]?.asString ?? "$"
        let budgetLimit    = v["budgetLimit"]?.asDouble    ?? 2000.0
        let budgetPeriod   = v["budgetPeriod"]?.asString   ?? "monthly"
        let theme          = v["theme"]?.asString          ?? "light"
        let updatedAt      = v["updatedAt"]?.asInt         ?? currentTimestamp()
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
            (key: "updatedAt",      value: .integer(updatedAt)),
        ])
    }

    mutating func applyPatch(_ v: JSONValue) {
        if let c = v["currency"]?.asString       { currency       = c }
        if let s = v["currencySymbol"]?.asString { currencySymbol = s }
        if let b = v["budgetLimit"]?.asDouble    { budgetLimit    = b }
        if let p = v["budgetPeriod"]?.asString   { budgetPeriod   = p }
        if let t = v["theme"]?.asString          { theme          = t }
        updatedAt = currentTimestamp()
    }

    func validate() throws {
        if currency.trimmingCharacters(in: [" "]).isEmpty {
            throw AppError.badRequest("'currency' is required")
        }
        if budgetLimit < 0 {
            throw AppError.badRequest("'budgetLimit' must be non-negative")
        }
        let validPeriods = ["monthly", "weekly", "yearly"]
        if !validPeriods.contains(budgetPeriod) {
            throw AppError.badRequest("'budgetPeriod' must be monthly, weekly, or yearly")
        }
        let validThemes = ["light", "dark"]
        if !validThemes.contains(theme) {
            throw AppError.badRequest("'theme' must be light or dark")
        }
    }
}

// MARK: - Helpers

/// Generate a unique ID: 8-char hex timestamp prefix + 12-char random suffix.
func generateID() -> String {
    let ts   = UInt64(time(nil))
    let r1   = UInt64(UInt32(bitPattern: Int32(random())))
    let r2   = UInt64(UInt32(bitPattern: Int32(random())))
    return hexPad(ts & 0xFFFFFFFF, digits: 8)
         + hexPad(r1 & 0xFFFFFF, digits: 6)
         + hexPad(r2 & 0xFFFFFF, digits: 6)
}

private func hexPad(_ val: UInt64, digits: Int) -> String {
    var v = val
    var chars: [Character] = []
    let hexC: [Character] = ["0","1","2","3","4","5","6","7","8","9","a","b","c","d","e","f"]
    for _ in 0..<digits {
        chars.insert(hexC[Int(v & 0xF)], at: chars.startIndex)
        v >>= 4
    }
    return String(chars)
}

func currentTimestamp() -> Int { Int(time(nil)) }

/// Validate YYYY-MM-DD format (does not check calendar validity, only structure).
func isValidDate(_ s: String) -> Bool {
    let chars = Array(s)
    guard chars.count == 10 else { return false }
    // Check separators
    guard chars[4] == "-" && chars[7] == "-" else { return false }
    // Check all other positions are digits
    for i in [0,1,2,3,5,6,8,9] {
        guard chars[i] >= "0" && chars[i] <= "9" else { return false }
    }
    return true
}
