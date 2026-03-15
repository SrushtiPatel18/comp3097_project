import Glibc

// MARK: - File-based JSON storage

final class Storage {
    private let dataDir: String

    private var transactions: [Transaction] = []
    private var categories: [Category] = []
    private var settings: Settings = Settings.defaults

    private let txFile: String
    private let catFile: String
    private let settingsFile: String

    init(dataDir: String = "./data") {
        self.dataDir      = dataDir
        self.txFile       = "\(dataDir)/transactions.json"
        self.catFile      = "\(dataDir)/categories.json"
        self.settingsFile = "\(dataDir)/settings.json"
    }

    func load() {
        mkdir(dataDir, 0o755)
        transactions = loadArray(from: txFile,  decode: Transaction.fromJSON)
        categories   = loadArray(from: catFile, decode: Category.fromJSON)
        settings     = loadObject(from: settingsFile, decode: Settings.fromJSON) ?? Settings.defaults
        if categories.isEmpty { seedCategories() }
    }

    // MARK: Transactions

    func allTransactions(categoryId: String? = nil) -> [Transaction] {
        guard let cid = categoryId else { return transactions }
        return transactions.filter { $0.categoryId == cid }
    }

    func findTransaction(id: String) -> Transaction? {
        transactions.first { $0.id == id }
    }

    func addTransaction(_ tx: Transaction) throws {
        if transactions.contains(where: { $0.id == tx.id }) {
            throw AppError.conflict("Transaction with this id already exists")
        }
        transactions.append(tx)
        try persistTransactions()
    }

    func updateTransaction(_ tx: Transaction) throws {
        guard let idx = transactions.firstIndex(where: { $0.id == tx.id }) else {
            throw AppError.notFound("Transaction not found")
        }
        transactions[idx] = tx
        try persistTransactions()
    }

    func deleteTransaction(id: String) throws {
        let before = transactions.count
        transactions.removeAll { $0.id == id }
        if transactions.count == before { throw AppError.notFound("Transaction not found") }
        try persistTransactions()
    }

    // MARK: Categories

    func allCategories() -> [Category] { categories }

    func findCategory(id: String) -> Category? {
        categories.first { $0.id == id }
    }

    func addCategory(_ cat: Category) throws {
        if categories.contains(where: { $0.id == cat.id }) {
            throw AppError.conflict("Category with this id already exists")
        }
        categories.append(cat)
        try persistCategories()
    }

    func updateCategory(_ cat: Category) throws {
        guard let idx = categories.firstIndex(where: { $0.id == cat.id }) else {
            throw AppError.notFound("Category not found")
        }
        categories[idx] = cat
        try persistCategories()
    }

    func deleteCategory(id: String) throws {
        let before = categories.count
        categories.removeAll { $0.id == id }
        if categories.count == before { throw AppError.notFound("Category not found") }
        let hadTransactions = transactions.contains { $0.categoryId == id }
        if hadTransactions {
            transactions = transactions.map { tx in
                var t = tx
                if t.categoryId == id { t.categoryId = "" }
                return t
            }
            try persistTransactions()
        }
        try persistCategories()
    }

    // MARK: Settings

    func getSettings() -> Settings { settings }

    func updateSettings(_ s: Settings) throws {
        settings = s
        try persistSettings()
    }

    // MARK: Persistence

    private func persistTransactions() throws {
        let arr = JSONValue.array(transactions.map { $0.toJSON() })
        try write(json: arr, to: txFile)
    }

    private func persistCategories() throws {
        let arr = JSONValue.array(categories.map { $0.toJSON() })
        try write(json: arr, to: catFile)
    }

    private func persistSettings() throws {
        try write(json: settings.toJSON(), to: settingsFile)
    }

    private func write(json: JSONValue, to path: String) throws {
        let content = json.json
        let bytes   = Array(content.utf8)
        guard let f = fopen(path, "w") else {
            throw AppError.internalError("Cannot open file for writing: \(path)")
        }
        defer { fclose(f) }
        let written = fwrite(bytes, 1, bytes.count, f)
        if written != bytes.count {
            throw AppError.internalError("Write error to: \(path)")
        }
    }

    private func readFile(_ path: String) -> String? {
        guard let f = fopen(path, "r") else { return nil }
        defer { fclose(f) }
        var result = ""
        var buf = [CChar](repeating: 0, count: 4096)
        while fgets(&buf, Int32(buf.count), f) != nil {
            result += String(cString: buf)
        }
        return result.isEmpty ? nil : result
    }

    private func loadArray<T>(from path: String, decode: (JSONValue) -> T?) -> [T] {
        guard let raw = readFile(path),
              let json = parseJSON(raw),
              let arr  = json.asArray
        else { return [] }
        return arr.compactMap { decode($0) }
    }

    private func loadObject<T>(from path: String, decode: (JSONValue) -> T?) -> T? {
        guard let raw = readFile(path),
              let json = parseJSON(raw)
        else { return nil }
        return decode(json)
    }

    // MARK: Seed data

    private func seedCategories() {
        let seeds: [(String, String, String, String, Bool)] = [
            ("cat_salary",       "Salary",       "briefcase",   "#22c55e", true),
            ("cat_freelance",    "Freelance",     "laptop",      "#3b82f6", true),
            ("cat_investments",  "Investments",   "trending-up", "#8b5cf6", true),
            ("cat_food",         "Food",          "utensils",    "#f97316", false),
            ("cat_transport",    "Transport",     "car",         "#06b6d4", false),
            ("cat_housing",      "Housing",       "home",        "#6366f1", false),
            ("cat_health",       "Health",        "heart",       "#ec4899", false),
            ("cat_entertainment","Entertainment", "film",        "#f59e0b", false),
            ("cat_shopping",     "Shopping",      "shopping-bag","#84cc16", false),
            ("cat_other",        "Other",         "circle",      "#9ca3af", false),
        ]
        let now = Int(time(nil))
        categories = seeds.map { id, name, icon, color, isDefault in
            Category(id: id, name: name, icon: icon, color: color,
                     type: "both", isDefault: isDefault,
                     createdAt: now, updatedAt: now)
        }
        _ = try? { try persistCategories() }()
    }
}
