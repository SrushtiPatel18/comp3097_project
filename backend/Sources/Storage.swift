import Glibc

// MARK: - Thread-safe file-based JSON storage

final class Storage {
    private let dataDir:     String
    private let txFile:      String
    private let catFile:     String
    private let settingsFile: String

    private var transactions: [Transaction] = []
    private var categories:   [Category]    = []
    private var settings:     Settings      = Settings.defaults

    private var mutex = pthread_mutex_t()

    init(dataDir: String = "./data") {
        self.dataDir      = dataDir
        self.txFile       = "\(dataDir)/transactions.json"
        self.catFile      = "\(dataDir)/categories.json"
        self.settingsFile = "\(dataDir)/settings.json"
        pthread_mutex_init(&mutex, nil)
    }

    deinit { pthread_mutex_destroy(&mutex) }

    // MARK: - Load

    func load() {
        lock(); defer { unlock() }
        mkdir(dataDir, 0o755)
        transactions = loadArray(from: txFile,  decode: Transaction.fromJSON)
        categories   = loadArray(from: catFile, decode: Category.fromJSON)
        settings     = loadObject(from: settingsFile, decode: Settings.fromJSON) ?? Settings.defaults
        if categories.isEmpty { seedCategories() }
        logger.info("Storage loaded: \(transactions.count) transactions, \(categories.count) categories")
    }

    // MARK: - Transactions

    func allTransactions(
        categoryId: String? = nil,
        type:       String? = nil,
        search:     String? = nil,
        from:       String? = nil,
        to:         String? = nil
    ) -> [Transaction] {
        lock(); defer { unlock() }
        var result = transactions

        if let cid = categoryId, !cid.isEmpty {
            result = result.filter { $0.categoryId == cid }
        }
        if let t = type, !t.isEmpty {
            result = result.filter { $0.type.rawValue == t }
        }
        if let f = from, !f.isEmpty {
            result = result.filter { $0.date >= f }
        }
        if let t = to, !t.isEmpty {
            result = result.filter { $0.date <= t }
        }
        if let s = search, !s.isEmpty {
            let lower = s.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(lower) ||
                $0.note.lowercased().contains(lower)
            }
        }
        // Newest first (date desc, then createdAt desc)
        return result.sorted { a, b in
            if a.date != b.date { return a.date > b.date }
            return a.createdAt > b.createdAt
        }
    }

    func findTransaction(id: String) -> Transaction? {
        lock(); defer { unlock() }
        return transactions.first { $0.id == id }
    }

    func addTransaction(_ tx: Transaction) throws {
        lock(); defer { unlock() }
        guard !transactions.contains(where: { $0.id == tx.id }) else {
            throw AppError.conflict("Transaction with id '\(tx.id)' already exists")
        }
        transactions.append(tx)
        try persistTransactions()
    }

    func updateTransaction(_ tx: Transaction) throws {
        lock(); defer { unlock() }
        guard let idx = transactions.firstIndex(where: { $0.id == tx.id }) else {
            throw AppError.notFound("Transaction '\(tx.id)' not found")
        }
        transactions[idx] = tx
        try persistTransactions()
    }

    func deleteTransaction(id: String) throws {
        lock(); defer { unlock() }
        let before = transactions.count
        transactions.removeAll { $0.id == id }
        guard transactions.count < before else {
            throw AppError.notFound("Transaction '\(id)' not found")
        }
        try persistTransactions()
    }

    // MARK: - Categories

    func allCategories() -> [Category] {
        lock(); defer { unlock() }
        return categories
    }

    func findCategory(id: String) -> Category? {
        lock(); defer { unlock() }
        return categories.first { $0.id == id }
    }

    func categoryNameExists(_ name: String, excludingId: String? = nil) -> Bool {
        lock(); defer { unlock() }
        let lower = name.lowercased()
        return categories.contains {
            $0.name.lowercased() == lower && $0.id != (excludingId ?? "")
        }
    }

    func addCategory(_ cat: Category) throws {
        lock(); defer { unlock() }
        guard !categories.contains(where: { $0.id == cat.id }) else {
            throw AppError.conflict("Category with id '\(cat.id)' already exists")
        }
        categories.append(cat)
        try persistCategories()
    }

    func updateCategory(_ cat: Category) throws {
        lock(); defer { unlock() }
        guard let idx = categories.firstIndex(where: { $0.id == cat.id }) else {
            throw AppError.notFound("Category '\(cat.id)' not found")
        }
        categories[idx] = cat
        try persistCategories()
    }

    func deleteCategory(id: String) throws {
        lock(); defer { unlock() }
        guard let cat = categories.first(where: { $0.id == id }) else {
            throw AppError.notFound("Category '\(id)' not found")
        }
        if cat.isDefault {
            throw AppError.conflict("Cannot delete a built-in default category")
        }
        categories.removeAll { $0.id == id }
        // Orphan any transactions that referenced this category
        let orphanIds = transactions.filter { $0.categoryId == id }.map { $0.id }
        if !orphanIds.isEmpty {
            transactions = transactions.map { tx in
                guard tx.categoryId == id else { return tx }
                var t = tx; t.categoryId = "cat_other"; return t
            }
            try persistTransactions()
        }
        try persistCategories()
    }

    // MARK: - Settings

    func getSettings() -> Settings {
        lock(); defer { unlock() }
        return settings
    }

    func updateSettings(_ s: Settings) throws {
        lock(); defer { unlock() }
        settings = s
        try persistSettings()
    }

    // MARK: - Summary

    struct Summary {
        let totalIncome:  Double
        let totalExpense: Double
        let balance:      Double
        let count:        Int
    }

    func summary(
        from: String? = nil,
        to:   String? = nil,
        categoryId: String? = nil
    ) -> Summary {
        lock(); defer { unlock() }
        var txs = transactions
        if let f = from, !f.isEmpty { txs = txs.filter { $0.date >= f } }
        if let t = to,   !t.isEmpty { txs = txs.filter { $0.date <= t } }
        if let c = categoryId, !c.isEmpty { txs = txs.filter { $0.categoryId == c } }

        var income: Double = 0
        var expense: Double = 0
        for tx in txs {
            if tx.type == .income { income  += tx.amount }
            else                  { expense += tx.amount }
        }
        return Summary(totalIncome: income, totalExpense: expense,
                       balance: income - expense, count: txs.count)
    }

    // MARK: - Private helpers

    private func lock()   { pthread_mutex_lock(&mutex)   }
    private func unlock() { pthread_mutex_unlock(&mutex) }

    // Atomic write: write to .tmp then rename (crash-safe)
    private func write(json: JSONValue, to path: String) throws {
        let content = json.json
        let bytes   = Array(content.utf8)
        let tmp     = path + ".tmp"

        guard let f = fopen(tmp, "w") else {
            throw AppError.internalError("Cannot open temp file: \(tmp)")
        }
        let written = fwrite(bytes, 1, bytes.count, f)
        fclose(f)

        guard written == bytes.count else {
            unlink(tmp)
            throw AppError.internalError("Write incomplete to: \(tmp)")
        }
        guard Glibc.rename(tmp, path) == 0 else {
            unlink(tmp)
            throw AppError.internalError("Rename failed: \(tmp) → \(path)")
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
        guard let raw  = readFile(path),
              let json = parseJSON(raw),
              let arr  = json.asArray
        else { return [] }
        return arr.compactMap { decode($0) }
    }

    private func loadObject<T>(from path: String, decode: (JSONValue) -> T?) -> T? {
        guard let raw  = readFile(path),
              let json = parseJSON(raw)
        else { return nil }
        return decode(json)
    }

    private func persistTransactions() throws { try write(json: .array(transactions.map { $0.toJSON() }), to: txFile) }
    private func persistCategories()   throws { try write(json: .array(categories.map   { $0.toJSON() }), to: catFile) }
    private func persistSettings()     throws { try write(json: settings.toJSON(), to: settingsFile) }

    // MARK: - Seed data

    private func seedCategories() {
        let seeds: [(String, String, String, String, Bool)] = [
            ("cat_salary",        "Salary",        "briefcase",    "#22c55e", true),
            ("cat_freelance",     "Freelance",      "laptop",       "#3b82f6", true),
            ("cat_investments",   "Investments",    "trending-up",  "#8b5cf6", true),
            ("cat_food",          "Food",           "utensils",     "#f97316", false),
            ("cat_transport",     "Transport",      "car",          "#06b6d4", false),
            ("cat_housing",       "Housing",        "home",         "#6366f1", false),
            ("cat_health",        "Health",         "heart",        "#ec4899", false),
            ("cat_entertainment", "Entertainment",  "film",         "#f59e0b", false),
            ("cat_shopping",      "Shopping",       "shopping-bag", "#84cc16", false),
            ("cat_other",         "Other",          "circle",       "#9ca3af", false),
        ]
        let now = Int(time(nil))
        categories = seeds.map { id, name, icon, color, isDefault in
            Category(id: id, name: name, icon: icon, color: color,
                     type: "both", isDefault: isDefault, createdAt: now, updatedAt: now)
        }
        _ = try? { try persistCategories() }()
    }
}
